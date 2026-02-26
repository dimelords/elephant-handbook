# Schema and Configuration Workflow Guide

Quick reference for managing schemas and configuration.

## Two Repositories

### revisorschemas/ (Schema Definitions)
- **Location**: Separate git repository
- **Purpose**: Define document structure and validation
- **Files**: JSON schema files (`.json`)
- **Example**: `dimelords-ai.json`

### eleconf-config/ (Configuration)
- **Location**: Part of elephant-local repository
- **Purpose**: Configure which schemas to use and how
- **Files**: HCL configuration files (`.hcl`)
- **Example**: `schemas.hcl`, `dimelords-ai.hcl`

## When to Update Each

### Update revisorschemas/ when:
- ✅ Adding new document types
- ✅ Adding/removing fields from documents
- ✅ Changing validation rules
- ✅ Modifying content block definitions
- ✅ Adding new meta types or links

### Update eleconf-config/ when:
- ✅ Changing which schema versions to use
- ✅ Adding/removing document statuses
- ✅ Modifying workflows
- ✅ Changing which schemas to load
- ✅ Configuring document type settings

## Complete Workflow

### Scenario: Adding a New AI Document Type

#### Step 1: Define the Schema (revisorschemas/)

```bash
cd revisorschemas

# Create or edit schema file
vim dimelords-ai.json

# Add your document type definition
# (see example below)

# Commit and tag
git add dimelords-ai.json
git commit -m "Add AI assistant document type"
git tag v1.0.0-dimelords
git push origin main
git push origin v1.0.0-dimelords
```

#### Step 2: Configure Schema Loading (eleconf-config/)

```bash
cd eleconf-config

# Edit schemas.hcl to reference your schema
vim schemas.hcl
```

Add:
```hcl
schema_set "dimelords" {
  version    = "v1.0.0-dimelords"
  repository = "https://github.com/dimelords/revisorschemas.git"
  schemas    = ["dimelords-ai"]
}
```

#### Step 3: Configure Document Types (eleconf-config/)

```bash
# Create document type configuration
vim dimelords-ai.hcl
```

Add:
```hcl
document "dimelords/ai-assistant" {
  statuses = ["draft", "testing", "active"]
  
  workflow = {
    step_zero  = "draft"
    checkpoint = "active"
    steps      = ["draft", "testing"]
  }
}
```

#### Step 4: Apply to Elephant

```bash
cd eleconf

# Update lock file (validates schema versions exist)
go run ./cmd/eleconf update -dir ../eleconf-config

# Apply to repository (uploads schemas and config)
go run ./cmd/eleconf apply -env local -dir ../eleconf-config
```

#### Step 5: Commit Configuration (eleconf-config/)

```bash
cd eleconf-config

# Commit the configuration changes
git add schemas.hcl dimelords-ai.hcl schema.lock.json
git commit -m "Add Dimelords AI schema configuration"
git push origin main
```

## File Examples

### revisorschemas/dimelords-ai.json (Schema Definition)

```json
{
  "version": 1,
  "name": "dimelords-ai",
  "documents": [
    {
      "name": "AI Assistant",
      "declares": "dimelords/ai-assistant",
      "meta": [
        {"ref": "dimelords://ai/config", "count": 1}
      ],
      "content": [
        {"ref": "core://genai/prompt-text"}
      ]
    }
  ],
  "meta": [
    {
      "id": "dimelords://ai/config",
      "block": {
        "name": "AI Config",
        "declares": {"type": "dimelords/ai-assistant"},
        "data": {
          "purpose": {
            "enum": ["generation", "checking", "translation"]
          }
        }
      }
    }
  ]
}
```

### eleconf-config/schemas.hcl (Schema Loading)

```hcl
schema_set "dimelords" {
  version    = "v1.0.0-dimelords"
  repository = "https://github.com/dimelords/revisorschemas.git"
  schemas    = ["dimelords-ai"]
}
```

### eleconf-config/dimelords-ai.hcl (Document Configuration)

```hcl
document "dimelords/ai-assistant" {
  statuses = ["draft", "testing", "active"]
  
  workflow = {
    step_zero  = "draft"
    checkpoint = "active"
    steps      = ["draft", "testing"]
  }
}
```

## Quick Commands

### Check what's currently loaded
```bash
cd eleconf
go run ./cmd/eleconf status -env local
```

### Update lock file only (no changes to Elephant)
```bash
cd eleconf
go run ./cmd/eleconf update -dir ../eleconf-config
```

### Preview changes without applying
```bash
cd eleconf
go run ./cmd/eleconf apply -env local -dir ../eleconf-config --dry-run
```

### Apply changes
```bash
cd eleconf
go run ./cmd/eleconf apply -env local -dir ../eleconf-config
```

## Common Scenarios

### Scenario 1: Just changing a workflow

**Only update**: `eleconf-config/`

```bash
cd eleconf-config
vim article.hcl  # Change workflow steps
cd ../eleconf
go run ./cmd/eleconf apply -env local -dir ../eleconf-config
```

### Scenario 2: Adding a new field to existing document

**Update both**:

1. `revisorschemas/` - Add field to schema
2. Tag new version
3. `eleconf-config/schemas.hcl` - Update version number
4. Apply with eleconf

### Scenario 3: Using a new schema version from upstream

**Only update**: `eleconf-config/schemas.hcl`

```hcl
schema_set "core" {
  version = "v1.2.0"  # Changed from v1.1.2
  # ...
}
```

Then run eleconf update and apply.

## Troubleshooting

### "Schema version not found"
- Check the tag exists in revisorschemas: `git -C revisorschemas tag -l`
- Push the tag: `git -C revisorschemas push origin v1.0.0-dimelords`

### "Hash mismatch"
- Schema changed since lock file was created
- Run: `go run ./cmd/eleconf update -dir ../eleconf-config`

### Changes not appearing in Elephant
- Did you run `eleconf apply`?
- Check Elephant logs: `docker compose -f docker-compose.core.yml logs repository`

## Summary

| Task | Update revisorschemas/ | Update eleconf-config/ | Run eleconf |
|------|----------------------|----------------------|-------------|
| Add new document type | ✅ | ✅ | ✅ |
| Add field to document | ✅ | - | ✅ |
| Change workflow | - | ✅ | ✅ |
| Change statuses | - | ✅ | ✅ |
| Upgrade schema version | - | ✅ | ✅ |
| Add validation rule | ✅ | - | ✅ |

## See Also

- [Schema Loading](schema-loading.md)
- [Customer Schemas](customer-schemas.md)
- [Eleconf Usage](eleconf-usage.md)
