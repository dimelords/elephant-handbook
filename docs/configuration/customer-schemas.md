# Customer Schema Management

This guide explains how to manage schemas as a customer organization (like Dimelords).

## Overview

As a customer, you should maintain your own fork of the revisorschemas repository. This allows you to:

- **Customize schemas** for your organization's needs
- **Control schema versions** independently
- **Add custom document types** specific to your workflows
- **Sync upstream changes** when needed

## Repository Structure

### Upstream (ttab/revisorschemas)
- **Purpose**: Core schemas maintained by TT
- **Contains**: Base document types (core/article, core/image, etc.)
- **Updates**: New features, bug fixes, improvements
- **URL**: https://github.com/ttab/revisorschemas

### Your Fork (dimelords/revisorschemas)
- **Purpose**: Your organization's schema repository
- **Contains**: Core schemas + your customizations
- **Updates**: You control when to sync from upstream
- **URL**: https://github.com/dimelords/revisorschemas

## Current Setup

You already have the correct setup:

```bash
$ git -C revisorschemas remote -v
origin    git@github.com:dimelords/revisorschemas.git (fetch/push)
upstream  git@github.com:ttab/revisorschemas (fetch/push)
```

And your `eleconf-config/schemas.hcl` points to your fork:

```hcl
schema_set "core" {
  version    = "v1.1.2"
  repository = "https://github.com/dimelords/revisorschemas.git"
  schemas    = ["core", "core-planning", "core-metadoc", "core-genai"]
}
```

## Workflow

### 1. Making Custom Changes

When you need to customize schemas:

```bash
cd revisorschemas

# Create a feature branch
git checkout -b feature/add-custom-field

# Edit schema files (e.g., core.json)
# Add your custom fields or document types

# Test your changes
go test ./...

# Commit and push to your fork
git add .
git commit -m "Add custom field for internal tracking"
git push origin feature/add-custom-field

# Create a pull request in your fork
# After review, merge to main
```

### 2. Creating a Release

After merging changes, create a version tag:

```bash
# Tag the release
git tag v1.1.4-dimelords
git push origin v1.1.4-dimelords
```

### 3. Using Your Custom Version

Update `eleconf-config/schemas.hcl`:

```hcl
schema_set "core" {
  version    = "v1.1.4-dimelords"  # Your custom version
  repository = "https://github.com/dimelords/revisorschemas.git"
  schemas    = ["core", "core-planning", "core-metadoc", "core-genai"]
}
```

Then apply:

```bash
cd eleconf
go run ./cmd/eleconf update -dir ../eleconf-config
go run ./cmd/eleconf apply -env local -dir ../eleconf-config
```

### 4. Syncing Upstream Changes

Periodically sync improvements from upstream:

```bash
cd revisorschemas

# Fetch upstream changes
git fetch upstream

# Review what's new
git log HEAD..upstream/main --oneline

# Merge upstream changes
git checkout main
git merge upstream/main

# Resolve any conflicts
# Test the merged changes
go test ./...

# Push to your fork
git push origin main

# Create a new release tag
git tag v1.2.0-dimelords
git push origin v1.2.0-dimelords
```

## Versioning Strategy

### Recommended Naming

Use a suffix to distinguish your versions:

- **Upstream**: `v1.1.2`, `v1.2.0`
- **Your fork**: `v1.1.2-dimelords`, `v1.2.0-dimelords`

This makes it clear which versions are custom.

### Version Types

1. **Upstream sync**: `v1.2.0-dimelords` (based on upstream v1.2.0)
2. **Custom features**: `v1.1.2-dimelords.1` (custom changes on top of v1.1.2)
3. **Hotfixes**: `v1.1.2-dimelords.1-hotfix` (urgent fixes)

## Schema Customization Examples

### Adding Custom Fields

In `core.json`, add organization-specific fields:

```json
{
  "properties": {
    "dimelords:internalId": {
      "type": "string",
      "description": "Internal tracking ID"
    },
    "dimelords:department": {
      "type": "string",
      "enum": ["news", "sports", "culture"]
    }
  }
}
```

### Creating Custom Document Types

Create a new file `dimelords-custom.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Dimelords Custom Document",
  "type": "object",
  "properties": {
    "title": { "type": "string" },
    "customField": { "type": "string" }
  }
}
```

Add to `eleconf-config/schemas.hcl`:

```hcl
schema_set "dimelords" {
  version    = "v1.0.0-dimelords"
  repository = "https://github.com/dimelords/revisorschemas.git"
  schemas    = ["dimelords-custom"]
}
```

### Extending Existing Types

Use JSON Schema's `allOf` to extend base types:

```json
{
  "allOf": [
    { "$ref": "core.json#/$defs/article" },
    {
      "properties": {
        "dimelords:priority": {
          "type": "string",
          "enum": ["low", "medium", "high", "urgent"]
        }
      }
    }
  ]
}
```

## Best Practices

### 1. Namespace Custom Fields

Prefix custom fields with your organization name:

```json
"dimelords:customField": { ... }
```

This prevents conflicts with upstream changes.

### 2. Document Changes

Maintain a CHANGELOG.md in your fork:

```markdown
## v1.1.4-dimelords (2026-02-25)
- Added dimelords:internalId field to core/article
- Added dimelords:department enum
```

### 3. Test Before Releasing

Always run tests before tagging:

```bash
go test ./...
```

### 4. Review Upstream Changes

Before syncing, review what changed:

```bash
git log HEAD..upstream/main --stat
```

Look for:
- Breaking changes
- New features you want
- Conflicts with your customizations

### 5. Keep Forks Updated

Sync regularly (monthly or quarterly) to:
- Get bug fixes
- Receive new features
- Reduce merge conflicts

## Troubleshooting

### Merge Conflicts

When syncing upstream:

```bash
# If conflicts occur
git status  # See conflicting files
# Edit files to resolve conflicts
git add .
git commit -m "Merge upstream v1.2.0"
```

### Schema Validation Errors

If schemas don't validate:

```bash
cd revisorschemas
go test ./...
```

Fix validation errors before releasing.

### Eleconf Can't Find Version

Ensure the tag exists:

```bash
git tag -l "v1.1.4-dimelords"
git push origin v1.1.4-dimelords
```

## Migration Path

If you're currently using upstream directly:

1. **Fork** ttab/revisorschemas to dimelords/revisorschemas
2. **Update** eleconf-config/schemas.hcl to point to your fork
3. **Tag** your current version (e.g., `v1.1.2-dimelords`)
4. **Test** with eleconf update/apply
5. **Document** your customization strategy

## See Also

- [Schema Loading](schema-loading.md)
- [Eleconf Usage](eleconf-usage.md)
- [JSON Schema Documentation](https://json-schema.org/)
- [Git Fork Workflow](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks)
