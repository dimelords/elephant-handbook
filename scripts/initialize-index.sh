#!/bin/bash

# Initialize Elephant Index Service
# Registers OpenSearch cluster, creates index set, and activates it

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo
    echo -e "${BLUE}━━━━ $1 ━━━━${NC}"
    echo
}

# Configuration
INDEX_URL="${INDEX_URL:-http://localhost:1082}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
CLIENT_ID="${CLIENT_ID:-elephant}"
CLIENT_SECRET="${CLIENT_SECRET}"
OPENSEARCH_ENDPOINT="${OPENSEARCH_ENDPOINT:-http://opensearch:9200}"

if [ -z "$CLIENT_SECRET" ]; then
    if [ -f "/tmp/elephant-client-secret.txt" ]; then
        CLIENT_SECRET=$(cat /tmp/elephant-client-secret.txt)
    else
        print_error "CLIENT_SECRET not set and /tmp/elephant-client-secret.txt not found"
        exit 1
    fi
fi

get_access_token() {
    TOKEN=$(curl -k -s -X POST "${KEYCLOAK_URL}/realms/elephant/protocol/openid-connect/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -d "client_id=${CLIENT_ID}" \
        -d "client_secret=${CLIENT_SECRET}" \
        -d 'grant_type=client_credentials' | jq -r '.access_token')

    if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        print_error "Failed to get access token from Keycloak"
        return 1
    fi

    echo "$TOKEN"
}

register_opensearch_cluster() {
    print_step "Registering OpenSearch Cluster"

    local TOKEN=$(get_access_token)

    # Check if cluster already exists
    local EXISTING=$(curl -s -X POST "${INDEX_URL}/twirp/elephant.index.Management/ListClusters" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d '{}' | jq -r '.clusters[] | select(.name=="default") | .name')

    if [ "$EXISTING" = "default" ]; then
        print_info "✓ OpenSearch cluster 'default' already registered"
        return 0
    fi

    # Register cluster
    local RESULT=$(curl -s -X POST "${INDEX_URL}/twirp/elephant.index.Management/RegisterCluster" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{
            \"name\": \"default\",
            \"endpoint\": \"${OPENSEARCH_ENDPOINT}\",
            \"auth\": {}
        }")

    if echo "$RESULT" | jq -e '.code' >/dev/null 2>&1; then
        print_error "Failed to register cluster: $(echo "$RESULT" | jq -r '.msg')"
        return 1
    fi

    print_info "✓ Registered OpenSearch cluster 'default'"
}

create_and_activate_index() {
    print_step "Creating and Activating Index Set"

    local TOKEN=$(get_access_token)

    # Check if an active index set already exists
    local ACTIVE_INDEX=$(curl -s -X POST "${INDEX_URL}/twirp/elephant.index.Management/ListIndexSets" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d '{}' | jq -r '.index_sets[] | select(.active==true) | .name')

    if [ -n "$ACTIVE_INDEX" ]; then
        print_info "✓ Active index set already exists: $ACTIVE_INDEX"
        return 0
    fi

    # Create new index set
    print_info "Creating new index set..."
    local INDEX_NAME=$(curl -s -X POST "${INDEX_URL}/twirp/elephant.index.Management/Reindex" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d '{"cluster":"default"}' | jq -r '.name')

    if [ -z "$INDEX_NAME" ] || [ "$INDEX_NAME" = "null" ]; then
        print_error "Failed to create index set"
        return 1
    fi

    print_info "✓ Created index set: $INDEX_NAME"

    # Wait a moment for indexing to start
    print_info "Waiting for initial indexing..."
    sleep 3

    # Activate the index set
    print_info "Activating index set..."
    local ACTIVATE_RESULT=$(curl -s -X POST "${INDEX_URL}/twirp/elephant.index.Management/SetIndexSetStatus" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{
            \"name\": \"${INDEX_NAME}\",
            \"active\": true
        }")

    if echo "$ACTIVATE_RESULT" | jq -e '.code' >/dev/null 2>&1; then
        local ERROR_CODE=$(echo "$ACTIVATE_RESULT" | jq -r '.code')
        if [ "$ERROR_CODE" = "failed_precondition" ]; then
            print_info "Index set needs more time to catch up, activating anyway..."
            curl -s -X POST "${INDEX_URL}/twirp/elephant.index.Management/SetIndexSetStatus" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $TOKEN" \
                -d "{
                    \"name\": \"${INDEX_NAME}\",
                    \"active\": true,
                    \"force_active\": true
                }" >/dev/null
        fi
    fi

    print_info "✓ Activated index set: $INDEX_NAME"

    # Show status
    print_info "Index status:"
    curl -s -X POST "${INDEX_URL}/twirp/elephant.index.Management/ListIndexSets" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d '{}' | jq -r '.index_sets[] | "  • \(.name) (cluster: \(.cluster), position: \(.position), active: \(.active))"'
}

main() {
    print_step "Initializing Elephant Index Service"

    register_opensearch_cluster
    create_and_activate_index

    echo
    print_info "✅ Index service initialization complete!"
    echo
}

main "$@"
