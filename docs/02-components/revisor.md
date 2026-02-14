# Revisor - Schema Validation Engine

## Overview

Revisor is Elephant's flexible schema validation engine. It validates NewsDoc documents against configurable schemas with support for:

- Type constraints (strings, numbers, objects, arrays)
- Custom constraint types
- Deprecation warnings
- Template-based document creation
- Hierarchical schema composition

## Architecture

```
┌─────────────┐
│  Document   │
│   (JSON)    │
└──────┬──────┘
       │
       ▼
┌─────────────────┐      ┌──────────────┐
│    Revisor      │◄─────┤   Schema     │
│   Validator     │      │  Definition  │
└────────┬────────┘      └──────────────┘
         │
         ├─► String Constraints
         ├─► Document Constraints
         ├─► Block Constraints
         ├─► Deprecation Checks
         │
         ▼
  ┌───────────────┐
  │  Validation   │
  │    Result     │
  │ (Pass/Fail +  │
  │   Warnings)   │
  └───────────────┘
```

## Schema Structure

Schemas in Revisor are defined in JSON and describe the expected structure of documents.

### Basic Schema Example

```json
{
  "name": "core/article",
  "version": "1.0.0",
  "labels": {
    "en": "Article",
    "sv": "Artikel"
  },
  "declares": [
    {
      "name": "title",
      "type": "string",
      "labels": {
        "en": "Title"
      },
      "constraints": [
        {
          "type": "required"
        },
        {
          "type": "length",
          "min": 5,
          "max": 200
        }
      ]
    },
    {
      "name": "content",
      "type": "document",
      "labels": {
        "en": "Content"
      },
      "constraints": [
        {
          "type": "document/contains-block",
          "count": "required",
          "block": "core/paragraph"
        }
      ]
    }
  ]
}
```

## Constraint Types

### String Constraints

**`required`** - Field must be present and non-empty
```json
{
  "type": "required"
}
```

**`length`** - String length validation
```json
{
  "type": "length",
  "min": 5,
  "max": 200
}
```

**`pattern`** - Regex validation
```json
{
  "type": "pattern",
  "value": "^[A-Z][a-z]+$",
  "message": "Must start with uppercase letter"
}
```

**`enum`** - Must be one of allowed values
```json
{
  "type": "enum",
  "values": ["draft", "published", "archived"]
}
```

### Document Constraints

**`document/contains-block`** - Require specific block types
```json
{
  "type": "document/contains-block",
  "count": "required",
  "block": "core/paragraph"
}
```

Count options:
- `required` - At least one must exist
- `optional` - Zero or more allowed
- `forbidden` - None allowed

**`document/no-empty-blocks`** - Blocks must have content
```json
{
  "type": "document/no-empty-blocks"
}
```

### Block Constraints

**`block/data-required`** - Block must have specific data fields
```json
{
  "type": "block/data-required",
  "path": "text.value",
  "message": "Paragraph must have text content"
}
```

**`block/link-required`** - Block must have specific links
```json
{
  "type": "block/link-required",
  "rel": "image",
  "message": "Image block must link to an image"
}
```

### Custom Constraints

You can implement custom constraint types in Go:

```go
// Custom constraint implementation
func ValidateCustomConstraint(ctx context.Context, constraint revisor.Constraint, value interface{}) ([]revisor.ValidationError, error) {
    // Your validation logic here
    return nil, nil
}

// Register custom constraint
revisor.RegisterConstraintType("custom/my-constraint", ValidateCustomConstraint)
```

## Deprecation Handling

Revisor supports marking schemas and fields as deprecated:

```json
{
  "name": "title",
  "type": "string",
  "deprecated": {
    "message": "Use 'headline' instead",
    "replacement": "headline"
  }
}
```

Deprecation warnings are returned separately from validation errors:

```go
result, err := validator.Validate(document, schema)
if err != nil {
    // Handle error
}

if !result.Valid {
    // Handle validation errors
}

if len(result.Warnings) > 0 {
    // Handle deprecation warnings
}
```

## Templates

Templates define the initial structure for new documents:

```json
{
  "name": "core/article",
  "template": {
    "type": "core/article",
    "uri": "",
    "uuid": "",
    "title": "",
    "meta": [],
    "links": [],
    "content": [
      {
        "type": "core/heading-1",
        "uuid": "",
        "data": {
          "text": ""
        }
      },
      {
        "type": "core/paragraph",
        "uuid": "",
        "data": {
          "text": ""
        }
      }
    ]
  }
}
```

Creating a document from template:

```go
doc, err := schema.NewDocument()
```

## Integration with elephant-repository

Revisor is integrated directly into elephant-repository:

```go
// When creating/updating a document
validator := revisor.NewValidator(schemas)

result, err := validator.Validate(document, document.Type)
if err != nil {
    return fmt.Errorf("validation error: %w", err)
}

if !result.Valid {
    return fmt.Errorf("document invalid: %v", result.Errors)
}

// Document is valid, proceed with storage
```

## Schema Loading

Schemas are typically loaded from the `revisorschemas` repository:

```bash
# In elephant-repository
go get github.com/dimelords/revisorschemas
```

