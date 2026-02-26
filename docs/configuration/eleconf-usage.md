# Eleconf - Configuration Management

Eleconf is a CLI tool for managing Elephant repository configuration including schemas, document types, workflows, and statuses.

## Overview

Eleconf uses HCL configuration files to declare the desired state of your Elephant repository and applies changes automatically.

**Important:** Eleconf configures the repository's content and business logic (schemas, document types, workflows), NOT the database schema. Database tables are created automatically by the migration init containers when services start.

## What Eleconf Configures

- **Schemas** - JSON schemas for document validation (loaded from revisorschemas)
- **Document types** - Which document types are available (core/article, core/author, etc.)
- **Workflows** - Workflow steps and statuses for each document type
- **Meta types** - Metadata type configurations
- **Metrics** - Metric kind definitions

## What Eleconf Does NOT Configure

- Database tables (handled by migration init containers)
- Service configuration (handled by docker-compose environment variables)
- Authentication (handled by Keycloak setup script)

## Configuration Directory

The `eleconf-config/` directory contains:

- `local.hcl` - Environment configuration (endpoints)
- `schemas.hcl` - Schema versions from revisorschemas
- `article.hcl`, `author.hcl`, etc. - Document type configurations
- `schema.lock.json` - Locked schema versions (generated)

## Basic Usage

### 1. Update Lock File

When schema versions change, update the lock file:

```bash
cd eleconf
go run ./cmd/eleconf update -dir ../eleconf-config
```

This validates that the referenced schema versions exist and updates `schema.lock.json`.

### 2. Apply Configuration

Apply the configuration to your local Elephant repository:

```bash
cd eleconf
go run ./cmd/eleconf apply \
  -env local \
  -dir ../eleconf-config
```

This will:
1. Compare current repository config with declared config
2. Show a diff of changes
3. Ask for confirmation
4. Apply the changes

### 3. Review Changes

Eleconf shows a detailed diff before applying:

```
~ schema upgrade core v1.1.1 => v1.1.2
+ status "approved" for "core/article"
~ update workflow for "core/article":
  steps: ["draft", "done", "approved"]

Do you want to apply these changes? [y/n]:
```

## Configuration Files

### Environment Configuration

`local.hcl`:
```hcl
environment "local" {
  repository_endpoint = "http://localhost:1080"
  keycloak_endpoint = "http://localhost:8080/realms/elephant"
}
```

### Schema Configuration

`schemas.hcl`:
```hcl
schema_set "core" {
  version    = "v1.1.2"
  repository = "https://github.com/ttab/revisorschemas.git"
  
  schemas = [
    "core",
    "core-planning",
    "core-metadoc",
  ]
}
```

### Document Type Configuration

`article.hcl`:
```hcl
document "core/article" {
  meta_doc = "core/article+meta"
  
  statuses = [
    "draft",
    "done",
    "approved",
    "usable",
  ]
  
  workflow = {
    step_zero  = "draft"
    checkpoint = "usable"
    negative_checkpoint = "unpublished"
    steps      = ["draft", "done", "approved"]
  }
}
```

## When to Use Eleconf

- **Initial setup**: Configure schemas and document types after starting Elephant
- **Schema updates**: When upgrading to new schema versions
- **Workflow changes**: When modifying document workflows or statuses
- **New document types**: When adding new content types

## Authentication

Eleconf uses the same Keycloak authentication as other Elephant services. It will:
1. Open a browser for login
2. Store tokens in `~/.config/eleconf/tokens.json`
3. Automatically refresh tokens when needed

## Tips

- Always run `update` before `apply` to ensure lock file is current
- Review the diff carefully before confirming changes
- Schema downgrades will show a warning
- Use `-dry-run` flag to see changes without applying

## See Also

- [Eleconf README](../../eleconf/README.md)
- [Schema Management](schemas.md)
- [Document Types](document-types.md)
