-- Elephant Database Initialization
-- This script sets up initial database configuration for development/testing
-- For production, migrations are handled by the repository service

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create database users (if they don't exist)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'elephant_app') THEN
        CREATE ROLE elephant_app WITH LOGIN PASSWORD 'change-me-in-production';
    END IF;

    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'elephant_reporting') THEN
        CREATE ROLE elephant_reporting WITH LOGIN PASSWORD 'change-me-in-production';
    END IF;
END
$$;

-- Grant privileges
GRANT CONNECT ON DATABASE elephant TO elephant_app;
GRANT CONNECT ON DATABASE elephant TO elephant_reporting;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO elephant_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO elephant_reporting;

-- Create initial organizations/units for development
-- Note: In production, these are typically loaded from configuration

-- Example: Create a development unit
INSERT INTO units (uuid, name, created, updated)
VALUES
    (gen_random_uuid(), 'Development Unit', NOW(), NOW())
ON CONFLICT DO NOTHING;

-- Example: Create development user claims
-- Note: Actual users come from your identity provider (OIDC)
-- This is just metadata for development

COMMENT ON DATABASE elephant IS 'Elephant document repository - development database';

-- Create reporting views (read-only for reporting user)

-- Document statistics view
CREATE OR REPLACE VIEW document_stats AS
SELECT
    d.type,
    d.status,
    COUNT(*) as document_count,
    COUNT(DISTINCT d.uuid) as unique_documents,
    MAX(d.version) as max_version,
    DATE(d.created) as creation_date
FROM documents d
GROUP BY d.type, d.status, DATE(d.created);

GRANT SELECT ON document_stats TO elephant_reporting;

-- Event log statistics view
CREATE OR REPLACE VIEW event_stats AS
SELECT
    event_type,
    COUNT(*) as event_count,
    DATE(created) as event_date
FROM events
GROUP BY event_type, DATE(created);

GRANT SELECT ON event_stats TO elephant_reporting;

-- User activity view
CREATE OR REPLACE VIEW user_activity AS
SELECT
    creator as user_id,
    COUNT(*) as action_count,
    MAX(created) as last_activity,
    DATE(created) as activity_date
FROM documents
GROUP BY creator, DATE(created);

GRANT SELECT ON user_activity TO elephant_reporting;

-- Performance monitoring
CREATE OR REPLACE VIEW slow_queries AS
SELECT
    query,
    calls,
    total_time,
    mean_time,
    max_time
FROM pg_stat_statements
WHERE mean_time > 100  -- queries slower than 100ms
ORDER BY mean_time DESC
LIMIT 50;

-- Enable pg_stat_statements if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Grant monitoring privileges
GRANT pg_monitor TO elephant_reporting;

-- Setup for logical replication (optional, for read replicas)
-- ALTER SYSTEM SET wal_level = logical;
-- ALTER SYSTEM SET max_replication_slots = 4;
-- ALTER SYSTEM SET max_wal_senders = 4;

-- Note: Requires PostgreSQL restart after these changes
-- SELECT pg_reload_conf(); -- or restart PostgreSQL

-- Create publication for logical replication (if needed)
-- CREATE PUBLICATION elephant_pub FOR ALL TABLES;

-- Create replication slot for reporting
-- SELECT pg_create_logical_replication_slot('elephant_reporting_slot', 'pgoutput');

COMMENT ON ROLE elephant_app IS 'Application user for Elephant services';
COMMENT ON ROLE elephant_reporting IS 'Read-only user for reporting and analytics';

-- Indexes for common queries (examples)
-- Note: Actual indexes are created by migrations in elephant-repository

-- Example: Create index on document type and status
-- CREATE INDEX IF NOT EXISTS idx_documents_type_status ON documents(type, status);

-- Example: Create index on event log for sequential reading
-- CREATE INDEX IF NOT EXISTS idx_events_id ON events(id);

-- Example: Create index on created timestamp for time-based queries
-- CREATE INDEX IF NOT EXISTS idx_documents_created ON documents(created);

-- Setup complete
DO $$
BEGIN
    RAISE NOTICE 'Elephant database initialization complete';
    RAISE NOTICE 'Application user: elephant_app';
    RAISE NOTICE 'Reporting user: elephant_reporting';
    RAISE NOTICE 'Remember to change passwords in production!';
END
$$;
