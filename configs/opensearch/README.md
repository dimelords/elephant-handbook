# Custom OpenSearch Image

This directory contains a custom OpenSearch Dockerfile that extends the official OpenSearch image with additional plugins required by Elephant.

## What's Added

### ICU Analysis Plugin

The [ICU Analysis plugin](https://opensearch.org/docs/latest/analyzers/icu/) provides:

- **Unicode normalization** - Proper handling of accented characters
- **Case folding** - Language-aware case conversion
- **Collation** - Locale-specific sorting
- **Tokenization** - Better word boundary detection for multiple languages
- **Transliteration** - Converting between scripts (e.g., Cyrillic to Latin)

This is essential for:
- Swedish text analysis (å, ä, ö handling)
- Multi-language content
- Proper search across different character sets
- Accurate sorting and filtering

## Usage

The custom image is built automatically by docker-compose:

```yaml
opensearch:
  build:
    context: ../../opensearch
    dockerfile: Dockerfile
```

## Base Image

- **Base**: `opensearchproject/opensearch:2.19.0`
- **Plugin**: `analysis-icu`

## Why Not Use the Standard Image?

The standard OpenSearch image doesn't include the ICU plugin by default. Without it:
- Swedish characters (å, ä, ö) may not be handled correctly
- Search quality degrades for non-ASCII text
- Sorting may be incorrect for localized content

## Updating

To update the OpenSearch version:

1. Edit `Dockerfile` and change the base image version
2. Rebuild: `docker compose build opensearch`
3. Test thoroughly with Swedish content

## Verifying the Plugin

Check if the plugin is installed:

```bash
curl http://localhost:9200/_cat/plugins
```

Should show:
```
opensearch-node analysis-icu 2.19.0
```

## See Also

- [OpenSearch ICU Analysis Plugin](https://opensearch.org/docs/latest/analyzers/icu/)
- [elephant-index README](../elephant-index/README.md) - Uses this for text analysis
