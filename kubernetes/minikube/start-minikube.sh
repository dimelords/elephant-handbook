#!/bin/bash

# Elephant Minikube Startup Script
# Starts Minikube with appropriate resources and deploys Elephant

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo "  _____ _             _                 _"
    echo " | ____| | ___ _ __ | |__   __ _ _ __ | |_"
    echo " |  _| | |/ _ \ '_ \| '_ \ / _\` | '_ \| __|"
    echo " | |___| |  __/ |_) | | | | (_| | | | | |_"
    echo " |_____|_|\___| .__/|_| |_|\__,_|_| |_|\__|"
    echo "              |_|"
    echo "    Minikube Local Deployment"
    echo -e "${NC}"
}

check_prerequisites() {
    print_step "Checking Prerequisites"

    if ! command -v minikube &> /dev/null; then
        print_error "Minikube not found. Install with: brew install minikube"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Install with: brew install kubectl"
        exit 1
    fi

    print_info "✓ Minikube: $(minikube version --short)"
    print_info "✓ kubectl: $(kubectl version --client --short)"
}

start_minikube() {
    print_step "Starting Minikube"

    # Check if already running
    if minikube status &> /dev/null; then
        print_info "Minikube is already running"
        return
    fi

    print_info "Starting Minikube with:"
    print_info "  • CPUs: 4"
    print_info "  • Memory: 8GB"
    print_info "  • Disk: 40GB"
    print_info "  • Driver: docker"
    echo

    minikube start \
        --cpus=4 \
        --memory=8192 \
        --disk-size=40g \
        --driver=docker \
        --kubernetes-version=v1.28.0

    print_info "✓ Minikube started successfully"

    # Enable addons
    print_info "Enabling addons..."
    minikube addons enable storage-provisioner
    minikube addons enable default-storageclass
    minikube addons enable metrics-server

    print_info "✓ Addons enabled"
}

configure_vm_settings() {
    print_step "Configuring VM Settings"

    print_info "Setting vm.max_map_count for OpenSearch..."
    minikube ssh 'sudo sysctl -w vm.max_map_count=262144'

    print_info "✓ VM settings configured"
}

deploy_elephant() {
    print_step "Deploying Elephant"

    print_info "Applying Kubernetes manifests..."
    kubectl apply -k "$(dirname "$0")"

    print_info "✓ Manifests applied"

    print_info "Waiting for pods to start (this may take 3-5 minutes)..."
    echo

    # Wait for namespace
    kubectl wait --for=condition=Ready namespace/elephant --timeout=30s 2>/dev/null || true

    # Wait for infrastructure pods
    print_info "Waiting for infrastructure..."
    kubectl wait --for=condition=Ready pod -l app=postgres -n elephant --timeout=300s 2>/dev/null || print_warn "PostgreSQL taking longer than expected"
    kubectl wait --for=condition=Ready pod -l app=keycloak-postgres -n elephant --timeout=300s 2>/dev/null || print_warn "Keycloak DB taking longer than expected"
    kubectl wait --for=condition=Ready pod -l app=minio -n elephant --timeout=300s 2>/dev/null || print_warn "MinIO taking longer than expected"
    kubectl wait --for=condition=Ready pod -l app=opensearch -n elephant --timeout=300s 2>/dev/null || print_warn "OpenSearch taking longer than expected"

    # Wait for Keycloak
    print_info "Waiting for Keycloak..."
    kubectl wait --for=condition=Ready pod -l app=keycloak -n elephant --timeout=300s 2>/dev/null || print_warn "Keycloak taking longer than expected"

    # Wait for Elephant services
    print_info "Waiting for Elephant services..."
    kubectl wait --for=condition=Ready pod -l app=elephant-repository -n elephant --timeout=300s 2>/dev/null || print_warn "Repository taking longer than expected"
    kubectl wait --for=condition=Ready pod -l app=elephant-index -n elephant --timeout=300s 2>/dev/null || print_warn "Index taking longer than expected"
    kubectl wait --for=condition=Ready pod -l app=elephant-user -n elephant --timeout=300s 2>/dev/null || print_warn "User taking longer than expected"

    print_info "✓ Deployment complete"
}

show_status() {
    print_step "Service Status"

    kubectl get pods -n elephant

    echo
    print_info "Checking service health..."
    kubectl get svc -n elephant
}

show_access_info() {
    print_step "🎉 Elephant is Running on Minikube!"

    MINIKUBE_IP=$(minikube ip)

    echo -e "${CYAN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ACCESS SERVICES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"

    echo "  🔐 Keycloak Admin:     http://${MINIKUBE_IP}:30080/admin"
    echo "      Username:  admin"
    echo "      Password:  admin"
    echo
    echo "  📦 Repository API:     http://${MINIKUBE_IP}:31080/twirp/"
    echo "  🔍 Index API:          http://${MINIKUBE_IP}:31082/twirp/"
    echo "  👤 User API:           http://${MINIKUBE_IP}:31083/twirp/"
    echo
    echo "  📊 MinIO Console:      http://${MINIKUBE_IP}:30901"
    echo "      Username:  minioadmin"
    echo "      Password:  minioadmin"
    echo

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  USEFUL COMMANDS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo "  View logs:"
    echo "    kubectl logs -n elephant -l app=elephant-repository -f"
    echo
    echo "  Access PostgreSQL:"
    echo "    kubectl exec -it -n elephant postgres-0 -- psql -U postgres -d elephant"
    echo
    echo "  Port forward (alternative to NodePort):"
    echo "    kubectl port-forward -n elephant svc/keycloak 8080:8080"
    echo
    echo "  Minikube dashboard:"
    echo "    minikube dashboard"
    echo
    echo "  Stop Minikube:"
    echo "    minikube stop"
    echo
    echo "  Delete everything:"
    echo "    minikube delete"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

main() {
    print_banner

    check_prerequisites
    start_minikube
    configure_vm_settings
    deploy_elephant
    show_status
    show_access_info

    print_info "Setup complete! Elephant is running on Minikube."
}

main "$@"
