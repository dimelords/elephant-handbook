# Postman Collection Guide

Quick guide for testing Elephant APIs using Postman.

## Quick Setup

### 1. Import Collection and Environment

1. **Import the Collection**:
   - Open Postman
   - Click **Import** in the top-left
   - Select `Elephant-Local.postman_collection.json` from elephant-local root
   - Click **Import**

2. **Import the Environment**:
   - Click **Import** again
   - Select `Elephant-Local.postman_environment.json` from elephant-local root
   - Click **Import**

3. **Select the Environment**:
   - In the top-right dropdown, select **"Elephant Local"**

### 2. Test Authentication

1. Open the **Authentication** folder
2. Run **"Get Access Token"**
3. Check the **Console** - you should see "Token expires in: 300 seconds"
4. The token is now automatically stored in the environment variable `{{access_token}}`

## How It Works

### Automatic Token Management

The collection has **automatic token refresh** built-in:

- **Pre-request Script**: Runs before every request
- **Checks token expiry**: If expired or missing, fetches a new token
- **Uses environment variables**: Stores token, refresh token, and expiry time
- **Bearer auth**: All authenticated requests use `{{access_token}}`

You don't need to manually copy/paste tokens between requests!

### Manual Token Refresh

If you want to manually refresh the token:
1. Go to **Authentication → Get Access Token**
2. Click **Send**
3. The new token is automatically saved

## Available Requests

### Documents

- **Create Document** - Creates a new document
- **Get Document** - Retrieves document by UUID
- **Update Document** - Updates existing document
- **Delete Document** - Soft-deletes a document
- **Get Document History** - Lists all versions

### Search (elephant-index)

- **Search Articles** - Full-text search for articles
- **Search Authors** - Search for author documents
- **Advanced Search** - Complex queries with filters

### Eventlog

- **Get Recent Events** - Latest eventlog entries
- **Get Events After** - Events after specific ID

### Status Management

- **Get Status** - Current workflow status
- **Update Status** - Change document status

### Meta Operations

- **Get Meta** - Retrieve document metadata
- **Update Meta** - Update metadata fields

## Environment Variables

The Postman environment includes:

- `base_url` - Repository API endpoint (default: http://localhost:1080)
- `index_url` - Index service endpoint (default: http://localhost:1280)
- `user_url` - User service endpoint (default: http://localhost:1282)
- `access_token` - Automatically managed JWT token
- `refresh_token` - Refresh token for renewals
- `token_expiry` - Token expiration timestamp

## Tips

### Test Against Different Environments

1. Duplicate the environment
2. Change the URLs to point to staging/production
3. Update authentication settings

### Debug API Calls

- Open **Console** (bottom-left in Postman)
- See full request/response including headers
- Check pre-request script output

### Save Response Data

Use Tests tab to extract data:

```javascript
// Extract document UUID from response
const response = pm.response.json();
pm.environment.set("last_uuid", response.uuid);
```

### Chain Requests

1. Create a document
2. Use `{{last_uuid}}` in subsequent requests
3. Automate workflows

## Common Workflows

### Create and Publish Article

1. **Create Document** → Save UUID
2. **Update Meta** → Add title, description
3. **Update Content** → Add article body
4. **Update Status** → Change to "usable"
5. **Search Articles** → Verify it appears in search

### Test Versioning

1. **Create Document** → Version 1
2. **Update Document** → Version 2
3. **Update Document** → Version 3
4. **Get Document History** → See all versions
5. **Get Document** (specific version) → Retrieve old version

### Test Access Control

1. Get token with limited scopes
2. Try operations (some should fail)
3. Get token with full scopes
4. Retry operations (should succeed)

## Troubleshooting

### Token Issues

**Problem**: "Unauthorized" or "Invalid token"

**Solution**:
- Manually run "Get Access Token"
- Check if Keycloak/auth service is running
- Verify credentials in environment

### Connection Refused

**Problem**: "Could not get response"

**Solution**:
- Check if services are running
- Verify port forwarding (if using Kubernetes)
- Check base_url in environment

### Validation Errors

**Problem**: "Schema validation failed"

**Solution**:
- Check request body matches NewsDoc format
- Ensure required fields are present
- Verify document type exists

## See Also

- [cURL Examples](curl-examples.md) - Command-line API testing
- [Authentication Guide](../06-authentication/keycloak.md) - OIDC setup
- [API Reference](../02-components/apis.md) - Complete API documentation
