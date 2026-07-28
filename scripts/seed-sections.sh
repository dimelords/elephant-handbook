#!/bin/bash

# Seed core/section Taxonomy Documents
#
# core/section is a bounded_collection taxonomy type (see eleconf-config/taxonomy.hcl) -
# there's no admin UI for creating them and none exist by default in a fresh local repo.
# Without at least one, Planning/Article/QuickArticle creation is blocked: upstream made
# Section a mandatory field on create, and the section picker has nothing to search.
#
# Safe to re-run - fetches the current version (if any) and passes it as if_match, so it
# updates existing sections (e.g. to fix ACL) instead of failing on "already exists".
#
# ACL is granted to READER_UNIT (default: unit://dimelords/newsroom, shared by all local
# test users - see elephant-handbook/scripts/setup-keycloak.sh) so sections are actually
# visible to real users' search queries. Without an explicit ACL the repository grants
# read access only to the calling service account, which no real user can match.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

REPOSITORY_URL="${REPOSITORY_URL:-http://localhost:1080}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://localhost:8443}"
CLIENT_ID="${CLIENT_ID:-elephant}"
READER_UNIT="${READER_UNIT:-unit://dimelords/newsroom}"

print_step "Seeding core/section Documents"

if [ -z "$CLIENT_SECRET" ]; then
    print_error "CLIENT_SECRET not set"
    print_warn "Usage: CLIENT_SECRET=\"\$(cat /tmp/elephant-client-secret.txt)\" ./seed-sections.sh"
    exit 1
fi

print_info "Fetching access token..."
TOKEN=$(curl -sk -X POST "$KEYCLOAK_URL/realms/elephant/protocol/openid-connect/token" \
    -d grant_type=client_credentials \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
    print_error "Failed to get access token"
    exit 1
fi

create_section() {
    local slug="$1"
    local title="$2"
    local uuid
    uuid=$(python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_URL, 'core://section/$slug'))")

    # Look up the current version so this can update (not just create) - GetMeta
    # 404s with a JSON error body if the document doesn't exist yet, in which case
    # we fall back to -1 (create-only).
    local if_match
    if_match=$(curl -sk -X POST "$REPOSITORY_URL/twirp/elephant.repository.Documents/GetMeta" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
        -d "{\"uuid\":\"$uuid\"}" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('meta', {}).get('current_version', '-1'))
" 2>/dev/null || echo "-1")

    local body
    body=$(python3 -c "
import json, sys
print(json.dumps({
    'uuid': '$uuid',
    'document': {
        'uuid': '$uuid',
        'type': 'core/section',
        'uri': 'core://section/$slug',
        'title': '$title',
        'language': 'sv',
        'meta': [{
            'type': 'core/section',
            'data': {'code': '$slug'}
        }]
    },
    'ifMatch': '$if_match',
    'status': [{'name': 'usable'}],
    'acl': [{'uri': '$READER_UNIT', 'permissions': ['r']}]
}))
")

    local response
    response=$(curl -sk -o /dev/null -w "%{http_code}" -X POST \
        "$REPOSITORY_URL/twirp/elephant.repository.Documents/Update" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$body")

    if [ "$response" = "200" ]; then
        print_info "✓ Wrote section '$title' ($slug)"
    elif [ "$response" = "412" ]; then
        print_warn "Section '$title' ($slug) changed concurrently, skipping"
    else
        print_error "Failed to write '$title' ($slug): HTTP $response"
    fi
}

create_section "news" "Nyheter"
create_section "sport" "Sport"
create_section "culture" "Kultur"
create_section "economy" "Ekonomi"

print_info "Done. Sections should now be selectable when creating Plannings/Articles."