```go
import "github.com/dimelords/revisorschemas"

// Load schemas
schemaFS := revisorschemas.Schemas()
validator, err := revisor.NewValidatorFromFS(schemaFS)
```

## Custom Schemas

To create custom schemas for your organization:

1. Fork `revisorschemas` repository
2. Add your custom schema files in `schemas/` directory
3. Follow the naming convention: `{namespace}/{type}.json`
4. Update your elephant-repository to use your fork

Example custom schema file: `schemas/acme/press-release.json`

```json
{
  "name": "acme/press-release",
  "version": "1.0.0",
  "labels": {
    "en": "Press Release"
  },
  "declares": [
    {
      "name": "embargo_until",
      "type": "string",
      "labels": {
        "en": "Embargo Until"
      },
      "constraints": [
        {
          "type": "pattern",
          "value": "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$",
          "message": "Must be ISO 8601 datetime"
        }
      ]
    }
  ]
}
```

## Validation Result Structure

```go
type ValidationResult struct {
    Valid    bool
    Errors   []ValidationError
    Warnings []DeprecationWarning
}

type ValidationError struct {
    Path    string  // JSON path to invalid field
    Message string  // Human-readable error
    Code    string  // Machine-readable error code
}

type DeprecationWarning struct {
    Path        string
    Message     string
    Replacement string
}
```

## Performance Considerations

Revisor is designed for performance:

- **Compiled Schemas**: Schemas are parsed and compiled once at startup
- **Efficient Traversal**: Documents are traversed in a single pass
- **Constraint Caching**: Constraint validators are cached
- **Minimal Allocations**: Designed to minimize memory allocations

Typical validation performance:
- Small document (< 1KB): < 1ms
- Medium document (10-100KB): < 5ms
- Large document (> 1MB): < 50ms

## Testing Your Schemas

Revisor includes a CLI tool for testing schemas:

```bash
# Validate a document against a schema
revisor validate \
  --schema schemas/core/article.json \
  --document test-article.json

# Run test suite for a schema
revisor test \
  --schema schemas/core/article.json \
  --tests testdata/article-tests/
```

Test structure:

```
testdata/
  article-tests/
    valid-minimal.json          # Should pass
    valid-complete.json         # Should pass
    invalid-missing-title.json  # Should fail
    invalid-empty-content.json  # Should fail
```

## Schema Versioning

Schemas support semantic versioning:

```json
{
  "name": "core/article",
  "version": "2.0.0",
  "previous_versions": ["1.0.0", "1.1.0"]
}
```

When updating schemas:
- **Patch** (1.0.x): Bug fixes, no breaking changes
- **Minor** (1.x.0): New optional fields, backward compatible
- **Major** (x.0.0): Breaking changes, not backward compatible

## Best Practices

1. **Start Simple**: Begin with minimal required constraints
2. **Add Validation Incrementally**: Don't over-constrain initially
3. **Use Descriptive Messages**: Help users understand validation errors
4. **Test Thoroughly**: Write test cases for valid and invalid documents
5. **Version Carefully**: Avoid breaking changes when possible
6. **Document Constraints**: Add comments explaining why constraints exist
7. **Use Deprecation**: Don't remove fields immediately, deprecate first

## Common Patterns

### Required Field with Fallback

```json
{
  "name": "title",
  "type": "string",
  "constraints": [
    {
      "type": "required"
    }
  ],
  "default": "Untitled"
}
```

### Conditional Validation

Use custom constraints for complex business rules:

```go
// If type is "video", require video link
func ValidateVideoRequirement(ctx context.Context, constraint revisor.Constraint, doc revisor.Document) ([]revisor.ValidationError, error) {
    if doc.Type == "core/video" {
        hasVideo := false
        for _, link := range doc.Links {
            if link.Rel == "video" {
                hasVideo = true
                break
            }
        }
        if !hasVideo {
            return []revisor.ValidationError{{
                Path: "links",
                Message: "Video document must have video link",
            }}, nil
        }
    }
    return nil, nil
}
```

### Hierarchical Schemas

Extend base schemas:

```json
{
  "name": "acme/special-article",
  "extends": "core/article",
  "declares": [
    {
      "name": "special_field",
      "type": "string"
    }
  ]
}
```

## Error Handling

Handle validation errors gracefully in your application:

```go
result, err := validator.Validate(doc, schema)
if err != nil {
    // System error, not validation error
    log.Errorf("validation system error: %v", err)
    return err
}

if !result.Valid {
    // Document doesn't meet schema requirements
    for _, e := range result.Errors {
        log.Warnf("validation error at %s: %s", e.Path, e.Message)
    }
    return fmt.Errorf("document validation failed")
}

for _, w := range result.Warnings {
    // Deprecated fields used
    log.Infof("deprecation warning at %s: %s", w.Path, w.Message)
}
```

## Further Reading

- [revisor GitHub Repository](https://github.com/dimelords/revisor)
- [revisorschemas Repository](https://github.com/dimelords/revisorschemas)
- [NewsDoc Format](newsdoc.md)
- [Custom NewsDoc](../10-customization/custom-newsdoc.md)
