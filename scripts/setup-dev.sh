#!/bin/bash

# Elephant Handbook - Development Environment Setup Script
# Sets up a complete local development environment for Elephant

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ELEPHANT_DIR="${1:-$(pwd)/elephant-repos}"
POSTGRES_VERSION="${POSTGRES_VERSION:-16}"
OPENSEARCH_VERSION="${OPENSEARCH_VERSION:-2.11.0}"

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

    # Check Go
    if ! command -v go &> /dev/null; then
        missing+=("Go 1.23+")
    else
        print_info "✓ Go $(go version | awk '{print $3}')"
    fi

    # Check Node.js
    if ! command -v node &> /dev/null; then
        missing+=("Node.js")
    else
        print_info "✓ Node.js $(node --version)"
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing+=("Docker")
    else
        print_info "✓ Docker $(docker --version | awk '{print $3}' | tr -d ',')"
    fi

    # Check Mage
    if ! command -v mage &> /dev/null; then
        print_warn "Mage not found. Will install..."
        go install github.com/magefile/mage@latest
        print_info "✓ Mage installed"
    else
        print_info "✓ Mage $(mage -version 2>&1 | head -n 1)"
    fi

    # Check gh CLI
    if ! command -v gh &> /dev/null; then
        missing+=("GitHub CLI (gh)")
    else
        print_info "✓ GitHub CLI $(gh --version | head -n 1 | awk '{print $3}')"
    fi

    # Check psql
    if ! command -v psql &> /dev/null; then
        print_warn "PostgreSQL client (psql) not found"
    else
        print_info "✓ PostgreSQL client $(psql --version | awk '{print $3}')"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing[@]}"; do
            echo "  - $tool"
        done
        echo
        echo "Please install the missing tools and try again."
        echo "See: https://github.com/dimelords/elephant-handbook#prerequisites"
        exit 1
    fi

    print_info "All prerequisites satisfied!"
}

# Setup PostgreSQL
setup_postgres() {
    print_step "Setting up PostgreSQL"

    cd "$ELEPHANT_DIR/elephant-repository"

    print_info "Starting PostgreSQL container..."
    mage sql:postgres "pg$POSTGRES_VERSION" || print_warn "PostgreSQL may already be running"

    # Wait for PostgreSQL to be ready
    print_info "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        if docker exec elephant-postgres pg_isready -U postgres &>/dev/null; then
            print_info "PostgreSQL is ready!"
            break
        fi
        sleep 1
    done

    print_info "Creating database..."
    mage sql:db || print_warn "Database may already exist"

    print_info "Running migrations..."
    mage sql:migrate

    print_info "Creating reporting user..."
    mage reportinguser || print_warn "Reporting user may already exist"

    print_info "Setting replication permissions..."
    mage replicationpermissions

    print_info "✓ PostgreSQL setup complete"
}

# Setup MinIO
setup_minio() {
    print_step "Setting up MinIO (S3-compatible storage)"

    cd "$ELEPHANT_DIR/elephant-repository"

    print_info "Starting MinIO container..."
    mage s3:minio || print_warn "MinIO may already be running"

    # Wait for MinIO to be ready
    print_info "Waiting for MinIO to be ready..."
    sleep 5

    print_info "Creating S3 buckets..."
    mage s3:bucket elephant-archive || print_warn "Bucket may already exist"
    mage s3:bucket elephant-reports || print_warn "Bucket may already exist"

    print_info "✓ MinIO setup complete"
    print_info "  Console: http://localhost:9001 (minioadmin/minioadmin)"
}

