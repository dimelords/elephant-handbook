# PostgreSQL Database Queries

Common PostgreSQL queries for Elephant database operations, debugging, and monitoring.

## Quick Start Script

The handbook includes a comprehensive script with all examples:

```bash
cd elephant-handbook/scripts
./postgres-queries.sh
```

## Connection

### Docker Compose

```bash
docker compose exec -T postgres psql -U elephant -d elephant
```

### Direct Connection

```bash
psql postgresql://elephant:elephant@localhost:5432/elephant
```

### Kubernetes

```bash
kubectl exec -it postgres-0 -n elephant -- psql -U elephant -d elephant
```

## Database Schema

### List All Tables

```sql
\dt
```

### Describe Table Structure

```sql
\d document
\d document_version
\d eventlog
\d acl
```

### Table Sizes

```sql
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Document Queries

### Count Documents by Type

```sql
SELECT
    type,
    COUNT(*) as count,
    COUNT(DISTINCT uuid) as unique_documents
FROM document
GROUP BY type
ORDER BY count DESC;
```

### List Recent Documents

```sql
SELECT
    uuid,
    type,
    uri,
    current_version,
    created,
    updated
FROM document
ORDER BY created DESC
LIMIT 20;
```

### Find Document by UUID

```sql
SELECT *
FROM document
WHERE uuid = 'YOUR-UUID-HERE';
```

### Find Documents by URI Pattern

```sql
SELECT
    uuid,
    type,
    uri,
    created
FROM document
WHERE uri ILIKE '%search-term%'
ORDER BY created DESC
LIMIT 10;
```

### Find Documents by Type

```sql
SELECT
    uuid,
    uri,
    creator_uri,
    created,
    current_version
FROM document
WHERE type = 'core/article'
ORDER BY created DESC
LIMIT 20;
```

## Version History

### Get Document Version History

```sql
SELECT
    version,
    created,
    creator,
    LENGTH(document::text) as doc_size
FROM document_version
WHERE uuid = 'YOUR-UUID-HERE'
ORDER BY version DESC;
```

### Count Versions per Document

```sql
SELECT
    d.uuid,
    d.type,
    d.uri,
    COUNT(dv.version) as version_count
FROM document d
LEFT JOIN document_version dv ON d.uuid = dv.uuid
GROUP BY d.uuid, d.type, d.uri
ORDER BY version_count DESC
LIMIT 20;
```

### Find Documents with Many Versions

```sql
SELECT
    d.uuid,
    d.type,
    d.uri,
    COUNT(dv.version) as versions
FROM document d
JOIN document_version dv ON d.uuid = dv.uuid
GROUP BY d.uuid, d.type, d.uri
HAVING COUNT(dv.version) > 10
ORDER BY versions DESC;
```

## Status Queries

### Count Documents by Status

```sql
SELECT
    ds.status,
    COUNT(*) as count
FROM document_status ds
JOIN document d ON ds.uuid = d.uuid
GROUP BY ds.status
ORDER BY count DESC;
```

### Find Documents by Status

```sql
SELECT
    d.uuid,
    d.type,
    d.uri,
    ds.status,
    ds.version
FROM document d
JOIN document_status ds ON d.uuid = ds.uuid
WHERE ds.status = 'published'
ORDER BY d.updated DESC
LIMIT 20;
```

### Status Change History

```sql
SELECT
    uuid,
    version,
    status,
    created
FROM document_status
WHERE uuid = 'YOUR-UUID-HERE'
ORDER BY version ASC;
```

## Eventlog Queries

### Recent Eventlog Entries

```sql
SELECT
    id,
    event,
    type,
    uuid,
    timestamp,
    updater
FROM eventlog
ORDER BY id DESC
LIMIT 50;
```

### Eventlog by Document

```sql
SELECT
    id,
    event,
    type,
    timestamp,
    updater
FROM eventlog
WHERE uuid = 'YOUR-UUID-HERE'
ORDER BY id ASC;
```

### Eventlog Statistics

```sql
SELECT
    event,
    COUNT(*) as count
FROM eventlog
GROUP BY event
ORDER BY count DESC;
```

### Events by User

```sql
SELECT
    updater,
    COUNT(*) as event_count,
    MIN(timestamp) as first_event,
    MAX(timestamp) as last_event
FROM eventlog
GROUP BY updater
ORDER BY event_count DESC;
```

### Gap Detection in Eventlog

```sql
-- Find missing event IDs
SELECT
    id + 1 as missing_start,
    next_id - 1 as missing_end
FROM (
    SELECT
        id,
        LEAD(id) OVER (ORDER BY id) as next_id
    FROM eventlog
) t
WHERE next_id > id + 1;
```

## ACL (Access Control) Queries

### List ACL Entries

```sql
SELECT
    uuid,
    uri,
    permissions
FROM acl
LIMIT 20;
```

### Find Documents Accessible to Unit

```sql
SELECT
    d.uuid,
    d.type,
    d.uri,
    a.permissions
FROM document d
JOIN acl a ON d.uuid = a.uuid
WHERE a.uri = 'unit://dimelords/editorial'
ORDER BY d.created DESC
LIMIT 20;
```

### Documents Without ACL

```sql
SELECT
    d.uuid,
    d.type,
    d.uri
