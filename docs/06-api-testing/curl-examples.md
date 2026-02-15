# cURL API Testing Examples

Command-line examples for testing Elephant APIs. These examples assume you're running services locally with Docker Compose or Kubernetes.

## Prerequisites

```bash
# Install jq for JSON formatting
brew install jq  # macOS
# or
apt-get install jq  # Linux
```

## Quick Start Script

The handbook includes a comprehensive script with all examples:

```bash
cd elephant-handbook/scripts
./curl-examples.sh
```

This script will:
1. Authenticate and get a token
2. Show token claims
3. Search for documents
4. Query the eventlog
5. Check OpenSearch indices

## Authentication

### Get Access Token (Keycloak)

```bash
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8180/realms/elephant/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=elephant" \
  -d "client_secret=elephant-secret" \
  -d "username=dev" \
  -d "password=dev" \
  -d "scope=openid profile email doc_read doc_write doc_delete eventlog_read")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
echo "Token: $ACCESS_TOKEN"
```

### Get Access Token (Mock)

For development with mock authentication:

```bash
TOKEN_RESPONSE=$(curl -s http://localhost:1080/token \
  -d grant_type=password \
  -d 'username=Dev User <user://dev/user1, unit://dev/unit1>' \
  -d 'scope=doc_read doc_write doc_delete')

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
```

### Decode JWT Token

```bash
# Extract payload (second part of JWT)
PAYLOAD_B64=$(echo "$ACCESS_TOKEN" | cut -d'.' -f2)
# Add padding and decode
echo "$PAYLOAD_B64" | base64 -d 2>/dev/null | jq
```

## Documents API (elephant-repository)

### Create Document

```bash
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Update \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "uuid": "",
    "document": {
      "type": "core/article",
      "title": "Test Article from cURL",
      "language": "sv-se",
      "content": [
        {
          "type": "core/text",
          "role": "body",
          "data": {
            "text": "This is a test article created via cURL."
          }
        }
      ],
      "meta": [
        {
          "type": "core/description",
          "data": {
            "text": "A simple test article"
          }
        }
      ],
      "links": []
    },
    "status": [{"name": "draft"}]
  }' | jq
```

### Get Document

```bash
# Replace YOUR-UUID with actual UUID
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Get \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"uuid": "YOUR-UUID", "version": 0}' | jq
```

### Update Document

```bash
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Update \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "uuid": "YOUR-UUID",
    "document": {
      "type": "core/article",
      "title": "Updated Title",
      "language": "sv-se",
      "content": [],
      "meta": [],
      "links": []
    }
  }' | jq
```

### Delete Document

```bash
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Delete \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"uuid": "YOUR-UUID"}' | jq
```

### Get Document History

```bash
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/GetHistory \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"uuid": "YOUR-UUID"}' | jq
```

## Search API (elephant-index)

### Search Articles

```bash
curl -X POST http://localhost:1280/twirp/elephant.index.SearchV1/Query \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "documentType": "core/article",
    "size": 10,
    "from": 0,
    "language": "sv-se",
    "query": {
      "match_all": {}
    },
    "loadDocument": true,
    "shared": false
  }' | jq
```

### Full-Text Search

```bash
curl -X POST http://localhost:1280/twirp/elephant.index.SearchV1/Query \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "documentType": "core/article",
    "size": 10,
    "language": "sv-se",
    "query": {
      "multi_match": {
        "query": "your search term",
        "fields": ["document.title^2", "document.content.*.data.text"]
      }
    },
    "loadDocument": true
  }' | jq
```

### Search by Date Range

```bash
curl -X POST http://localhost:1280/twirp/elephant.index.SearchV1/Query \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "documentType": "core/article",
    "query": {
      "range": {
        "document.meta.0.created": {
          "gte": "2024-01-01",
          "lte": "2024-12-31"
        }
      }
    }
  }' | jq
```

## Eventlog API

### Get Recent Events

```bash
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Eventlog \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "after": "0",
    "limit": "10"
  }' | jq
```

### Stream Events (Follow Mode)

```bash
# Start from event 0 and keep polling
LAST_ID=0
while true; do
  RESPONSE=$(curl -s -X POST http://localhost:1080/twirp/elephant.repository.Documents/Eventlog \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"after\": \"$LAST_ID\", \"limit\": \"10\"}")

  # Extract events
  echo "$RESPONSE" | jq '.entries[]'

  # Update last ID
  NEW_LAST=$(echo "$RESPONSE" | jq -r '.entries[-1].id // empty')
  if [ -n "$NEW_LAST" ]; then
    LAST_ID=$NEW_LAST
  fi

  sleep 2
done
```

## Status API

### Get Document Status

```bash
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/GetStatus \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"uuid": "YOUR-UUID"}' | jq
```

