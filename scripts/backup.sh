#!/bin/bash

# Elephant Handbook - Backup Script
# Creates backups of PostgreSQL databases and S3 objects

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ENVIRONMENT="${ENVIRONMENT:-local}"
KEEP_DAYS="${KEEP_DAYS:-7}"

# PostgreSQL settings
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_PASSWORD="${PG_PASSWORD:-postgres}"
PG_DATABASE="${PG_DATABASE:-elephant}"

# S3/MinIO settings
S3_ENDPOINT="${S3_ENDPOINT:-http://localhost:9000}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-minioadmin}"
S3_SECRET_KEY="${S3_SECRET_KEY:-minioadmin}"
S3_BUCKET="${S3_BUCKET:-elephant-archive}"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo
    echo -e "${BLUE}==== $1 ====${NC}"
    echo
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --keep-days)
            KEEP_DAYS="$2"
            shift 2
            ;;
        --postgres-only)
            POSTGRES_ONLY=true
            shift
            ;;
        --s3-only)
            S3_ONLY=true
            shift
            ;;
        --help)
            cat << EOF
Usage: $0 [OPTIONS]

Options:
  --dir DIR           Backup directory (default: ./backups)
  --env ENV           Environment name (default: local)
  --keep-days DAYS    Keep backups for N days (default: 7)
  --postgres-only     Only backup PostgreSQL
  --s3-only           Only backup S3/MinIO
  --help              Show this help message

Environment Variables:
  PG_HOST             PostgreSQL host (default: localhost)
  PG_PORT             PostgreSQL port (default: 5432)
  PG_USER             PostgreSQL user (default: postgres)
  PG_PASSWORD         PostgreSQL password (default: postgres)
  PG_DATABASE         PostgreSQL database (default: elephant)
  S3_ENDPOINT         S3/MinIO endpoint (default: http://localhost:9000)
  S3_ACCESS_KEY       S3 access key (default: minioadmin)
  S3_SECRET_KEY       S3 secret key (default: minioadmin)
  S3_BUCKET           S3 bucket name (default: elephant-archive)

Examples:
  $0                                    # Backup everything
  $0 --postgres-only                    # Only PostgreSQL
  $0 --dir /backups --keep-days 30      # Custom location and retention

EOF
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    print_step "Checking Prerequisites"

    local missing=()

    if [ "$POSTGRES_ONLY" != true ] && [ "$S3_ONLY" != true ] || [ "$POSTGRES_ONLY" = true ]; then
        if ! command -v pg_dump &> /dev/null; then
            missing+=("pg_dump (PostgreSQL client)")
        fi
    fi

    if [ "$POSTGRES_ONLY" != true ] && [ "$S3_ONLY" != true ] || [ "$S3_ONLY" = true ]; then
        if ! command -v aws &> /dev/null; then
            print_warn "AWS CLI not found. Will try using mc (MinIO client)"
            if ! command -v mc &> /dev/null; then
                missing+=("aws or mc (for S3 backup)")
            fi
        fi
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi

    print_info "All prerequisites satisfied"
}

# Create backup directory
create_backup_dir() {
    print_step "Creating Backup Directory"

    mkdir -p "$BACKUP_DIR/$ENVIRONMENT"
    print_info "Backup directory: $BACKUP_DIR/$ENVIRONMENT"
}

# Backup PostgreSQL
backup_postgres() {
    if [ "$S3_ONLY" = true ]; then
        return
    fi

    print_step "Backing up PostgreSQL"

    local backup_file="$BACKUP_DIR/$ENVIRONMENT/postgres-$TIMESTAMP.sql.gz"

    print_info "Database: $PG_DATABASE"
    print_info "Host: $PG_HOST:$PG_PORT"
    print_info "Output: $backup_file"

    # Perform backup
    export PGPASSWORD="$PG_PASSWORD"

    if pg_dump -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" \
        --no-owner --no-acl --clean --if-exists | gzip > "$backup_file"; then

        local size=$(du -h "$backup_file" | cut -f1)
        print_info "✓ PostgreSQL backup complete: $size"

        # Create a metadata file
        cat > "$backup_file.meta" << EOF
timestamp: $TIMESTAMP
environment: $ENVIRONMENT
database: $PG_DATABASE
host: $PG_HOST
size: $size
EOF

    else
        print_error "✗ PostgreSQL backup failed"
        return 1
    fi

    unset PGPASSWORD
}

# Backup S3/MinIO
backup_s3() {
    if [ "$POSTGRES_ONLY" = true ]; then
        return
    fi

    print_step "Backing up S3/MinIO"

    local backup_dir="$BACKUP_DIR/$ENVIRONMENT/s3-$TIMESTAMP"
    mkdir -p "$backup_dir"

    print_info "Bucket: $S3_BUCKET"
    print_info "Endpoint: $S3_ENDPOINT"
    print_info "Output: $backup_dir"

    # Try AWS CLI first
    if command -v aws &> /dev/null; then
        print_info "Using AWS CLI..."

        if aws s3 sync "s3://$S3_BUCKET" "$backup_dir" \
            --endpoint-url "$S3_ENDPOINT" \
            --no-verify-ssl 2>/dev/null; then

            local size=$(du -sh "$backup_dir" | cut -f1)
            print_info "✓ S3 backup complete: $size"
        else
            print_warn "AWS CLI failed, trying MinIO client..."
            backup_s3_with_mc "$backup_dir"
        fi
    else
        backup_s3_with_mc "$backup_dir"
    fi
}