FROM document d
LEFT JOIN acl a ON d.uuid = a.uuid
WHERE a.uuid IS NULL;
```

## Meta and Links

### Documents with Specific Meta Type

```sql
SELECT
    uuid,
    type,
    uri,
    meta
FROM document
WHERE meta @> '[{"type": "core/description"}]'::jsonb
LIMIT 10;
```

### Documents with Links

```sql
SELECT
    uuid,
    type,
    uri,
    jsonb_array_length(links) as link_count
FROM document
WHERE jsonb_array_length(links) > 0
ORDER BY link_count DESC
LIMIT 20;
```

### Extract Specific Meta Field

```sql
SELECT
    uuid,
    type,
    uri,
    meta -> 0 -> 'data' ->> 'text' as description
FROM document
WHERE type = 'core/article'
    AND meta @> '[{"type": "core/description"}]'::jsonb
LIMIT 10;
```

## Performance and Monitoring

### Database Statistics

```sql
SELECT
    'Total Documents' as metric,
    COUNT(*) as value
FROM document
UNION ALL
SELECT
    'Total Document Versions',
    COUNT(*)
FROM document_version
UNION ALL
SELECT
    'Total Eventlog Entries',
    COUNT(*)
FROM eventlog
UNION ALL
SELECT
    'Total ACL Entries',
    COUNT(*)
FROM acl;
```

### Active Connections

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    LEFT(query, 50) as query
FROM pg_stat_activity
WHERE datname = 'elephant';
```

### Slow Queries

```sql
SELECT
    pid,
    usename,
    now() - query_start as duration,
    LEFT(query, 100) as query
FROM pg_stat_activity
WHERE state = 'active'
    AND query_start < now() - interval '5 seconds'
ORDER BY duration DESC;
```

### Index Usage

```sql
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

### Cache Hit Ratio

```sql
SELECT
    'Index Hit Rate' as metric,
    (sum(idx_blks_hit)) / nullif(sum(idx_blks_hit + idx_blks_read),0) as ratio
FROM pg_statio_user_indexes
UNION ALL
SELECT
    'Table Hit Rate',
    sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read),0)
FROM pg_statio_user_tables;
```

## Maintenance Queries

### Vacuum Statistics

```sql
SELECT
    schemaname,
    tablename,
    last_vacuum,
    last_autovacuum,
    n_dead_tup,
    n_live_tup
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC;
```

### Table Bloat Estimation

```sql
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    n_dead_tup,
    n_live_tup,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) as dead_ratio
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC;
```

### Reindex if Needed

```sql
-- Check index bloat first, then reindex
REINDEX TABLE document;
REINDEX TABLE document_version;
REINDEX TABLE eventlog;
```

## Backup and Restore

### Export Specific Document

```bash
# Export single document and all its versions
psql -U elephant -d elephant -c "
COPY (
    SELECT uuid, version, document
    FROM document_version
    WHERE uuid = 'YOUR-UUID'
    ORDER BY version
) TO STDOUT WITH CSV HEADER
" > document-backup.csv
```

### Export All Documents of Type

```bash
psql -U elephant -d elephant -c "
COPY (
    SELECT d.uuid, d.type, d.uri, dv.version, dv.document
    FROM document d
    JOIN document_version dv ON d.uuid = dv.uuid
    WHERE d.type = 'core/article'
    ORDER BY d.uuid, dv.version
) TO STDOUT WITH CSV HEADER
" > articles-backup.csv
```

## Debugging Queries

### Find Orphaned Versions

```sql
-- Versions without parent document
SELECT DISTINCT dv.uuid
FROM document_version dv
LEFT JOIN document d ON dv.uuid = d.uuid
WHERE d.uuid IS NULL;
```

### Find Inconsistent Version Numbers

```sql
-- Documents where current_version doesn't match max version
SELECT
    d.uuid,
    d.current_version as claimed_version,
    MAX(dv.version) as actual_max_version
FROM document d
JOIN document_version dv ON d.uuid = dv.uuid
GROUP BY d.uuid, d.current_version
HAVING d.current_version != MAX(dv.version);
```

### Find Large Documents

```sql
SELECT
    d.uuid,
    d.type,
    d.uri,
    pg_size_pretty(LENGTH(dv.document::text)) as doc_size,
    dv.version
FROM document d
JOIN document_version dv ON d.uuid = dv.uuid AND d.current_version = dv.version
ORDER BY LENGTH(dv.document::text) DESC
LIMIT 20;
```

## Development Helpers

### Clear All Data (DANGEROUS - Dev Only)

```sql
-- ⚠️ WARNING: This deletes ALL data!
TRUNCATE TABLE eventlog RESTART IDENTITY CASCADE;
TRUNCATE TABLE document_status CASCADE;
TRUNCATE TABLE document_version CASCADE;
TRUNCATE TABLE document CASCADE;
TRUNCATE TABLE acl CASCADE;
```

### Insert Test Document

```sql
INSERT INTO document (uuid, type, uri, current_version, creator_uri, created, updated)
VALUES (
    gen_random_uuid()::text,
    'core/article',
    'article://test/' || gen_random_uuid()::text,
    1,
    'user://dev/test',
    now(),
    now()
);
```

## See Also

- [Database Schema](../05-infrastructure/database.md) - Database design and migrations
- [Backup Guide](../operations/backup-restore.md) - Backup and restore procedures
- [Monitoring](../08-observability/metrics.md) - Database monitoring setup
