#!/bin/bash

# Elephant Handbook - Kubernetes Deployment Script
# Deploys Elephant to Kubernetes cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${ENVIRONMENT:-dev}"
NAMESPACE="elephant"
KUSTOMIZE_DIR="kubernetes/overlays/$ENVIRONMENT"

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
        --env|--environment)
            ENVIRONMENT="$2"
            KUSTOMIZE_DIR="kubernetes/overlays/$ENVIRONMENT"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --help)
            cat << EOF
Usage: $0 [OPTIONS]

Options:
  --env, --environment ENV    Deployment environment (dev, staging, production)
                              Default: dev
  --namespace NAMESPACE       Kubernetes namespace
                              Default: elephant
  --help                      Show this help message

Examples:
  $0                          # Deploy to dev environment
  $0 --env staging            # Deploy to staging
  $0 --env production         # Deploy to production

Prerequisites:
  - kubectl configured for target cluster
  - Required secrets created
  - Kustomize overlays configured

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

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    else
        print_info "✓ kubectl $(kubectl version --client --short 2>/dev/null | head -1)"
    fi

    # Check cluster connection
    if ! kubectl cluster-info &>/dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_error "Please configure kubectl first"
        exit 1
    else
        local context=$(kubectl config current-context)
        print_info "✓ Connected to cluster: $context"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi

    # Check if kustomize directory exists
    if [ ! -d "$KUSTOMIZE_DIR" ]; then
        print_error "Kustomize directory not found: $KUSTOMIZE_DIR"
        print_error "Available environments:"
        ls -1 kubernetes/overlays/ 2>/dev/null || echo "  (none found)"
        exit 1
    fi

    print_info "All prerequisites satisfied"
}

# Create namespace
create_namespace() {
    print_step "Creating Namespace"

    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        print_info "Namespace $NAMESPACE already exists"
    else
        print_info "Creating namespace $NAMESPACE..."
        kubectl create namespace "$NAMESPACE"
        print_info "✓ Namespace created"
    fi
}

# Check secrets
check_secrets() {
    print_step "Checking Secrets"

    local required_secrets=(
        "postgres-credentials"
        "s3-credentials"
        "postgres-connection"
    )

    local missing_secrets=()

    for secret in "${required_secrets[@]}"; do
        if kubectl get secret "$secret" -n "$NAMESPACE" &>/dev/null; then
            print_info "✓ Secret $secret exists"
        else
            print_warn "✗ Secret $secret not found"
            missing_secrets+=("$secret")
        fi
    done

    if [ ${#missing_secrets[@]} -gt 0 ]; then
        print_warn "Missing secrets. Create them with:"
        echo
        for secret in "${missing_secrets[@]}"; do
            case $secret in
                postgres-credentials)
                    echo "kubectl create secret generic postgres-credentials \\"
                    echo "  --from-literal=username=postgres \\"
                    echo "  --from-literal=password=YOUR_PASSWORD \\"
                    echo "  --namespace $NAMESPACE"
                    echo
                    ;;
                s3-credentials)
                    echo "kubectl create secret generic s3-credentials \\"
                    echo "  --from-literal=access-key-id=YOUR_ACCESS_KEY \\"
                    echo "  --from-literal=secret-access-key=YOUR_SECRET_KEY \\"
                    echo "  --namespace $NAMESPACE"
                    echo
                    ;;
                postgres-connection)
                    echo "kubectl create secret generic postgres-connection \\"
                    echo "  --from-literal=connection-string='postgres://USER:PASS@HOST:5432/elephant?sslmode=require' \\"
                    echo "  --namespace $NAMESPACE"
                    echo
                    ;;
            esac
        done

        read -p "Continue without these secrets? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Deploy with kustomize
