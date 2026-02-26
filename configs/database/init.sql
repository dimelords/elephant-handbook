-- Elephant Database Initialization
-- This script sets up initial database configuration for development/testing
-- Runs BEFORE migrations, so only creates extensions and roles
-- Tables and views are created by service migrations

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

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

-- Grant basic privileges
GRANT CONNECT ON DATABASE elephant TO elephant_app;
GRANT CONNECT ON DATABASE elephant TO elephant_reporting;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO elephant_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO elephant_reporting;

-- Grant monitoring privileges
GRANT pg_monitor TO elephant_reporting;

-- Comments
COMMENT ON DATABASE elephant IS 'Elephant document repository - development database';
COMMENT ON ROLE elephant_app IS 'Application user for Elephant services';
COMMENT ON ROLE elephant_reporting IS 'Read-only user for reporting and analytics';

-- Setup complete
DO $$
BEGIN
    RAISE NOTICE 'Elephant database initialization complete';
    RAISE NOTICE 'Extensions created: uuid-ossp, pgcrypto, pg_stat_statements';
    RAISE NOTICE 'Application user: elephant_app';
    RAISE NOTICE 'Reporting user: elephant_reporting';
    RAISE NOTICE 'Remember to change passwords in production!';
    RAISE NOTICE 'Tables will be created by service migrations';
END
$$;
