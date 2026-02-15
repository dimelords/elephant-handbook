#!/bin/bash

# Elephant Handbook - Start Local Services Script
# Starts all Elephant services locally (outside of Docker/k8s)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ELEPHANT_DIR="${1:-$(pwd)}"

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

# Check prerequisites
check_prerequisites() {
    print_step "Checking Prerequisites"

    local missing=()

    if ! command -v docker &> /dev/null; then
        missing+=("Docker")
    fi

    if ! command -v mage &> /dev/null; then
        print_warn "Mage not found (optional for some services)"
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

# Check if services are already running
check_running() {
    print_step "Checking Running Services"

    # Check PostgreSQL
    if docker ps --format '{{.Names}}' | grep -q "elephant-postgres"; then
        print_info "✓ PostgreSQL is running"
    else
        print_warn "✗ PostgreSQL is not running"
    fi

    # Check MinIO
    if docker ps --format '{{.Names}}' | grep -q "elephant-minio"; then
        print_info "✓ MinIO is running"
    else
        print_warn "✗ MinIO is not running"
    fi

    # Check OpenSearch
    if docker ps --format '{{.Names}}' | grep -q "elephant-opensearch"; then
        print_info "✓ OpenSearch is running"
    else
        print_warn "✗ OpenSearch is not running (optional)"
    fi
}

# Start infrastructure services
start_infrastructure() {
    print_step "Starting Infrastructure Services"

    # Start PostgreSQL
    print_info "Starting PostgreSQL..."
    if docker ps -a --format '{{.Names}}' | grep -q "elephant-postgres"; then
        docker start elephant-postgres &>/dev/null || true
    else
        print_warn "PostgreSQL container doesn't exist. Run setup-dev.sh first."
    fi

    # Start MinIO
    print_info "Starting MinIO..."
    if docker ps -a --format '{{.Names}}' | grep -q "elephant-minio"; then
        docker start elephant-minio &>/dev/null || true
    else
        print_warn "MinIO container doesn't exist. Run setup-dev.sh first."
    fi

    # Start OpenSearch (optional)
    if docker ps -a --format '{{.Names}}' | grep -q "elephant-opensearch"; then
        print_info "Starting OpenSearch..."
        docker start elephant-opensearch &>/dev/null || true
    fi

    print_info "Waiting for services to be ready..."
    sleep 5
}

# Display service information
display_info() {
    print_step "Service Information"

    cat << EOF

Infrastructure Services (Docker):
  PostgreSQL:    localhost:5432 (user: postgres, password: postgres)
  MinIO API:     http://localhost:9000 (minioadmin/minioadmin)
  MinIO Console: http://localhost:9001 (minioadmin/minioadmin)
  OpenSearch:    http://localhost:9200 (if running)

Application Services (need to be started manually in separate terminals):

Terminal 1 - Repository Service:
  cd $ELEPHANT_DIR/elephant-repository
  ./elephant-repository
  # Will be available at: http://localhost:1080

Terminal 2 - Index Service (optional):
  cd $ELEPHANT_DIR/elephant-index
  ./elephant-index
  # Will be available at: http://localhost:1081

Terminal 3 - User Service (optional):
  cd $ELEPHANT_DIR/elephant-user
  ./elephant-user
  # Will be available at: http://localhost:1082

Terminal 4 - Frontend (Web):
  cd $ELEPHANT_DIR/elephant-chrome
  npm run dev:web
  # Will be available at: http://localhost:5173

Terminal 5 - Frontend (CSS):
  cd $ELEPHANT_DIR/elephant-chrome
  npm run dev:css

Quick Start Commands:

# Get a development token:
curl http://localhost:1080/token \\
  -d grant_type=password \\
  -d 'username=Dev User <user://dev/user1, unit://dev/unit1>' \\
  -d 'scope=doc_read doc_write doc_delete'

# Health check:
curl http://localhost:1080/healthz

# Create a test document:
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Create \\
  -H "Authorization: Bearer <YOUR_TOKEN>" \\
  -H "Content-Type: application/json" \\
  -d '{"document": {"type": "core/article", "title": "Test"}}'

Tips:
  - Use tmux or screen to manage multiple terminals
  - Check logs if services don't start
  - Ensure .env files are configured in each service directory

EOF
}

# Create tmux session (optional)
create_tmux_session() {
    if command -v tmux &> /dev/null; then
        read -p "Do you want to start services in a tmux session? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Creating tmux session 'elephant'..."

            # Create new session
            tmux new-session -d -s elephant

            # Window 0: Infrastructure info
            tmux rename-window -t elephant:0 'info'
            tmux send-keys -t elephant:0 "echo 'Infrastructure services are running in Docker.'" C-m
            tmux send-keys -t elephant:0 "echo 'Use Ctrl+b then number to switch windows.'" C-m
            tmux send-keys -t elephant:0 "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep elephant" C-m

            # Window 1: Repository
            tmux new-window -t elephant:1 -n 'repository'
            tmux send-keys -t elephant:1 "cd $ELEPHANT_DIR/elephant-repository" C-m
            tmux send-keys -t elephant:1 "./elephant-repository" C-m

            # Window 2: Frontend Web
            tmux new-window -t elephant:2 -n 'frontend-web'
            tmux send-keys -t elephant:2 "cd $ELEPHANT_DIR/elephant-chrome" C-m
            tmux send-keys -t elephant:2 "npm run dev:web" C-m

            # Window 3: Frontend CSS
            tmux new-window -t elephant:3 -n 'frontend-css'
            tmux send-keys -t elephant:3 "cd $ELEPHANT_DIR/elephant-chrome" C-m
            tmux send-keys -t elephant:3 "npm run dev:css" C-m

            # Window 4: Index (optional)
            if [ -f "$ELEPHANT_DIR/elephant-index/elephant-index" ]; then
                tmux new-window -t elephant:4 -n 'index'
                tmux send-keys -t elephant:4 "cd $ELEPHANT_DIR/elephant-index" C-m
                tmux send-keys -t elephant:4 "# ./elephant-index" C-m
            fi

            # Select first window
            tmux select-window -t elephant:0

            print_info "✓ Tmux session 'elephant' created"
            print_info "  Attach with: tmux attach -t elephant"
            print_info "  Detach with: Ctrl+b then d"
            print_info "  Switch windows: Ctrl+b then 0-4"
            print_info "  Kill session: tmux kill-session -t elephant"

            read -p "Attach to tmux session now? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                tmux attach -t elephant
            fi
        fi
    fi
}

# Alternative: Using Docker Compose
suggest_docker_compose() {
    print_step "Alternative: Docker Compose"

    cat << EOF

For an easier setup, consider using Docker Compose:

  cd $ELEPHANT_DIR/../elephant-handbook/docker-compose
  docker compose -f docker-compose.dev.yml up -d

This will start all services including application services in Docker.

See: $ELEPHANT_DIR/../elephant-handbook/docs/03-development/docker-compose.md

EOF
}

# Main script
main() {
    echo "========================================"
    echo "Elephant Local Services Starter"
    echo "========================================"
    echo "Directory: $ELEPHANT_DIR"
    echo "========================================"
    echo

    check_prerequisites

    # Check if elephant-repository exists
    if [ ! -d "$ELEPHANT_DIR/elephant-repository" ]; then
        print_error "elephant-repository not found at: $ELEPHANT_DIR/elephant-repository"
        print_error "Please run clone-all-repos.sh first or specify correct path"
        exit 1
    fi

    check_running
    start_infrastructure
    display_info

    # Offer tmux session
    create_tmux_session

    # Suggest Docker Compose alternative
    suggest_docker_compose

    print_step "Ready!"
    print_info "Infrastructure services are running."
    print_info "Start application services as shown above."
}

# Run main script
main
