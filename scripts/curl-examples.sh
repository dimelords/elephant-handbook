#!/bin/bash
# Elephant API - curl Examples
# Quick reference for testing APIs from command line

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Elephant Local API - curl Examples ===${NC}\n"

# Get token first with all required scopes
echo -e "${YELLOW}1. Getting access token...${NC}"
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8180/realms/elephant/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=elephant" \
  -d "client_secret=elephant-secret" \
  -d "username=dev" \
  -d "password=dev" \
  -d "scope=openid profile email search doc_read doc_read_all doc_write doc_delete eventlog_read metrics_read user baboon media content-api asset_upload")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo -e "${YELLOW}Failed to get token. Is Keycloak running?${NC}"
  exit 1
fi

echo "$ACCESS_TOKEN"
echo -e "${GREEN}✓ Token obtained${NC}"
echo ""

# Decode token to show claims
echo -e "${YELLOW}2. Token claims:${NC}"
# Extract payload (second part of JWT)
PAYLOAD_B64=$(echo "$ACCESS_TOKEN" | cut -d'.' -f2)
# Convert base64url to base64 and add padding
PAYLOAD_B64=$(echo "$PAYLOAD_B64" | tr '_-' '/+')
# Add padding if needed
case $((${#PAYLOAD_B64} % 4)) in
  2) PAYLOAD_B64="${PAYLOAD_B64}==" ;;
  3) PAYLOAD_B64="${PAYLOAD_B64}=" ;;
esac
# Decode and parse
PAYLOAD=$(echo "$PAYLOAD_B64" | base64 -d 2>/dev/null)
echo "$PAYLOAD" | jq '{sub, email, given_name, family_name, units}'
echo ""

# Search documents via Index service (not Repository)
echo -e "${YELLOW}3. Searching for articles via Index...${NC}"
DOCS_RESPONSE=$(curl -s -X POST http://localhost:1280/twirp/elephant.index.SearchV1/Query \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "documentType": "core/article",
    "size": 5,
    "from": 0,
    "language": "sv-se",
    "query": {
      "match_all": {}
    },
    "loadDocument": true,
    "shared": false
  }')

if echo "$DOCS_RESPONSE" | jq -e '.hits.hits' > /dev/null 2>&1; then
  DOC_COUNT=$(echo "$DOCS_RESPONSE" | jq '.hits.hits | length')
  if [ "$DOC_COUNT" -gt 0 ]; then
    echo "$DOCS_RESPONSE" | jq '.hits.hits[] | {uuid: .document.uuid, title: .document.title, type: .document.type}'
  else
    echo "No articles found (empty index)"
  fi
else
  echo "Response: $DOCS_RESPONSE"
fi
echo ""

# Get eventlog
echo -e "${YELLOW}4. Recent eventlog entries...${NC}"
EVENTLOG_RESPONSE=$(curl -s -X POST http://localhost:1080/twirp/elephant.repository.Documents/Eventlog \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "after": "0",
    "limit": "5"
  }')

if echo "$EVENTLOG_RESPONSE" | jq -e '.entries' > /dev/null 2>&1; then
  EVENT_COUNT=$(echo "$EVENTLOG_RESPONSE" | jq '.entries | length')
  if [ "$EVENT_COUNT" -gt 0 ]; then
    echo "$EVENTLOG_RESPONSE" | jq '.entries[] | {id, type, uuid}'
  else
    echo "No eventlog entries found"
  fi
else
  echo "Response: $EVENTLOG_RESPONSE"
fi
echo ""

# Search authors
echo -e "${YELLOW}5. Searching for authors...${NC}"
AUTHORS_RESPONSE=$(curl -s -X POST http://localhost:1280/twirp/elephant.index.SearchV1/Query \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "documentType": "core/author",
    "size": 10,
    "from": 0,
    "language": "sv-se",
    "query": {
      "match_all": {}
    },
    "loadDocument": true,
    "shared": false
  }')

if echo "$AUTHORS_RESPONSE" | jq -e '.hits.hits' > /dev/null 2>&1; then
  AUTHOR_COUNT=$(echo "$AUTHORS_RESPONSE" | jq '.hits.hits | length')
  if [ "$AUTHOR_COUNT" -gt 0 ]; then
    echo "$AUTHORS_RESPONSE" | jq '.hits.hits[] | {
      title: .document.title,
      email: (.document.meta[1].data.email // "no email"),
      created: (.document.meta[0].created // "unknown")
    }'
  else
    echo "No authors found"
  fi
else
  echo "Response: $AUTHORS_RESPONSE"
fi
echo ""

# OpenSearch - List indices
echo -e "${YELLOW}6. OpenSearch indices...${NC}"
curl -s -u admin:Admin123! http://localhost:9200/_cat/indices?v | head -5
echo ""

echo -e "${GREEN}=== More Examples ===${NC}\n"

echo "Create a document:"
echo "curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Update \\"
echo "  -H \"Authorization: Bearer \$ACCESS_TOKEN\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{"
echo "    \"uuid\": \"\","
echo "    \"document\": {"
echo "      \"type\": \"core/article\","
echo "      \"title\": \"Test Article from curl\","
echo "      \"language\": \"sv-se\","
echo "      \"content\": [],"
echo "      \"meta\": [],"
echo "      \"links\": []"
echo "    },"
echo "    \"status\": [{\"name\": \"draft\"}]"
echo "  }' | jq"
echo ""

echo "Get specific document:"
echo "curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Get \\"
echo "  -H \"Authorization: Bearer \$ACCESS_TOKEN\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"uuid\": \"YOUR-UUID\", \"version\": 0}' | jq"
echo ""

echo "OpenSearch full-text search:"
echo "curl -u admin:Admin123! -X POST http://localhost:9200/_search \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"query\": {"
echo "      \"match\": {"
echo "        \"document.title\": \"your search term\""
echo "      }"
echo "    }"
echo "  }' | jq"
echo ""

echo -e "${GREEN}Done!${NC}"