# Setup OpenSearch (optional)
setup_opensearch() {
    print_step "Setting up OpenSearch (Optional)"

    read -p "Do you want to setup OpenSearch for search functionality? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping OpenSearch setup"
        return
    fi

    print_info "Starting OpenSearch container..."

    if docker ps -a --format '{{.Names}}' | grep -q "^elephant-opensearch$"; then
        print_warn "OpenSearch container already exists"
        docker start elephant-opensearch || true
    else
        docker run -d \
            --name elephant-opensearch \
            -p 9200:9200 \
            -p 9600:9600 \
            -e "discovery.type=single-node" \
            -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=Admin123!" \
            -e "DISABLE_SECURITY_PLUGIN=true" \
            "opensearchproject/opensearch:$OPENSEARCH_VERSION"
    fi

    # Wait for OpenSearch to be ready
    print_info "Waiting for OpenSearch to be ready..."
    for i in {1..60}; do
        if curl -s http://localhost:9200 &>/dev/null; then
            print_info "OpenSearch is ready!"
            break
        fi
        sleep 2
    done

    print_info "✓ OpenSearch setup complete"
    print_info "  URL: http://localhost:9200"
}

# Setup elephant-repository
setup_repository() {
    print_step "Setting up elephant-repository"

    cd "$ELEPHANT_DIR/elephant-repository"

    # Create .env file
    print_info "Creating .env file..."
    cat > .env << 'EOF'
S3_ENDPOINT=http://localhost:9000/
S3_ACCESS_KEY_ID=minioadmin
S3_ACCESS_KEY_SECRET=minioadmin
MOCK_JWT_SIGNING_KEY='MIGkAgEBBDAgdjcifmVXiJoQh7IbTnsCS81CxYHQ1r6ftXE6ykJDz1SoQJEB6LppaCLpNBJhGNugBwYFK4EEACKhZANiAAS4LqvuFUwFXUNpCPTtgeMy61hE-Pdm57OVzTaVKUz7GzzPKNoGbcTllPGDg7nzXIga9ObRNs8ytSLQMOWIO8xJW35Xko4kwPR_CVsTS5oMaoYnBCOZYEO2NXND7gU7GoM'
EOF

    print_info "Building elephant-repository..."
    go build -o elephant-repository ./cmd/elephant-repository

    print_info "✓ elephant-repository is ready"
    print_info "  Start with: ./elephant-repository"
    print_info "  API: http://localhost:1080"
}

# Setup elephant-chrome
setup_chrome() {
    print_step "Setting up elephant-chrome"

    cd "$ELEPHANT_DIR/elephant-chrome"

    print_info "Installing npm dependencies..."
    npm install

    # Create .env file
    print_info "Creating .env file..."
    cat > .env << 'EOF'
VITE_REPOSITORY_URL=http://localhost:1080
VITE_DEV_SERVER_PORT=5173
VITE_HMR_PORT=6000
EOF

    print_info "✓ elephant-chrome is ready"
    print_info "  Start dev server: npm run dev:web"
    print_info "  Start CSS watcher: npm run dev:css"
    print_info "  URL: http://localhost:5173"
}

# Setup elephant-index (optional)
setup_index() {
    print_step "Setting up elephant-index (Optional)"

    if ! docker ps --format '{{.Names}}' | grep -q "^elephant-opensearch$"; then
        print_warn "OpenSearch is not running, skipping elephant-index setup"
        return
    fi

    cd "$ELEPHANT_DIR/elephant-index"

    # Create .env file
    print_info "Creating .env file..."
    cat > .env << 'EOF'
REPOSITORY_URL=http://localhost:1080
OPENSEARCH_URL=http://localhost:9200
OPENSEARCH_USERNAME=admin
OPENSEARCH_PASSWORD=Admin123!
EOF

    print_info "Building elephant-index..."
    go build -o elephant-index ./cmd/elephant-index

    print_info "✓ elephant-index is ready"
    print_info "  Start with: ./elephant-index"
}