deploy_kustomize() {
    print_step "Deploying with Kustomize"

    print_info "Environment: $ENVIRONMENT"
    print_info "Namespace: $NAMESPACE"
    print_info "Kustomize directory: $KUSTOMIZE_DIR"
    echo

    # Show what will be deployed
    print_info "Resources to be deployed:"
    kubectl kustomize "$KUSTOMIZE_DIR" | grep -E "^(apiVersion|kind|metadata:)" | head -20
    echo "  ..."
    echo

    # Confirm deployment
    if [ "$ENVIRONMENT" = "production" ]; then
        print_warn "⚠️  You are deploying to PRODUCTION"
        read -p "Are you sure you want to continue? (yes/no) " -r
        echo
        if [[ ! $REPLY = "yes" ]]; then
            print_info "Deployment cancelled"
            exit 0
        fi
    else
        read -p "Deploy to $ENVIRONMENT? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deployment cancelled"
            exit 0
        fi
    fi

    # Apply with kubectl
    print_info "Applying manifests..."
    kubectl apply -k "$KUSTOMIZE_DIR"

    print_info "✓ Manifests applied"
}

# Wait for deployments
wait_for_deployments() {
    print_step "Waiting for Deployments"

    local deployments=(
        "elephant-repository"
        "elephant-index"
        "elephant-user"
    )

    for deployment in "${deployments[@]}"; do
        if kubectl get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
            print_info "Waiting for $deployment..."
            kubectl rollout status deployment/"$deployment" -n "$NAMESPACE" --timeout=5m || true
        fi
    done

    # Check StatefulSets
    if kubectl get statefulset postgres -n "$NAMESPACE" &>/dev/null; then
        print_info "Waiting for postgres StatefulSet..."
        kubectl rollout status statefulset/postgres -n "$NAMESPACE" --timeout=5m || true
    fi
}

# Display status
display_status() {
    print_step "Deployment Status"

    print_info "Pods:"
    kubectl get pods -n "$NAMESPACE" -o wide

    echo
    print_info "Services:"
    kubectl get services -n "$NAMESPACE"

    echo
    print_info "Ingress (if any):"
    kubectl get ingress -n "$NAMESPACE" 2>/dev/null || echo "  No ingress found"

    echo
    print_info "Persistent Volume Claims:"
    kubectl get pvc -n "$NAMESPACE"
}

# Show access instructions
show_access_instructions() {
    print_step "Access Instructions"

    # Get service URLs
    local repo_service=$(kubectl get svc elephant-repository -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

    if [ -z "$repo_service" ]; then
        cat << EOF

Services are running in cluster. To access them:

1. Port Forward (for local access):
   kubectl port-forward -n $NAMESPACE svc/elephant-repository 1080:1080

2. Ingress (if configured):
   kubectl get ingress -n $NAMESPACE

3. LoadBalancer (if configured):
   kubectl get svc -n $NAMESPACE

4. Check logs:
   kubectl logs -f deployment/elephant-repository -n $NAMESPACE

5. Exec into pod:
   kubectl exec -it deployment/elephant-repository -n $NAMESPACE -- sh

EOF
    else
        cat << EOF

Services are accessible at:
  Repository: http://$repo_service:1080

To access other services:
  kubectl get services -n $NAMESPACE

To check logs:
  kubectl logs -f deployment/elephant-repository -n $NAMESPACE

EOF
    fi
}

# Show rollback instructions
show_rollback_instructions() {
    print_step "Rollback Instructions"

    cat << EOF

If something goes wrong, you can rollback:

# View deployment history
kubectl rollout history deployment/elephant-repository -n $NAMESPACE

# Rollback to previous version
kubectl rollout undo deployment/elephant-repository -n $NAMESPACE

# Rollback to specific revision
kubectl rollout undo deployment/elephant-repository -n $NAMESPACE --to-revision=2

# Delete everything
kubectl delete -k $KUSTOMIZE_DIR

EOF
}

# Main script
main() {
    echo "========================================"
    echo "Elephant Kubernetes Deployment"
    echo "========================================"
    echo "Environment: $ENVIRONMENT"
    echo "Namespace: $NAMESPACE"
    echo "========================================"
    echo

    check_prerequisites
    create_namespace
    check_secrets
    deploy_kustomize
    wait_for_deployments
    display_status
    show_access_instructions
    show_rollback_instructions

    print_step "Deployment Complete!"
    print_info "✓ Elephant deployed to $ENVIRONMENT environment"
}

# Run main script
main
