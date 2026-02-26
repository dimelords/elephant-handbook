#!/bin/bash

# Elephant Minikube Validation Script
# Validates the Minikube deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_check() {
    echo -e "${GREEN}✓${NC} $1"
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "Validating Elephant Minikube Deployment"
echo "========================================"
echo

# Check Minikube is running
if minikube status &> /dev/null; then
    print_check "Minikube is running"
else
    print_fail "Minikube is not running"
    echo "  Run: ./start-minikube.sh"
    exit 1
fi

# Check namespace exists
if kubectl get namespace elephant &> /dev/null; then
    print_check "Namespace 'elephant' exists"
else
    print_fail "Namespace 'elephant' not found"
    echo "  Run: kubectl apply -k ."
    exit 1
fi

# Check pods
echo
echo "Pod Status:"
echo "-----------"
kubectl get pods -n elephant --no-headers | while read line; do
    name=$(echo $line | awk '{print $1}')
    status=$(echo $line | awk '{print $3}')
    
    if [[ "$status" == "Running" ]]; then
        print_check "$name"
    elif [[ "$status" == "Completed" ]]; then
        print_check "$name (completed)"
    else
        print_warn "$name ($status)"
    fi
done

# Check services
echo
echo "Service Endpoints:"
echo "------------------"
MINIKUBE_IP=$(minikube ip)

# Test each service
services=("keycloak:30080" "repository:31080" "index:31082" "user:31083" "minio:30901")

for svc in "${services[@]}"; do
    name=$(echo $svc | cut -d: -f1)
    port=$(echo $svc | cut -d: -f2)
    
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://${MINIKUBE_IP}:${port}" > /dev/null 2>&1; then
        print_check "$name accessible at http://${MINIKUBE_IP}:${port}"
    else
        print_warn "$name not responding at http://${MINIKUBE_IP}:${port}"
    fi
done

# Check database
echo
echo "Database Status:"
echo "----------------"
if kubectl exec -n elephant postgres-0 -- pg_isready -U postgres &> /dev/null; then
    print_check "PostgreSQL is ready"
    
    # Check database exists
    if kubectl exec -n elephant postgres-0 -- psql -U postgres -lqt | cut -d \| -f 1 | grep -qw elephant; then
        print_check "Database 'elephant' exists"
    else
        print_warn "Database 'elephant' not found"
    fi
else
    print_fail "PostgreSQL is not ready"
fi

# Check OpenSearch
echo
echo "OpenSearch Status:"
echo "------------------"
if kubectl exec -n elephant opensearch-0 -- curl -s http://localhost:9200/_cluster/health &> /dev/null; then
    health=$(kubectl exec -n elephant opensearch-0 -- curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [[ "$health" == "green" ]] || [[ "$health" == "yellow" ]]; then
        print_check "OpenSearch cluster is $health"
    else
        print_warn "OpenSearch cluster is $health"
    fi
else
    print_fail "OpenSearch is not responding"
fi

# Summary
echo
echo "========================================"
echo "Validation Complete"
echo
echo "Access services at:"
echo "  Keycloak: http://${MINIKUBE_IP}:30080/admin"
echo "  Repository: http://${MINIKUBE_IP}:31080/twirp/"
echo "  Index: http://${MINIKUBE_IP}:31082/twirp/"
echo "  User: http://${MINIKUBE_IP}:31083/twirp/"
echo "  MinIO: http://${MINIKUBE_IP}:30901"
echo

