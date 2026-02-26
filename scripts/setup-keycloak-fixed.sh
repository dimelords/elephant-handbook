#!/bin/bash

# Elephant - Keycloak Setup Script (FIXED VERSION)
# Configures Keycloak realm, client, and test users
# This version uses kcadm.sh to avoid HTTPS requirement issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM_NAME="elephant"
CLIENT_ID="elephant"
CONTAINER_NAME="${KEYCLOAK_CONTAINER:-elephant-keycloak}"

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

# Wait for Keycloak to be ready
wait_for_keycloak() {
    print_step "Waiting for Keycloak to be ready"

    for i in {1..60}; do
        if curl -sf "$KEYCLOAK_URL/health/ready" >/dev/null 2>&1; then
            print_info "Keycloak is ready!"
            return 0
        fi
        echo -n "."
        sleep 2
    done

    print_error "Keycloak did not become ready in time"
    exit 1
}

# Configure kcadm.sh credentials
configure_kcadm() {
    print_step "Configuring Keycloak Admin CLI"

    docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 \
        --realm master \
        --user $KEYCLOAK_ADMIN \
        --password $KEYCLOAK_ADMIN_PASSWORD

    print_info "Admin CLI configured"
}

# Create realm
create_realm() {
    print_step "Creating Elephant realm"

    # Check if realm exists
    REALM_EXISTS=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get realms/$REALM_NAME 2>/dev/null || echo "")

    if [ -n "$REALM_EXISTS" ]; then
        print_warn "Realm '$REALM_NAME' already exists, updating SSL settings"
        docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh update realms/$REALM_NAME \
            -s sslRequired=NONE
    else
        docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh create realms \
            -s realm=$REALM_NAME \
            -s enabled=true \
            -s sslRequired=NONE \
            -s displayName="Elephant Editorial System" \
            -s accessTokenLifespan=300 \
            -s ssoSessionIdleTimeout=1800 \
            -s ssoSessionMaxLifespan=36000 \
            -s offlineSessionIdleTimeout=2592000

        print_info "Realm created successfully"
    fi
}

# Create client
create_client() {
    print_step "Creating Elephant client"

    # Check if client exists
    CLIENT_EXISTS=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get clients -r $REALM_NAME \
        --fields clientId | jq -r '.[] | select(.clientId=="'$CLIENT_ID'") | .clientId' 2>/dev/null || echo "")

    if [ -n "$CLIENT_EXISTS" ]; then
        print_warn "Client '$CLIENT_ID' already exists"
    else
        docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh create clients -r $REALM_NAME \
            -s clientId=$CLIENT_ID \
            -s name="Elephant Client" \
            -s description="Elephant Editorial System" \
            -s enabled=true \
            -s protocol=openid-connect \
            -s publicClient=false \
            -s standardFlowEnabled=true \
            -s directAccessGrantsEnabled=true \
            -s serviceAccountsEnabled=true \
            -s 'redirectUris=["http://localhost:5173/*","http://localhost:3000/*","http://localhost:1080/*"]' \
            -s 'webOrigins=["http://localhost:5173","http://localhost:3000","http://localhost:1080"]' \
            -s 'attributes={"access.token.lifespan":"300"}'

        print_info "Client created successfully"
    fi

    # Get client UUID
    CLIENT_UUID=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get clients -r $REALM_NAME \
        --fields id,clientId | jq -r '.[] | select(.clientId=="'$CLIENT_ID'") | .id')

    print_info "Client UUID: $CLIENT_UUID"
}

# Create client scopes
create_client_scopes() {
    print_step "Creating custom client scopes"

    # Create permission scopes as optional scopes
    for scope in schema_read doc_read_all eventlog_read; do
        docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh create client-scopes -r $REALM_NAME \
            -s name=$scope \
            -s protocol=openid-connect \
            -s 'attributes={"include.in.token.scope":"true"}' 2>/dev/null || print_warn "Scope $scope may already exist"
    done

    # Get scope IDs
    SCHEMA_READ_ID=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get client-scopes -r $REALM_NAME \
        | jq -r '.[] | select(.name=="schema_read") | .id')
    DOC_READ_ID=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get client-scopes -r $REALM_NAME \
        | jq -r '.[] | select(.name=="doc_read_all") | .id')
    EVENTLOG_READ_ID=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get client-scopes -r $REALM_NAME \
        | jq -r '.[] | select(.name=="eventlog_read") | .id')

    # Add as optional scopes (not default)
    docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh update \
        clients/$CLIENT_UUID/optional-client-scopes/$SCHEMA_READ_ID -r $REALM_NAME 2>/dev/null || true
    docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh update \
        clients/$CLIENT_UUID/optional-client-scopes/$DOC_READ_ID -r $REALM_NAME 2>/dev/null || true
    docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh update \
        clients/$CLIENT_UUID/optional-client-scopes/$EVENTLOG_READ_ID -r $REALM_NAME 2>/dev/null || true

    print_info "Client scopes configured as optional scopes"
}

