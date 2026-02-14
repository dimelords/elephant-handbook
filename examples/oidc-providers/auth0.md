# Auth0 OIDC Configuration

Auth0 is a cloud-based identity platform that provides authentication and authorization services. This guide shows how to configure Elephant to use Auth0.

## Prerequisites

- Auth0 account (free or paid tier)
- Auth0 tenant created
- Elephant services deployed

## Auth0 Setup

### 1. Create Application

```
Dashboard → Applications → Create Application

Name: Elephant Editorial System
Application Type: Single Page Application
Technology: React

Settings:
  - Allowed Callback URLs:
      https://elephant.example.com/callback
      http://localhost:5173/callback (development)

  - Allowed Logout URLs:
      https://elephant.example.com
      http://localhost:5173 (development)

  - Allowed Web Origins:
      https://elephant.example.com
      http://localhost:5173 (development)

  - Allowed Origins (CORS):
      https://elephant.example.com
      http://localhost:5173 (development)
```

Save the following for configuration:
- **Domain**: your-tenant.auth0.com
- **Client ID**: your-client-id
- **Client Secret**: your-client-secret (for backend)

### 2. Create API

```
Dashboard → APIs → Create API

Name: Elephant Repository API
Identifier: https://api.elephant.example.com
Signing Algorithm: RS256

Settings:
  - Enable RBAC: Yes
  - Add Permissions in Access Token: Yes
  - Allow Skipping User Consent: Yes
  - Token Expiration: 86400 seconds (24 hours)
  - Token Expiration For Browser Flows: 7200 seconds (2 hours)
```

### 3. Define Permissions

In your API → Permissions tab:

```
Permission (Scope)     | Description
-----------------------|----------------------------------
doc:read               | Read documents
doc:write              | Create and update documents
doc:delete             | Delete documents
doc:admin              | Administrative operations
```

### 4. Create Custom Claims (Action)

Dashboard → Actions → Flows → Login

Create new Action:

```javascript
/**
* Handler that will be called during the execution of a PostLogin flow.
*
* @param {Event} event - Details about the user and the context in which they are logging in.
* @param {PostLoginAPI} api - Interface whose methods can be used to change the behavior of the login.
*/
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://elephant.example.com/';

  // Add units from user metadata
  if (event.user.user_metadata && event.user.user_metadata.units) {
    api.accessToken.setCustomClaim(`${namespace}units`, event.user.user_metadata.units);
    api.idToken.setCustomClaim(`${namespace}units`, event.user.user_metadata.units);
  }

  // Add display name
  const name = event.user.name || event.user.email;
  api.accessToken.setCustomClaim(`sub_name`, name);
  api.idToken.setCustomClaim(`sub_name`, name);

  // Map permissions to Elephant scopes
  const permissions = event.authorization?.permissions || [];
  const scopes = permissions.map(p => p.replace(':', '_')).join(' ');

  if (scopes) {
    api.accessToken.setCustomClaim(`${namespace}scope`, scopes);
  }
};
```

Add this Action to your Login flow.

### 5. Create Users

Dashboard → User Management → Users → Create User

```
Email: editor@example.com
Password: (set strong password)
Connection: Username-Password-Authentication

User Metadata (JSON):
{
  "units": ["unit-uuid-1", "unit-uuid-2"]
}

Assign Permissions:
  - doc:read
  - doc:write
```

### 6. Create Rules (Alternative to Actions)

If using Rules instead of Actions:

Dashboard → Auth Pipeline → Rules → Create Rule

```javascript
function addElephantClaims(user, context, callback) {
  const namespace = 'https://elephant.example.com/';

  // Add units
  if (user.user_metadata && user.user_metadata.units) {
    context.accessToken[namespace + 'units'] = user.user_metadata.units;
    context.idToken[namespace + 'units'] = user.user_metadata.units;
  }

  // Add display name
  context.accessToken['sub_name'] = user.name || user.email;
  context.idToken['sub_name'] = user.name || user.email;

  // Add scope
  if (context.authorization && context.authorization.permissions) {
    const scopes = context.authorization.permissions
      .map(p => p.replace(':', '_'))
      .join(' ');
    context.accessToken[namespace + 'scope'] = scopes;
  }

  callback(null, user, context);
}
```

## Elephant Configuration

### Environment Variables

For `elephant-repository`:

```bash
# Auth0 OIDC configuration
export OIDC_ENABLED=true
export OIDC_ISSUER="https://your-tenant.auth0.com/"
export OIDC_AUDIENCE="https://api.elephant.example.com"
export OIDC_JWKS_URL="https://your-tenant.auth0.com/.well-known/jwks.json"

# Optional: For machine-to-machine
export OIDC_CLIENT_ID="your-client-id"
export OIDC_CLIENT_SECRET="your-client-secret"
```

For `elephant-chrome` (.env):

```bash
VITE_AUTH0_DOMAIN=your-tenant.auth0.com
VITE_AUTH0_CLIENT_ID=your-client-id
VITE_AUTH0_AUDIENCE=https://api.elephant.example.com
VITE_AUTH0_REDIRECT_URI=https://elephant.example.com/callback
VITE_AUTH0_SCOPE="openid profile email doc:read doc:write"
```

### Kubernetes Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: auth0-config
  namespace: elephant
type: Opaque
stringData:
  domain: "your-tenant.auth0.com"
  client-id: "your-client-id"
  client-secret: "your-client-secret"
  audience: "https://api.elephant.example.com"
  issuer: "https://your-tenant.auth0.com/"