# Create startup script
create_startup_script() {
    print_step "Creating startup script"

    cat > "$ELEPHANT_DIR/start-all.sh" << 'EOF'
#!/bin/bash

# Start all Elephant services

set -e

ELEPHANT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting Elephant services..."
echo

# Start PostgreSQL and MinIO (if not already running)
cd "$ELEPHANT_DIR/elephant-repository"
docker start elephant-postgres || echo "PostgreSQL already running"
docker start elephant-minio || echo "MinIO already running"

# Start OpenSearch (if it exists)
docker start elephant-opensearch 2>/dev/null || true

echo
echo "Databases started. Waiting 5 seconds..."
sleep 5

echo
echo "Start the following services in separate terminals:"
echo
echo "Terminal 1 - Repository:"
echo "  cd $ELEPHANT_DIR/elephant-repository"
echo "  ./elephant-repository"
echo
echo "Terminal 2 - Frontend (Web):"
echo "  cd $ELEPHANT_DIR/elephant-chrome"
echo "  npm run dev:web"
echo
echo "Terminal 3 - Frontend (CSS):"
echo "  cd $ELEPHANT_DIR/elephant-chrome"
echo "  npm run dev:css"
echo
echo "Terminal 4 - Index (if OpenSearch is running):"
echo "  cd $ELEPHANT_DIR/elephant-index"
echo "  ./elephant-index"
echo
echo "Elephant will be available at:"
echo "  Frontend: http://localhost:5173"
echo "  Repository API: http://localhost:1080"
echo "  MinIO Console: http://localhost:9001 (minioadmin/minioadmin)"
echo

# Get mock token
echo "To get a development token:"
echo "  curl http://localhost:1080/token \\"
echo "    -d grant_type=password \\"
echo "    -d 'username=Dev User <user://dev/1, unit://dev/unit1>' \\"
echo "    -d 'scope=doc_read doc_write doc_delete'"
echo
EOF

    chmod +x "$ELEPHANT_DIR/start-all.sh"

    print_info "✓ Created startup script: $ELEPHANT_DIR/start-all.sh"
}

# Main setup
main() {
    echo "========================================"
    echo "Elephant Development Environment Setup"
    echo "========================================"
    echo

    check_prerequisites

    # Check if repositories exist
    if [ ! -d "$ELEPHANT_DIR/elephant-repository" ]; then
        print_error "Elephant repositories not found at: $ELEPHANT_DIR"
        echo
        echo "Please run the clone script first:"
        echo "  $(dirname "$0")/clone-all-repos.sh $ELEPHANT_DIR"
        exit 1
    fi

    setup_postgres
    setup_minio
    setup_opensearch
    setup_repository
    setup_chrome
    setup_index
    create_startup_script

    # Summary
    print_step "Setup Complete!"

    cat << EOF
Development environment is ready!

Directory: $ELEPHANT_DIR

Services configured:
  ✓ PostgreSQL (port 5432)
  ✓ MinIO (ports 9000, 9001)
$(docker ps --format '{{.Names}}' | grep -q "elephant-opensearch" && echo "  ✓ OpenSearch (port 9200)" || echo "  ⊘ OpenSearch (not configured)")
  ✓ elephant-repository (ready to start)
  ✓ elephant-chrome (ready to start)
$([ -f "$ELEPHANT_DIR/elephant-index/elephant-index" ] && echo "  ✓ elephant-index (ready to start)" || echo "  ⊘ elephant-index (not configured)")

To start all services:
  $ELEPHANT_DIR/start-all.sh

Or start services manually:

  Terminal 1 - Repository:
    cd $ELEPHANT_DIR/elephant-repository && ./elephant-repository

  Terminal 2 - Frontend (Web):
    cd $ELEPHANT_DIR/elephant-chrome && npm run dev:web

  Terminal 3 - Frontend (CSS):
    cd $ELEPHANT_DIR/elephant-chrome && npm run dev:css

Access:
  Frontend: http://localhost:5173
  Repository API: http://localhost:1080
  MinIO Console: http://localhost:9001 (minioadmin/minioadmin)

Get a development token:
  curl http://localhost:1080/token \\
    -d grant_type=password \\
    -d 'username=Dev User <user://dev/1, unit://dev/unit1>' \\
    -d 'scope=doc_read doc_write doc_delete'

Happy coding! 🐘
EOF
}

# Run main setup
main
