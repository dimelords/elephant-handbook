# Examples

Practical examples for customizing and extending Elephant.

## Directory Structure

```
examples/
├── custom-newsdoc/         # Custom NewsDoc document formats
├── custom-schema/          # Custom Revisor validation schemas
└── oidc-providers/         # OIDC authentication configurations
```

## Custom NewsDoc

Examples of custom document types for different use cases:

- **Press Release**: Template for press releases with embargo dates
- **Product Review**: Structured product review format
- **Event Coverage**: Live event reporting template
- **Interview**: Q&A interview format
- **Research Report**: Long-form research with sections

## Custom Schemas

Revisor schema examples for content validation:

- **Standard Article**: Basic news article schema
- **Photo Essay**: Image-heavy content with captions
- **Video Story**: Video-first storytelling
- **Data Journalism**: Charts and data visualizations
- **Live Blog**: Real-time updates and timeline

## OIDC Providers

Configuration examples for popular identity providers:

- **Keycloak**: Self-hosted OIDC
- **Auth0**: Cloud identity platform
- **Okta**: Enterprise SSO
- **Azure AD**: Microsoft identity
- **Google Workspace**: Google SSO

## Usage

### Using Custom NewsDoc

1. Copy example to your fork of `newsdoc` repository
2. Modify types and structure as needed
3. Update `elephant-chrome` to support new types

```bash
# In newsdoc repository
cp examples/custom-newsdoc/press-release.go types/press-release.go
```

### Using Custom Schemas

1. Copy schema to your fork of `revisorschemas` repository
2. Add validation rules and constraints
3. Test with revisor CLI
4. Deploy with your elephant-repository

```bash
# In revisorschemas repository
cp examples/custom-schema/press-release.json schemas/acme/press-release.json
revisor validate --schema schemas/acme/press-release.json --document test.json
```

### Using OIDC Configurations

1. Choose your identity provider
2. Copy configuration example
3. Update with your provider details
4. Configure elephant-repository environment variables

```bash
# Set environment variables
export OIDC_ISSUER="https://keycloak.example.com/realms/elephant"
export OIDC_CLIENT_ID="elephant"
export OIDC_CLIENT_SECRET="your-secret"
```

## Contributing

Have a useful custom type or schema? Submit a PR to add it to the examples!

1. Create your example
2. Add documentation
3. Include test cases
4. Submit PR to elephant-handbook

## Best Practices

### Custom Document Types

- **Start Simple**: Begin with minimal required fields
- **Extend Existing**: Build on core types when possible
- **Validate Early**: Use revisor to enforce structure
- **Document Thoroughly**: Add clear field descriptions

### Custom Schemas

- **Be Specific**: Clear, descriptive constraint messages
- **Test Edge Cases**: Include valid and invalid examples
- **Version Carefully**: Plan for schema evolution
- **Use Deprecation**: Don't remove fields immediately

### OIDC Configuration

- **Secure Secrets**: Never commit client secrets
- **Test Thoroughly**: Verify token claims structure
- **Monitor Tokens**: Check expiration and refresh
- **Document Requirements**: Specify required scopes

## Further Reading

- [NewsDoc Documentation](../../docs/02-components/newsdoc.md)
- [Revisor Deep Dive](../../docs/02-components/revisor.md)
- [Authentication Setup](../../docs/06-authentication/oidc-setup.md)
- [Customization Guide](../../docs/10-customization/)