# Backup S3 using MinIO client
backup_s3_with_mc() {
    local backup_dir="$1"

    print_info "Using MinIO client (mc)..."

    # Configure mc alias
    mc alias set backup-target "$S3_ENDPOINT" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" --insecure &>/dev/null

    if mc mirror "backup-target/$S3_BUCKET" "$backup_dir" --insecure; then
        local size=$(du -sh "$backup_dir" | cut -f1)
        print_info "✓ S3 backup complete: $size"
    else
        print_error "✗ S3 backup failed"
        return 1
    fi

    # Remove alias
    mc alias remove backup-target &>/dev/null
}

# Clean old backups
clean_old_backups() {
    print_step "Cleaning Old Backups"

    print_info "Keeping backups from last $KEEP_DAYS days"

    # Find and delete old backups
    local deleted=0

    if [ -d "$BACKUP_DIR/$ENVIRONMENT" ]; then
        while IFS= read -r -d '' file; do
            rm -rf "$file"
            deleted=$((deleted + 1))
            print_info "Deleted: $(basename "$file")"
        done < <(find "$BACKUP_DIR/$ENVIRONMENT" -type f -mtime +"$KEEP_DAYS" -print0)

        if [ $deleted -eq 0 ]; then
            print_info "No old backups to delete"
        else
            print_info "✓ Deleted $deleted old backup(s)"
        fi
    fi
}

# Verify backups
verify_backups() {
    print_step "Verifying Backups"

    # Verify PostgreSQL backup
    if [ "$S3_ONLY" != true ]; then
        local pg_backup="$BACKUP_DIR/$ENVIRONMENT/postgres-$TIMESTAMP.sql.gz"
        if [ -f "$pg_backup" ]; then
            if gzip -t "$pg_backup" 2>/dev/null; then
                print_info "✓ PostgreSQL backup file is valid"
            else
                print_error "✗ PostgreSQL backup file is corrupted"
            fi
        fi
    fi

    # Verify S3 backup
    if [ "$POSTGRES_ONLY" != true ]; then
        local s3_backup="$BACKUP_DIR/$ENVIRONMENT/s3-$TIMESTAMP"
        if [ -d "$s3_backup" ]; then
            local file_count=$(find "$s3_backup" -type f | wc -l)
            print_info "✓ S3 backup contains $file_count files"
        fi
    fi
}

# Create backup summary
create_summary() {
    print_step "Backup Summary"

    local summary_file="$BACKUP_DIR/$ENVIRONMENT/backup-$TIMESTAMP.summary"

    cat > "$summary_file" << EOF
Elephant Backup Summary
=======================
Timestamp: $TIMESTAMP
Environment: $ENVIRONMENT
Date: $(date)

PostgreSQL Backup:
EOF

    if [ "$S3_ONLY" != true ]; then
        local pg_backup="$BACKUP_DIR/$ENVIRONMENT/postgres-$TIMESTAMP.sql.gz"
        if [ -f "$pg_backup" ]; then
            echo "  File: $(basename "$pg_backup")" >> "$summary_file"
            echo "  Size: $(du -h "$pg_backup" | cut -f1)" >> "$summary_file"
            echo "  Database: $PG_DATABASE" >> "$summary_file"
        else
            echo "  Status: Not performed" >> "$summary_file"
        fi
    else
        echo "  Status: Skipped (--s3-only)" >> "$summary_file"
    fi

    cat >> "$summary_file" << EOF

S3/MinIO Backup:
EOF

    if [ "$POSTGRES_ONLY" != true ]; then
        local s3_backup="$BACKUP_DIR/$ENVIRONMENT/s3-$TIMESTAMP"
        if [ -d "$s3_backup" ]; then
            echo "  Directory: $(basename "$s3_backup")" >> "$summary_file"
            echo "  Size: $(du -sh "$s3_backup" | cut -f1)" >> "$summary_file"
            echo "  Files: $(find "$s3_backup" -type f | wc -l)" >> "$summary_file"
            echo "  Bucket: $S3_BUCKET" >> "$summary_file"
        else
            echo "  Status: Not performed" >> "$summary_file"
        fi
    else
        echo "  Status: Skipped (--postgres-only)" >> "$summary_file"
    fi

    cat "$summary_file"
}

# Show restore instructions
show_restore_instructions() {
    print_step "Restore Instructions"

    cat << EOF

To restore from this backup:

PostgreSQL:
  # Restore database
  gunzip -c $BACKUP_DIR/$ENVIRONMENT/postgres-$TIMESTAMP.sql.gz | \\
    psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE

S3/MinIO:
  # Using AWS CLI
  aws s3 sync $BACKUP_DIR/$ENVIRONMENT/s3-$TIMESTAMP s3://$S3_BUCKET \\
    --endpoint-url $S3_ENDPOINT

  # Using MinIO client
  mc mirror $BACKUP_DIR/$ENVIRONMENT/s3-$TIMESTAMP backup-target/$S3_BUCKET

Kubernetes:
  # Copy backup to pod and restore
  kubectl cp $BACKUP_DIR/$ENVIRONMENT/postgres-$TIMESTAMP.sql.gz \\
    postgres-0:/tmp/ -n elephant

  kubectl exec -it postgres-0 -n elephant -- \\
    gunzip -c /tmp/postgres-$TIMESTAMP.sql.gz | \\
    psql -U postgres -d elephant

EOF
}

# Main script
main() {
    echo "========================================"
    echo "Elephant Backup Script"
    echo "========================================"
    echo "Environment: $ENVIRONMENT"
    echo "Timestamp: $TIMESTAMP"
    echo "Backup Directory: $BACKUP_DIR"
    echo "========================================"
    echo

    check_prerequisites
    create_backup_dir
    backup_postgres
    backup_s3
    verify_backups
    clean_old_backups
    create_summary
    show_restore_instructions

    print_step "Backup Complete!"
    print_info "✓ Backup saved to: $BACKUP_DIR/$ENVIRONMENT"
}

# Run main script
main
