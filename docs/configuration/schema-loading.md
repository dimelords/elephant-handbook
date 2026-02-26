# Schema Loading from GitHub

This document explains how eleconf loads schemas from GitHub and what happens during the process.

## Overview

Eleconf fetches JSON schema files from the [ttab/revisorschemas](https://github.com/ttab/revisorschemas) GitHub repository and loads them into the Elephant repository. These schemas define the structure and validation rules for documents.

## How It Works

### 1. Configuration

In `eleconf-config/schemas.hcl`, you specify which schemas to load:

```hcl
schema_set "core" {
  version    = "v1.1.2"
  repository = "https://github.com/ttab/revisorschemas.git"
  
  schemas = [
    "core",
    "core-planning",
    "core-metadoc",
    "core-genai",
  ]
}
```

This tells eleconf:
- **version**: Which git tag to use (e.g., `v1.1.2`)
- **repository**: Where to fetch schemas from
- **schemas**: Which schema files to load (e.g., `core.json`, `core-planning.json`)

### 2. Update Lock File

When you run `eleconf update`:

```bash
go run ./cmd/eleconf update -dir ../eleconf-config
```

Eleconf:
1. **Clones** the revisorschemas repository (or uses cached copy)
2. **Checks out** the specified git tag (e.g., `v1.1.2`)
3. **Reads** each schema file (e.g., `core.json`)
4. **Calculates** SHA256 hash of each schema
5. **Writes** `schema.lock.json` with versions and hashes

Example lock file entry:
```json
{
  "core": {
    "name": "core",
    "version": "v1.1.2",
    "hash": "4a2f30c01bfafddd078eda639473d9d773519a62804ab1dad990d02347e7ecad"
  }
}
```

### 3. Apply Schemas

When you run `eleconf apply`:

```bash
go run ./cmd/eleconf apply -env local -dir ../eleconf-config
```

Eleconf:
1. **Fetches** schemas from GitHub using the locked versions
2. **Compares** with schemas currently in the repository
3. **Shows diff** of changes (new schemas, updates, removals)
4. **Uploads** schemas to the repository via API
5. **Activates** the new schema versions

## What's in a Schema?

Schemas are JSON files that define:

- **Document structure** - What fields a document can have
- **Field types** - String, number, array, object, etc.
- **Validation rules** - Required fields, formats, patterns
- **Relationships** - Links between documents
- **Metadata** - Document type information

Example schema structure:
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Article",
  "type": "object",
  "properties": {
    "title": {
      "type": "string",
      "minLength": 1
    },
    "content": {
      "type": "array",
      "items": { "$ref": "#/$defs/block" }
    }
  },
  "required": ["title"]
}
```

## Schema Sets

Schemas are organized into sets:

### Core Schemas
- **core** - Base document types (article, image, video)
- **core-planning** - Planning and assignment documents
- **core-metadoc** - Metadata documents
- **core-genai** - GenAI integration schemas

### TT Schemas (Organization-specific)
- **tt** - TT-specific document types
- **tt-planning** - TT planning extensions
- **tt-wires** - Wire service integration
- **tt-print** - Print publication schemas

## Version Management

### Git Tags
Schemas are versioned using git tags:
- `v1.1.2` - Stable release
- `v1.1.3-pre1` - Pre-release version

### Lock File
The `schema.lock.json` ensures:
- **Reproducibility** - Same schemas every time
- **Integrity** - Hashes verify content hasn't changed
- **Traceability** - Know exactly which version is deployed

### Upgrading Schemas

To upgrade to a new schema version:

1. **Update** `schemas.hcl`:
   ```hcl
   schema_set "core" {
     version = "v1.2.0"  # Changed from v1.1.2
     # ...
   }
   ```

2. **Update lock file**:
   ```bash
   go run ./cmd/eleconf update -dir ../eleconf-config
   ```

3. **Review changes**:
   ```bash
   go run ./cmd/eleconf apply -env local -dir ../eleconf-config
   ```
   
   Eleconf will show:
   ```
   ~ schema upgrade core v1.1.2 => v1.2.0
     Added fields: author.bio
     Changed validation: title.minLength 1 => 5
   ```

4. **Apply** if changes look good

## Alternative: HTTP Loading

Instead of git repository, you can load schemas via HTTP:

```hcl
schema_set "core" {
  version = "v1.1.2"
  url_template = "https://raw.githubusercontent.com/ttab/revisorschemas/refs/tags/{{.Version}}/{{.Name}}.json"
  
  schemas = ["core", "core-planning"]
}
```

This fetches schemas directly from GitHub's raw content URLs.

## Local Development

For local schema development, you can:

1. **Clone revisorschemas** locally
2. **Use local path** in schemas.hcl:
   ```hcl
   schema_set "core" {
     version = "local"
     path = "/path/to/revisorschemas"
     schemas = ["core"]
   }
   ```

3. **Test changes** before pushing to GitHub

## Security

### Hash Verification
The lock file hashes ensure:
- Schemas haven't been tampered with
- Exact same content is deployed
- Changes are intentional and tracked

### Version Pinning
Using git tags ensures:
- Stable, immutable versions
- No surprise changes
- Controlled upgrades

## Troubleshooting

### "Schema version not found"
- Check the git tag exists in revisorschemas
- Verify network connectivity to GitHub
- Try `git ls-remote https://github.com/ttab/revisorschemas.git` to list tags

### "Hash mismatch"
- Schema content changed since lock file was created
- Run `eleconf update` to regenerate lock file
- Review changes before applying

### "Failed to fetch schema"
- Check network connectivity
- Verify GitHub repository is accessible
- Check if using correct repository URL

## See Also

- [Eleconf Usage](eleconf-usage.md)
- [Document Types](document-types.md)
- [Revisorschemas Repository](https://github.com/ttab/revisorschemas)