### Update Status

```bash
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/UpdateStatus \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "uuid": "YOUR-UUID",
    "status": [
      {"name": "usable"},
      {"name": "published"}
    ]
  }' | jq
```

## Health Checks

### Repository Health

```bash
curl http://localhost:1080/healthz
```

### Index Service Health

```bash
curl http://localhost:1280/healthz
```

### OpenSearch Health

```bash
curl -u admin:Admin123! http://localhost:9200/_cluster/health | jq
```

## OpenSearch Direct Queries

### List All Indices

```bash
curl -u admin:Admin123! http://localhost:9200/_cat/indices?v
```

### Search Across All Indices

```bash
curl -u admin:Admin123! -X POST http://localhost:9200/_search \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": {
        "document.title": "your search term"
      }
    }
  }' | jq
```

### Get Index Mapping

```bash
curl -u admin:Admin123! http://localhost:9200/elephant-sv-se-core-article/_mapping | jq
```

## Complete Workflow Example

```bash
#!/bin/bash
# Complete document lifecycle example

# 1. Get token
echo "1. Getting token..."
TOKEN=$(curl -s http://localhost:1080/token \
  -d grant_type=password \
  -d 'username=Admin' \
  -d 'scope=doc_read doc_write doc_delete' | jq -r .access_token)

# 2. Create document
echo "2. Creating document..."
CREATE_RESPONSE=$(curl -s -X POST http://localhost:1080/twirp/elephant.repository.Documents/Update \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "uuid": "",
    "document": {
      "type": "core/article",
      "title": "Workflow Test Article",
      "language": "sv-se",
      "content": [],
      "meta": [],
      "links": []
    },
    "status": [{"name": "draft"}]
  }')

UUID=$(echo "$CREATE_RESPONSE" | jq -r .uuid)
echo "Created UUID: $UUID"

# 3. Update document
echo "3. Updating document..."
curl -s -X POST http://localhost:1080/twirp/elephant.repository.Documents/Update \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$UUID\",
    \"document\": {
      \"type\": \"core/article\",
      \"title\": \"Updated Workflow Test\",
      \"language\": \"sv-se\",
      \"content\": [],
      \"meta\": [],
      \"links\": []
    }
  }" | jq .version

# 4. Check history
echo "4. Getting history..."
curl -s -X POST http://localhost:1080/twirp/elephant.repository.Documents/GetHistory \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"uuid\": \"$UUID\"}" | jq '.versions | length'

# 5. Search for it
echo "5. Waiting for indexing..."
sleep 3
curl -s -X POST http://localhost:1280/twirp/elephant.index.SearchV1/Query \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "documentType": "core/article",
    "query": {
      "match": {
        "document.title": "Workflow Test"
      }
    }
  }' | jq '.hits.hits | length'

echo "Done!"
```

## Testing with Different Users

```bash
# Create tokens for different users/scopes
TOKEN_READ=$(curl -s http://localhost:1080/token \
  -d grant_type=password \
  -d 'username=Reader' \
  -d 'scope=doc_read' | jq -r .access_token)

TOKEN_WRITE=$(curl -s http://localhost:1080/token \
  -d grant_type=password \
  -d 'username=Writer' \
  -d 'scope=doc_read doc_write' | jq -r .access_token)

# Test with read-only user (should fail)
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Update \
  -H "Authorization: Bearer $TOKEN_READ" \
  -H "Content-Type: application/json" \
  -d '{"uuid": "", "document": {...}}' | jq

# Test with write user (should succeed)
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Update \
  -H "Authorization: Bearer $TOKEN_WRITE" \
  -H "Content-Type: application/json" \
  -d '{"uuid": "", "document": {...}}' | jq
```

## Troubleshooting

### Connection Refused

```bash
# Check if services are running
curl -v http://localhost:1080/healthz
curl -v http://localhost:1280/healthz

# Check if port forwarding is active (Kubernetes)
ps aux | grep port-forward
```

### Authentication Errors

```bash
# Verify token is valid
echo "$ACCESS_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq

# Check token expiration
EXPIRY=$(echo "$ACCESS_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r .exp)
CURRENT=$(date +%s)
echo "Token expires in: $(($EXPIRY - $CURRENT)) seconds"
```

### Validation Errors

```bash
# Enable verbose output to see full error
curl -v -X POST http://localhost:1080/twirp/elephant.repository.Documents/Update \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"uuid": "", "document": {...}}' 2>&1 | grep -A 20 "< HTTP"
```

## See Also

- [Postman Guide](postman.md) - GUI-based API testing
- [API Reference](../02-components/apis.md) - Complete API documentation
- [Authentication](../06-authentication/) - OIDC and JWT setup
