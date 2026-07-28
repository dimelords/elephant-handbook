#!/bin/bash

# Apply Elephant Repository Schemas
# Configures schemas using eleconf with optional TT schema support

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

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local response

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    while true; do
        read -p "$(echo -e "${CYAN}${prompt}${NC}")" response
        response=${response:-$default}
        case "$response" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HANDBOOK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ELECONF_DIR="$HANDBOOK_DIR/../eleconf"
ELECONF_CONFIG_DIR="$HANDBOOK_DIR/../eleconf-config"
CLIENT_SECRET="${CLIENT_SECRET}"

if [ -z "$CLIENT_SECRET" ]; then
    if [ -f "/tmp/elephant-client-secret.txt" ]; then
        CLIENT_SECRET=$(cat /tmp/elephant-client-secret.txt)
    else
        print_error "CLIENT_SECRET not set and /tmp/elephant-client-secret.txt not found"
        exit 1
    fi
fi

check_tt_schema() {
    if grep -q 'schema_set "tt"' "$ELECONF_CONFIG_DIR/schemas.hcl"; then
        return 0
    else
        return 1
    fi
}

disable_tt_schema() {
    print_info "Commenting out TT schema..."

    # Comment out the tt schema_set block
    sed -i.bak '/^# TT-specific schemas/,/^}$/s/^/# /' "$ELECONF_CONFIG_DIR/schemas.hcl"

    print_info "✓ TT schema disabled"
}

enable_tt_schema() {
    print_info "Enabling TT schema..."

    # Uncomment the tt schema_set block if it's commented
    sed -i.bak '/^# # TT-specific schemas/,/^# }$/s/^# //' "$ELECONF_CONFIG_DIR/schemas.hcl"

    print_info "✓ TT schema enabled"
}

build_eleconf() {
    print_step "Building eleconf"

    if [ ! -d "$ELECONF_DIR" ]; then
        print_error "eleconf directory not found at $ELECONF_DIR"
        exit 1
    fi

    cd "$ELECONF_DIR"

    if [ -f "./eleconf" ]; then
        print_info "eleconf binary already exists"
    else
        print_info "Building eleconf..."
        go build -o eleconf ./cmd/eleconf
        print_info "✓ eleconf built successfully"
    fi
}

apply_schemas() {
    print_step "Applying Repository Schemas"

    cd "$ELECONF_CONFIG_DIR"

    # eleconf resolves endpoints from a per-environment config.json under the
    # OS user config dir (~/.config or ~/Library/Application Support, depending
    # on XDG_CONFIG_HOME), not from any .env file in this directory. Without
    # this it fails with "no repository endpoint configured for environment".
    print_info "Registering 'local' environment endpoints with eleconf..."
    "$ELECONF_DIR/eleconf" configure --env=local \
        --endpoint=repository=http://localhost:1080 \
        --oidc=https://localhost:8443/realms/elephant

    print_info "Running eleconf update to fetch latest schema versions..."
    ENV=local \
    CLIENT_ID=elephant \
    CLIENT_SECRET="$CLIENT_SECRET" \
    "$ELECONF_DIR/eleconf" update

    print_info "Applying schemas to repository..."
    yes | ENV=local \
    CLIENT_ID=elephant \
    CLIENT_SECRET="$CLIENT_SECRET" \
    "$ELECONF_DIR/eleconf" apply 2>&1 | grep -v "^y$" || true

    print_info "✓ Schemas applied successfully"
}

main() {
    print_step "Schema Configuration"

    echo "The Elephant system requires repository schemas to be configured."
    echo "This includes document types, validation rules, and metadata definitions."
    echo

    # Ask about TT schema
    if check_tt_schema; then
        echo "The TT schema is currently ${GREEN}enabled${NC}."
        echo "This schema includes the 'tt/keycloak' account type needed by elephant-chrome."
        echo

        if ! ask_yes_no "Do you want to use the TT schema (recommended for elephant-chrome)?" "y"; then
            disable_tt_schema
        fi
    else
        echo "The TT schema is currently ${YELLOW}disabled${NC}."
        echo
        echo "${CYAN}About TT Schema:${NC}"
        echo "  • Defines 'tt/keycloak' account type for Keycloak authentication"
        echo "  • Required by elephant-chrome frontend"
        echo "  • Includes TT-specific document types and workflows"
        echo

        if ask_yes_no "Do you want to enable the TT schema?" "y"; then
            enable_tt_schema
        fi
    fi

    echo
    build_eleconf
    apply_schemas

    echo
    print_info "✅ Schema configuration complete!"
    echo

    # Show what was applied
    print_info "Active schemas:"
    TOKEN=$(curl -k -s -X POST 'https://localhost:8443/realms/elephant/protocol/openid-connect/token' \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -d 'client_id=elephant' \
        -d "client_secret=${CLIENT_SECRET}" \
        -d 'grant_type=client_credentials' | jq -r '.access_token')

    curl -s -X POST http://localhost:1080/twirp/elephant.repository.Schemas/GetAllActive \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d '{}' | jq -r '.schemas[] | "  • \(.name) v\(.version)"'

    echo
}

main "$@"
