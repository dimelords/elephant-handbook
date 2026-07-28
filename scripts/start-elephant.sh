#!/bin/bash

# Elephant Interactive Startup Script
# Starts core services and optionally adds spell and observability

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HANDBOOK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_DIR="$HANDBOOK_DIR/docker-compose"

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
    echo -e "${BLUE}━━━━ $1 ━━━━${NC}"
    echo
}

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
  _____ _             _                 _
 | ____| | ___ _ __ | |__   __ _ _ __ | |_
 |  _| | |/ _ \ '_ \| '_ \ / _` | '_ \| __|
 | |___| |  __/ |_) | | | | (_| | | | | |_
 |_____|_|\___| .__/|_| |_|\__,_|_| |_|\__|
              |_|
    The doc of fate - Interactive Setup
EOF
    echo -e "${NC}"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    while true; do
        echo -ne "${MAGENTA}${prompt}${NC}"
        read -r response
        response=${response:-$default}
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

check_prerequisites() {
    print_step "Checking Prerequisites"

    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker Desktop."
        exit 1
    fi

    if ! command -v docker compose &> /dev/null; then
        print_error "Docker Compose not found. Please install Docker Desktop."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_warn "jq not found. Install with: brew install jq"
        print_warn "jq is needed for token testing but not required for startup"
    fi

    if ! command -v mkcert &> /dev/null; then
        print_warn "mkcert not found. Install with: brew install mkcert"
        print_warn "mkcert is needed for HTTPS certificates"
    fi

    print_info "✓ Docker $(docker --version | awk '{print $3}' | tr -d ',')"
    print_info "✓ Docker Compose $(docker compose version | awk '{print $4}')"
}

check_ports() {
    print_step "Checking for Port Conflicts"

    # Host ports docker-compose.core.yml binds. If another project already owns one
    # of these (e.g. a differently-named Postgres/Keycloak stack), docker compose fails
    # deep into the build/pull step with a cryptic "port is already allocated" error.
    # Ports already held by our own elephant-* containers (e.g. a rerun after a partial
    # start) are expected and not a real conflict, so those are excluded.
    local ports=(5432 5434 6379 8280 8443 9000 9001 9200 9600)
    local conflicts=()
    local our_containers
    our_containers=$(docker ps --format '{{.Names}} {{.Ports}}' | grep '^elephant-' || true)

    for port in "${ports[@]}"; do
        if lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | grep -q ":${port} "; then
            if ! echo "$our_containers" | grep -q ":${port}->"; then
                conflicts+=("$port")
            fi
        fi
    done

    if [ ${#conflicts[@]} -gt 0 ]; then
        print_error "Port(s) already in use: ${conflicts[*]}"
        print_warn "These are hardcoded host ports in docker-compose.core.yml."
        print_warn "Find what's holding them with: lsof -iTCP -sTCP:LISTEN -P -n | grep -E ':($(IFS='|'; echo "${conflicts[*]}"))\\b'"
        print_warn "Either stop the conflicting container/process, or remap the port in"
        print_warn "docker-compose.core.yml (and the matching references in this scripts/ dir)."
        if ! ask_yes_no "Continue anyway?" "n"; then
            exit 1
        fi
    else
        print_info "✓ No port conflicts detected"
    fi
}

setup_certificates() {
    print_step "Setting up HTTPS Certificates"
    
    cd "$SCRIPT_DIR"
    if [ -f "./setup-certs.sh" ]; then
        print_info "Running certificate setup..."
        ./setup-certs.sh
    else
        print_warn "setup-certs.sh not found, skipping certificate setup"
        print_warn "HTTPS will not be available"
    fi
}

check_docker_running() {
    print_step "Checking Docker Status"

    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi

    print_info "Docker is running"
}

start_infrastructure() {
    print_step "Starting Infrastructure Services"
    
    export COMPOSE_PROJECT_NAME="elephant"
    
    print_info "Starting infrastructure services..."
    print_info "  • PostgreSQL (main + Keycloak)"
    print_info "  • Keycloak (authentication)"
    print_info "  • MinIO (S3 storage)"
    print_info "  • Redis (elephant-chrome collaboration cache)"
    print_info "  • OpenSearch (search engine)"
    echo

    cd "$COMPOSE_DIR"
    # Start only infrastructure services
    docker compose -f docker-compose.core.yml up -d postgres keycloak-postgres keycloak minio redis opensearch minio-init
    
    print_info "Waiting for infrastructure to be healthy..."
    sleep 10
    
    # Wait for Keycloak
    print_info "Waiting for Keycloak..."
    for i in {1..60}; do
        if curl -sf http://localhost:8280/health/ready &>/dev/null; then
            print_info "✓ Keycloak is ready"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo
}

start_elephant_services() {
    print_step "Starting Elephant Services"
    
    # Read the client secret generated by Keycloak setup
    if [ -f "/tmp/elephant-client-secret.txt" ]; then
        export ELEPHANT_CLIENT_SECRET=$(cat /tmp/elephant-client-secret.txt)
        print_info "Using client secret from Keycloak setup"
    else
        print_error "Client secret not found! Keycloak setup may have failed."
        exit 1
    fi
    
    print_info "Starting Elephant services..."
    print_info "  • elephant-repository"
    print_info "  • elephant-index (with automatic migrations)"
    print_info "  • elephant-user (with automatic migrations)"
    echo
    
    cd "$COMPOSE_DIR"
    # Start Elephant services (they depend on Keycloak realm being configured)
    docker compose -f docker-compose.core.yml up -d repository index-migrate index user-migrate user
    
    print_info "Waiting for services to be healthy..."
    sleep 15
    
    # Clean up init containers
    print_info "Cleaning up init containers..."
    docker rm "elephant-index-migrate-1" 2>/dev/null || true
    docker rm "elephant-user-migrate-1" 2>/dev/null || true
    docker rm "elephant-minio-init-1" 2>/dev/null || true
}

setup_keycloak() {
    print_step "Configuring Keycloak"
    
    # Find the Keycloak container
    KEYCLOAK_CONTAINER=$(docker ps --format '{{.Names}}' | grep "elephant-keycloak-1")
    
    if [ -z "$KEYCLOAK_CONTAINER" ]; then
        print_error "Could not find Keycloak container"
        return 1
    fi
    
    print_info "Using Keycloak container: $KEYCLOAK_CONTAINER"
    
    cd "$SCRIPT_DIR"
    if [ -f "./setup-keycloak.sh" ]; then
        print_info "Running Keycloak setup script..."
        KEYCLOAK_CONTAINER="$KEYCLOAK_CONTAINER" ./setup-keycloak.sh
    else
        print_error "setup-keycloak.sh not found!"
        print_warn "You'll need to configure Keycloak manually"
        return 1
    fi
}

start_spell_service() {
    print_step "Starting Spell Service"
    
    print_info "Starting elephant-spell (spellcheck service with migrations)..."
    cd "$COMPOSE_DIR"
    docker compose -f docker-compose.spell.yml up -d
    
    # Clean up spell-migrate init container
    sleep 5
    docker rm "elephant-spell-migrate-1" 2>/dev/null || true
    
    print_info "✓ Spell service started on port 1084"
}

start_observability() {
    print_step "Starting Observability Stack"
    
    print_info "Starting full observability stack..."
    print_info "  • Prometheus (metrics)"
    print_info "  • Loki (logs)"
    print_info "  • Tempo (traces)"
    print_info "  • Alloy (Faro receiver)"
    print_info "  • Grafana (dashboards)"
    cd "$COMPOSE_DIR"
    
    # Check if config files exist
    if [ ! -f "../configs/observability/prometheus/prometheus.yml" ]; then
        print_warn "Prometheus config not found at ../configs/observability/prometheus/prometheus.yml"
    fi
    if [ ! -f "../configs/observability/tempo/tempo.yaml" ]; then
        print_warn "Tempo config not found at ../configs/observability/tempo/tempo.yaml"
    fi
    if [ ! -f "../configs/observability/alloy/config.alloy" ]; then
        print_warn "Alloy config not found at ../configs/observability/alloy/config.alloy"
    fi
    
    docker compose -f docker-compose.observability.yml up -d
    
    print_info "✓ Prometheus started on port 9090"
    print_info "✓ Loki started on port 3100"
    print_info "✓ Tempo started on ports 3200, 4317, 4318"
    print_info "✓ Alloy started on ports 12345 (UI), 12346 (Faro)"
    print_info "✓ Grafana started on port 3000 (admin/admin)"
}

show_status() {
    print_step "Service Status"
    
    cd "$COMPOSE_DIR"
    docker compose -f docker-compose.core.yml ps
    
    if docker ps --format '{{.Names}}' | grep -q elephant-spell; then
        echo
        print_info "Spell service:"
        docker compose -f docker-compose.spell.yml ps
    fi
    
    if docker ps --format '{{.Names}}' | grep -q elephant-prometheus; then
        echo
        print_info "Observability stack:"
        docker compose -f docker-compose.observability.yml ps
    fi
}

show_summary() {
    print_step "🎉 Elephant is Running!"
    
    echo -e "${CYAN}"
    cat << 'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CORE SERVICES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    echo -e "${NC}"
    
    echo "  🔐 Keycloak Admin:     https://localhost:8443/admin (or http://localhost:8280/admin)"
    echo "      Username:  admin"
    echo "      Password:  admin"
    echo
    echo "  📦 Repository API:     http://localhost:1080/twirp/"
    echo "  🔍 Index API:          http://localhost:1082/twirp/"
    echo "  👤 User API:           http://localhost:1083/twirp/"
    echo
    echo "  📊 MinIO Console:      http://localhost:9001"
    echo "      Username:  minioadmin"
    echo "      Password:  minioadmin"
    echo
    echo "  🔎 OpenSearch:         http://localhost:9200"
    echo "  🗄️  PostgreSQL:         localhost:5432 (postgres/postgres)"
    echo "  🧠 Redis:              localhost:6379 (elephant-chrome collaboration cache)"
    
    if docker ps --format '{{.Names}}' | grep -q elephant-spell; then
        echo
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  OPTIONAL SERVICES${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo "  📝 Spell API:          http://localhost:1084/twirp/"
    fi
    
    if docker ps --format '{{.Names}}' | grep -q "elephant-prometheus"; then
        echo "  📊 Prometheus:         http://localhost:9090"
        echo "  📈 Grafana:            http://localhost:3000 (admin/admin)"
        echo "  📋 Loki:               http://localhost:3100"
        echo "  🔍 Tempo:              http://localhost:3200"
        echo "  🎯 Alloy (Faro):       http://localhost:12345 (UI)"
        echo "                         http://localhost:12346 (Faro endpoint)"
    fi
    
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  TEST USERS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo "  Editor (read/write):   editor / editor"
    echo "  Admin (full access):   admin / admin"
    echo "  Reader (read-only):    reader / reader"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  NEXT STEPS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo "1. Start the frontend (elephant-chrome) with HTTPS:"
    echo "   cd elephant-chrome"
    echo "   npm install"
    echo "   npm run dev"
    echo "   Access at: https://localhost:5173"
    echo
    echo "2. View logs:"
    echo "   cd $COMPOSE_DIR"
    echo "   docker compose -f docker-compose.core.yml logs -f"
    echo
    echo "3. Stop all services:"
    echo "   cd $COMPOSE_DIR"
    echo "   docker compose -f docker-compose.core.yml down"

    if docker ps --format '{{.Names}}' | grep -q elephant-spell; then
        echo "   docker compose -f docker-compose.spell.yml down"
    fi

    if docker ps --format '{{.Names}}' | grep -q "elephant-prometheus"; then
        echo "   docker compose -f docker-compose.observability.yml down"
    fi

    echo
    echo "4. Stop and remove all data:"
    echo "   docker compose -f docker-compose.core.yml down -v"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

initialize_index() {
    print_step "Initializing Index Service"

    cd "$SCRIPT_DIR"
    if [ -f "./initialize-index.sh" ]; then
        print_info "Registering OpenSearch cluster and creating index set..."
        CLIENT_SECRET="$(cat /tmp/elephant-client-secret.txt)" ./initialize-index.sh
    else
        print_error "initialize-index.sh not found!"
        print_warn "You'll need to initialize the index service manually"
        return 1
    fi
}

apply_repository_schemas() {
    print_step "Applying Repository Schemas"

    cd "$SCRIPT_DIR"
    if [ -f "./apply-schemas.sh" ]; then
        print_info "Configuring schemas and document types..."
        CLIENT_SECRET="$(cat /tmp/elephant-client-secret.txt)" ./apply-schemas.sh
    else
        print_error "apply-schemas.sh not found!"
        print_warn "You'll need to apply schemas manually"
        return 1
    fi
}

main() {
    print_banner

    check_prerequisites
    check_docker_running
    check_ports
    setup_certificates

    # Start infrastructure first
    start_infrastructure

    # Configure Keycloak before starting Elephant services
    setup_keycloak

    # Now start Elephant services (they need Keycloak realm to exist)
    start_elephant_services

    echo
    print_info "All core services are running!"
    echo

    # Initialize search index (required for frontend to work)
    if ask_yes_no "Do you want to initialize the index service now? (recommended)" "y"; then
        initialize_index
    else
        print_warn "Skipping index initialization - you'll see 'no active index' errors until you run initialize-index.sh"
    fi

    echo
    # Apply repository schemas (required for document creation)
    if ask_yes_no "Do you want to configure repository schemas now? (recommended)" "y"; then
        apply_repository_schemas
    else
        print_warn "Skipping schema configuration - you'll need to run apply-schemas.sh later"
    fi

    echo
    # Ask about optional services
    if ask_yes_no "Do you want to start the spell service (spellcheck)?" "n"; then
        start_spell_service
    else
        print_info "Skipping spell service"
    fi

    echo
    if ask_yes_no "Do you want to start the observability stack (Prometheus + Grafana)?" "n"; then
        start_observability
    else
        print_info "Skipping observability stack"
    fi

    echo
    show_status
    show_summary
}

# Handle Ctrl+C
trap 'echo -e "\n${YELLOW}Startup interrupted${NC}"; exit 1' INT

# Run main
main
