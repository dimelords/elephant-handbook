#!/bin/bash
# PostgreSQL Query Examples for Elephant Local Development
# Run these commands from the elephant-local directory

echo "=== Elephant PostgreSQL Query Examples ==="
echo ""

# Connection string
PSQL="docker compose exec -T postgres psql -U elephant -d elephant"

echo "1. List all tables:"
echo "-------------------"
$PSQL -c "\dt"
echo ""

echo "2. Count documents by type:"
echo "---------------------------"
$PSQL -c "
SELECT
    type,
    COUNT(*) as count,
    COUNT(DISTINCT uuid) as unique_documents
FROM document
GROUP BY type
ORDER BY count DESC;
"
echo ""

echo "3. List recent documents (last 10):"
echo "-----------------------------------"
$PSQL -c "
SELECT
    uuid,
    type,
    uri,
    current_version,
    created,
    updated
FROM document
ORDER BY created DESC
LIMIT 10;
"
echo ""

echo "4. Find all authors:"
echo "--------------------"
$PSQL -c "
SELECT
    uuid,
    uri,
    creator_uri,
    created,
    current_version
FROM document
WHERE type = 'core/author'
ORDER BY created DESC;
"
echo ""

echo "5. Get document versions history:"
echo "----------------------------------"
echo "Usage: Replace UUID with actual document UUID"
echo '$PSQL -c "SELECT version, created, creator FROM document_version WHERE uuid = '\''YOUR-UUID-HERE'\'' ORDER BY version DESC LIMIT 5;"'
echo ""

echo "6. Count documents by status:"
echo "-----------------------------"
$PSQL -c "
SELECT
    ds.status,
    COUNT(*) as count
FROM document_status ds
JOIN document d ON ds.uuid = d.uuid
GROUP BY ds.status
ORDER BY count DESC;
"
echo ""

echo "7. Check eventlog (last 20 events):"
echo "------------------------------------"
$PSQL -c "
SELECT
    id,
    event,
    type,
    uuid,
    timestamp,
    updater
FROM eventlog
ORDER BY id DESC
LIMIT 20;
"
echo ""

echo "8. Find documents by URI (case insensitive):"
echo "-----------------------------------------------"
echo "Usage: Replace SEARCH_TERM with your search term"
echo '$PSQL -c "SELECT uuid, type, uri, created FROM document WHERE uri ILIKE '\''%SEARCH_TERM%'\'' ORDER BY created DESC LIMIT 10;"'
echo ""

echo "9. Get ACL (Access Control List) entries:"
echo "------------------------------------------"
$PSQL -c "
SELECT
    uuid,
    uri,
    permissions
FROM acl
LIMIT 10;
"
echo ""

echo "10. Database statistics:"
echo "------------------------"
$PSQL -c "
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
"
echo ""

echo "=== Custom Query Template ==="
echo "Run custom queries with:"
echo 'docker compose exec -T postgres psql -U elephant -d elephant -c "YOUR SQL HERE"'
echo ""

echo "=== Interactive psql Session ==="
echo "For interactive queries, run:"
echo "docker compose exec postgres psql -U elephant -d elephant"