# Remove conflicting mappers
remove_conflicting_mappers() {
    print_step "Removing conflicting protocol mappers"

    # Remove client-roles-to-scope mapper if it exists
    MAPPER_ID=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get \
        clients/$CLIENT_UUID/protocol-mappers/models -r $REALM_NAME 2>/dev/null \
        | jq -r '.[] | select(.name=="client-roles-to-scope") | .id' || echo "")

    if [ -n "$MAPPER_ID" ]; then
        docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh delete \
            clients/$CLIENT_UUID/protocol-mappers/models/$MAPPER_ID -r $REALM_NAME
        print_info "Removed client-roles-to-scope mapper"
    else
        print_info "No conflicting mappers found"
    fi
}

# Add audience mapper
add_audience_mapper() {
    print_step "Adding audience mapper"

    # Check if mapper already exists
    MAPPER_EXISTS=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get \
        clients/$CLIENT_UUID/protocol-mappers/models -r $REALM_NAME 2>/dev/null \
        | jq -r '.[] | select(.name=="audience-mapper") | .name' || echo "")

    if [ -n "$MAPPER_EXISTS" ]; then
        print_warn "Audience mapper already exists"
    else
        docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh create \
            clients/$CLIENT_UUID/protocol-mappers/models -r $REALM_NAME \
            -s name=audience-mapper \
            -s protocol=openid-connect \
            -s protocolMapper=oidc-audience-mapper \
            -s 'config."included.client.audience"='$CLIENT_ID \
            -s 'config."access.token.claim"=true'

        print_info "Audience mapper added"
    fi
}

# Get client secret
get_client_secret() {
    print_step "Getting client secret"

    CLIENT_SECRET=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get \
        clients/$CLIENT_UUID/client-secret -r $REALM_NAME | jq -r '.value')

    print_info "Client secret: $CLIENT_SECRET"

    # Save to file
    echo "$CLIENT_SECRET" > /tmp/elephant-client-secret.txt
    print_info "Client secret saved to: /tmp/elephant-client-secret.txt"
}

# Create elephant-permissions scope with mappers
create_elephant_permissions() {
    print_step "Creating elephant-permissions scope"

    # Check if scope exists
    SCOPE_EXISTS=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get client-scopes -r $REALM_NAME \
        | jq -r '.[] | select(.name=="elephant-permissions") | .name' || echo "")

    if [ -z "$SCOPE_EXISTS" ]; then
        docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh create client-scopes -r $REALM_NAME \
            -s name=elephant-permissions \
            -s description="Elephant document permissions" \
            -s protocol=openid-connect \
            -s 'attributes={"include.in.token.scope":"true","display.on.consent.screen":"true"}'
    fi

    # Get scope UUID
    SCOPE_UUID=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get client-scopes -r $REALM_NAME \
        | jq -r '.[] | select(.name=="elephant-permissions") | .id')

    # Add units mapper
    docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh create \
        client-scopes/$SCOPE_UUID/protocol-mappers/models -r $REALM_NAME \
        -s name=units \
        -s protocol=openid-connect \
        -s protocolMapper=oidc-usermodel-attribute-mapper \
        -s 'config."user.attribute"=units' \
        -s 'config."claim.name"=units' \
        -s 'config."jsonType.label"=String' \
        -s 'config."id.token.claim"=true' \
        -s 'config."access.token.claim"=true' \
        -s 'config."userinfo.token.claim"=true' \
        -s 'config.multivalued=true' 2>/dev/null || print_warn "Units mapper may already exist"

    # Assign scope to client as default
    docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh update \
        clients/$CLIENT_UUID/default-client-scopes/$SCOPE_UUID -r $REALM_NAME 2>/dev/null || true

    print_info "Elephant-permissions scope configured"
}