```

## JWT Token Structure

Expected JWT claims from Auth0:

```json
{
  "iss": "https://your-tenant.auth0.com/",
  "sub": "auth0|550e8400e29b41d4a716446655440000",
  "aud": [
    "https://api.elephant.example.com",
    "https://your-tenant.auth0.com/userinfo"
  ],
  "iat": 1709896400,
  "exp": 1709982800,
  "azp": "your-client-id",
  "scope": "openid profile email doc:read doc:write",
  "permissions": [
    "doc:read",
    "doc:write"
  ],
  "https://elephant.example.com/units": [
    "unit-uuid-1",
    "unit-uuid-2"
  ],
  "https://elephant.example.com/scope": "doc_read doc_write",
  "sub_name": "Jane Editor"
}
```

## Frontend Integration

### Install Auth0 SDK

```bash
npm install @auth0/auth0-react
```

### Configure Provider

```typescript
// src/main.tsx
import { Auth0Provider } from '@auth0/auth0-react';

const root = ReactDOM.createRoot(document.getElementById('root')!);

root.render(
  <React.StrictMode>
    <Auth0Provider
      domain={import.meta.env.VITE_AUTH0_DOMAIN}
      clientId={import.meta.env.VITE_AUTH0_CLIENT_ID}
      authorizationParams={{
        redirect_uri: import.meta.env.VITE_AUTH0_REDIRECT_URI,
        audience: import.meta.env.VITE_AUTH0_AUDIENCE,
        scope: import.meta.env.VITE_AUTH0_SCOPE,
      }}
      useRefreshTokens={true}
      cacheLocation="localstorage"
    >
      <App />
    </Auth0Provider>
  </React.StrictMode>
);
```

### Use in Components

```typescript
// src/components/LoginButton.tsx
import { useAuth0 } from '@auth0/auth0-react';

export function LoginButton() {
  const { loginWithRedirect, isAuthenticated, logout, user } = useAuth0();

  if (isAuthenticated) {
    return (
      <div>
        <span>Welcome, {user?.name}</span>
        <button onClick={() => logout({
          logoutParams: { returnTo: window.location.origin }
        })}>
          Logout
        </button>
      </div>
    );
  }

  return <button onClick={() => loginWithRedirect()}>Login</button>;
}
```

### API Calls with Token

```typescript
// src/lib/api.ts
import { useAuth0 } from '@auth0/auth0-react';

export function useElephantAPI() {
  const { getAccessTokenSilently } = useAuth0();

  async function fetchDocuments() {
    const token = await getAccessTokenSilently({
      authorizationParams: {
        audience: import.meta.env.VITE_AUTH0_AUDIENCE,
        scope: 'doc:read',
      },
    });

    const response = await fetch('https://api.elephant.example.com/documents', {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    return response.json();
  }

  return { fetchDocuments };
}
```

## Testing

### Get Token via Client Credentials

For machine-to-machine authentication:

```bash
curl -X POST "https://your-tenant.auth0.com/oauth/token" \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "client_credentials",
    "client_id": "your-m2m-client-id",
    "client_secret": "your-m2m-client-secret",
    "audience": "https://api.elephant.example.com"
  }'

# Response
{
  "access_token": "eyJhbGci...",
  "token_type": "Bearer",
  "expires_in": 86400
}
```

### Test API Call

```bash
ACCESS_TOKEN="eyJhbGci..."

curl -X GET "https://api.elephant.example.com/documents" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

## Monitoring

### Auth0 Dashboard

Monitor in Dashboard → Monitoring:

- Login attempts and failures
- API usage
- Token requests
- Error rates

### Logs

Dashboard → Monitoring → Logs:

- Filter by event type
- View user login history
- Track API errors
- Export logs for analysis

### Alerts

Configure alerts for:
- Failed login attempts
- Unusual API usage
- Permission errors
- Token expiration issues

## Production Considerations

### Performance

- Enable token caching
- Use refresh tokens
- Configure appropriate token lifespans
- Use CDN for Auth0 scripts

### Security

- Enable Multi-Factor Authentication (MFA)
- Configure password policies
- Enable breached password detection
- Use attack protection features
- Regular security reviews

### High Availability

- Auth0 is cloud-hosted (99.99% SLA)
- Multi-region support
- Automatic failover
- DDoS protection

### Compliance

- GDPR compliance features
- Data residency options (US/EU/AU)
- Audit logs
- Regular compliance reports

## Cost Optimization

### Free Tier Limits

- 7,000 active users
- Unlimited logins
- 2 social connections
- Email/password database

### Paid Tier Benefits

- More active users
- Advanced features (MFA, custom domains)
- Premium support
- SLA guarantees

## Troubleshooting

### Token Missing Claims

1. Verify Action/Rule is enabled
2. Check custom claim namespaces
3. Verify user metadata structure
4. Test with Auth0 debugger

### CORS Errors

1. Add origins in Auth0 dashboard
2. Verify exact URL matches
3. Check HTTPS vs HTTP
4. Test with browser console

### Permission Denied

1. Verify API permissions assigned to user
2. Check scope in token request
3. Verify audience matches API identifier
4. Check backend token validation

## Migration from Other Providers

Auth0 supports importing users from:

- LDAP
- Active Directory
- Custom databases
- Other OAuth providers

Use Auth0's migration features for seamless transition.

## Further Reading

- [Auth0 Documentation](https://auth0.com/docs)
- [Auth0 React SDK](https://github.com/auth0/auth0-react)
- [OIDC Best Practices](https://auth0.com/docs/secure/security-guidance/best-practices)
- [Elephant Authentication](../../docs/06-authentication/oidc-setup.md)
