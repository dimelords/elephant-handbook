# Keycloak OIDC Configuration

Keycloak is an open-source identity and access management solution. This guide shows how to configure Elephant to use Keycloak for authentication.

## Prerequisites

- Keycloak server installed and running
- Admin access to Keycloak
- Elephant services deployed

## Keycloak Setup

### 1. Create Realm

```bash
# Login to Keycloak admin console
https://keycloak.example.com/admin

# Create new realm
Name: elephant
Display name: Elephant Editorial System
Enabled: Yes
```

### 2. Create Client

```
Client ID: elephant
Client Protocol: openid-connect
Access Type: confidential
Standard Flow Enabled: Yes
Direct Access Grants Enabled: Yes
Valid Redirect URIs:
  - https://elephant.example.com/*
  - http://localhost:5173/* (for development)
Web Origins:
  - https://elephant.example.com
  - http://localhost:5173
```

### 3. Configure Client Scopes

Create custom scope for Elephant permissions:

```
Name: elephant-permissions
Description: Elephant document permissions
Protocol: openid-connect
Include in Token Scope: Yes

Mappers:
  - Name: units
    Type: User Attribute
    User Attribute: units
    Token Claim Name: units
    Claim JSON Type: String
    Add to ID token: Yes
    Add to access token: Yes
    Add to userinfo: Yes
    Multivalued: Yes

  - Name: doc_scopes
    Type: User Attribute
    User Attribute: doc_scopes
    Token Claim Name: scope
    Claim JSON Type: String
    Add to access token: Yes
    Multivalued: Yes
```

### 4. Create Users

```
Username: editor@example.com
Email: editor@example.com
First Name: Jane
Last Name: Editor
Email Verified: Yes

Attributes:
  - units: ["unit-uuid-1", "unit-uuid-2"]
  - doc_scopes: ["doc_read", "doc_write"]

Credentials:
  Password: (set password)
  Temporary: No
```

### 5. Configure Token Settings

In Realm Settings → Tokens:

```
Access Token Lifespan: 5 minutes
Access Token Lifespan For Implicit Flow: 15 minutes
Client Login Timeout: 10 minutes
Login Action Timeout: 5 minutes
User-Initiated Action Lifespan: 5 minutes
```

## Elephant Configuration

### Environment Variables

For `elephant-repository`:

```bash
# Keycloak OIDC configuration
export OIDC_ENABLED=true
export OIDC_ISSUER="https://keycloak.example.com/realms/elephant"
export OIDC_AUDIENCE="elephant"
export OIDC_JWKS_URL="https://keycloak.example.com/realms/elephant/protocol/openid-connect/certs"

# Optional: For token introspection
export OIDC_CLIENT_ID="elephant"
export OIDC_CLIENT_SECRET="your-client-secret-from-keycloak"
```

For `elephant-chrome` (.env):

```bash
VITE_OIDC_AUTHORITY=https://keycloak.example.com/realms/elephant
VITE_OIDC_CLIENT_ID=elephant
VITE_OIDC_REDIRECT_URI=https://elephant.example.com/callback
VITE_OIDC_SCOPE="openid profile email elephant-permissions"
VITE_OIDC_RESPONSE_TYPE=code
VITE_OIDC_POST_LOGOUT_REDIRECT_URI=https://elephant.example.com/
```

### Kubernetes Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: oidc-config
  namespace: elephant
type: Opaque
stringData:
  issuer: "https://keycloak.example.com/realms/elephant"
  client-id: "elephant"
  client-secret: "your-client-secret"
  jwks-url: "https://keycloak.example.com/realms/elephant/protocol/openid-connect/certs"