# Create test users
create_users() {
    print_step "Creating test users"

    # Editor user
    docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh create users -r $REALM_NAME \
        -s username=editor \
        -s email=editor@dimelords.local \
        -s emailVerified=true \
        -s firstName=Test \
        -s lastName=Editor \
        -s enabled=true \
        -s 'attributes.units=["unit://dimelords/newsroom","unit://dimelords/sports"]' \
        -s 'attributes.doc_scopes=["doc_read","doc_write"]' 2>/dev/null || print_warn "User 'editor' may already exist"

    # Set password
    EDITOR_ID=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get users -r $REALM_NAME \
        -q username=editor | jq -r '.[0].id')
    if [ -n "$EDITOR_ID" ]; then
        docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh set-password -r $REALM_NAME \
            --userid $EDITOR_ID --new-password editor 2>/dev/null || true
    fi

    # Admin user
    docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh create users -r $REALM_NAME \
        -s username=admin \
        -s email=admin@dimelords.local \
        -s emailVerified=true \
        -s firstName=Test \
        -s lastName=Admin \
        -s enabled=true \
        -s 'attributes.units=["unit://dimelords/newsroom","unit://dimelords/sports","unit://dimelords/management"]' \
        -s 'attributes.doc_scopes=["doc_read","doc_write","doc_delete","doc_admin"]' 2>/dev/null || print_warn "User 'admin' may already exist"

    # Set password
    ADMIN_ID=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get users -r $REALM_NAME \
        -q username=admin | jq -r '.[0].id')
    if [ -n "$ADMIN_ID" ]; then
        docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh set-password -r $REALM_NAME \
            --userid $ADMIN_ID --new-password admin 2>/dev/null || true
    fi

    # Reader user
    docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh create users -r $REALM_NAME \
        -s username=reader \
        -s email=reader@dimelords.local \
        -s emailVerified=true \
        -s firstName=Test \
        -s lastName=Reader \
        -s enabled=true \
        -s 'attributes.units=["unit://dimelords/newsroom"]' \
        -s 'attributes.doc_scopes=["doc_read"]' 2>/dev/null || print_warn "User 'reader' may already exist"

    # Set password
    READER_ID=$(docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh get users -r $REALM_NAME \
        -q username=reader | jq -r '.[0].id')
    if [ -n "$READER_ID" ]; then
        docker exec $CONTAINER_NAME /opt/keycloak/bin/kcadm.sh set-password -r $REALM_NAME \
            --userid $READER_ID --new-password reader 2>/dev/null || true
    fi

    print_info "Test users created successfully"
}

# Main setup
main() {
    echo "========================================"
    echo "  Elephant Keycloak Setup (FIXED)"
    echo "========================================"
    echo

    wait_for_keycloak
    configure_kcadm
    create_realm
    create_client
    create_client_scopes
    remove_conflicting_mappers
    add_audience_mapper
    create_elephant_permissions
    get_client_secret
    create_users

    # Summary
    print_step "Setup Complete!"

    cat << EOF

Keycloak Configuration Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Admin Console:  $KEYCLOAK_URL/admin
Realm:          $REALM_NAME
Client ID:      $CLIENT_ID
Client Secret:  $CLIENT_SECRET

Test Users Created:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Editor (read/write access)
   Username: editor
   Password: editor

2. Admin (full access)
   Username: admin
   Password: admin

3. Reader (read-only)
   Username: reader
   Password: reader

Get Access Token (Client Credentials):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

curl -X POST "$KEYCLOAK_URL/realms/$REALM_NAME/protocol/openid-connect/token" \\
  -d "grant_type=client_credentials" \\
  -d "client_id=$CLIENT_ID" \\
  -d "client_secret=$CLIENT_SECRET" \\
  -d "scope=schema_read doc_read_all eventlog_read"

Get Access Token (Password Grant):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

curl -X POST "$KEYCLOAK_URL/realms/$REALM_NAME/protocol/openid-connect/token" \\
  -d "grant_type=password" \\
  -d "client_id=$CLIENT_ID" \\
  -d "client_secret=$CLIENT_SECRET" \\
  -d "username=editor" \\
  -d "password=editor"

Test API Call:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Get token
export TOKEN=\$(curl -sf -X POST "$KEYCLOAK_URL/realms/$REALM_NAME/protocol/openid-connect/token" \\
  -d "grant_type=client_credentials" \\
  -d "client_id=$CLIENT_ID" \\
  -d "client_secret=$CLIENT_SECRET" \\
  -d "scope=schema_read doc_read_all eventlog_read" | jq -r '.access_token')

# Call Elephant API
curl -X GET http://localhost:1080/healthz \\
  -H "Authorization: Bearer \$TOKEN"

EOF
}

# Run main
main