```

## JWT Token Structure

Expected JWT claims from Keycloak:

```json
{
  "exp": 1709900000,
  "iat": 1709896400,
  "iss": "https://keycloak.example.com/realms/elephant",
  "aud": "elephant",
  "sub": "550e8400-e29b-41d4-a716-446655440000",
  "typ": "Bearer",
  "azp": "elephant",
  "email": "editor@example.com",
  "email_verified": true,
  "name": "Jane Editor",
  "preferred_username": "editor@example.com",
  "given_name": "Jane",
  "family_name": "Editor",
  "units": ["unit-uuid-1", "unit-uuid-2"],
  "scope": "openid profile email doc_read doc_write"
}
```

## Frontend Integration

```typescript
// src/auth/keycloak.ts
import { UserManager, WebStorageStateStore } from 'oidc-client-ts';

const keycloakConfig = {
  authority: import.meta.env.VITE_OIDC_AUTHORITY,
  client_id: import.meta.env.VITE_OIDC_CLIENT_ID,
  redirect_uri: import.meta.env.VITE_OIDC_REDIRECT_URI,
  response_type: 'code',
  scope: 'openid profile email elephant-permissions',
  post_logout_redirect_uri: import.meta.env.VITE_OIDC_POST_LOGOUT_REDIRECT_URI,
  userStore: new WebStorageStateStore({ store: window.localStorage }),
  automaticSilentRenew: true,
  loadUserInfo: true,
};

export const userManager = new UserManager(keycloakConfig);

// Login
export async function login() {
  await userManager.signinRedirect();
}

// Handle callback
export async function handleCallback() {
  const user = await userManager.signinRedirectCallback();
  return user;
}

// Logout
export async function logout() {
  await userManager.signoutRedirect();
}

// Get access token
export async function getAccessToken(): Promise<string | null> {
  const user = await userManager.getUser();
  return user?.access_token || null;
}
```

## Testing

### Get Token via Direct Grant

```bash
# Get access token
curl -X POST "https://keycloak.example.com/realms/elephant/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=elephant" \
  -d "client_secret=your-client-secret" \
  -d "username=editor@example.com" \
  -d "password=your-password" \
  -d "scope=openid profile email elephant-permissions"

# Response
{
  "access_token": "eyJhbGci...",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "refresh_token": "eyJhbGci...",
  "token_type": "Bearer",
  "id_token": "eyJhbGci...",
  "not-before-policy": 0,
  "session_state": "uuid",
  "scope": "openid profile email elephant-permissions"
}
```

### Test API Call

```bash
# Use access token with Elephant API
ACCESS_TOKEN="eyJhbGci..."

curl -X GET "https://elephant.example.com/api/documents" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Verify Token

```bash
# Decode JWT to verify claims
echo "$ACCESS_TOKEN" | cut -d. -f2 | base64 -d | jq .

# Or use jwt.io to decode and verify
```

## Troubleshooting

### Token Validation Fails

1. Check issuer URL matches exactly (including trailing slash)
2. Verify JWKS endpoint is accessible
3. Check token expiration time
4. Ensure required claims are present

### User Cannot Login

1. Verify user exists and is enabled
2. Check user has required attributes (units, scopes)
3. Verify client configuration
4. Check redirect URIs are correct

### Permissions Not Working

1. Verify units attribute is in token
2. Check scope claim contains doc_read, doc_write, etc.
3. Verify user attributes are correctly mapped
4. Check ACLs in Elephant repository

## Production Considerations

### High Availability

- Deploy Keycloak in cluster mode
- Use external PostgreSQL database
- Configure session replication
- Use load balancer

### Security

- Enable HTTPS only
- Use strong client secrets
- Configure CORS properly
- Enable brute force protection
- Set appropriate token lifespans
- Regular security updates

### Monitoring

- Enable Keycloak metrics
- Monitor authentication failures
- Track token issuance rates
- Alert on unusual patterns

### Backup

- Regular database backups
- Export realm configuration
- Document custom configurations
- Test restore procedures

## Further Reading

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OIDC Core Specification](https://openid.net/specs/openid-connect-core-1_0.html)
- [Elephant Authentication](../../docs/06-authentication/oidc-setup.md)
