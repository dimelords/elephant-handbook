-- Extra databases for services that don't use the default "elephant" database.
-- Runs once, when the postgres volume is first initialised (docker-entrypoint-initdb.d).
-- The schema inside each database is applied by that service's *-migrate init
-- container (tern); this file only makes sure the database exists.

-- elephant-user (see user-migrate in docker-compose.core.yml)
SELECT 'CREATE DATABASE elephant_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'elephant_user')\gexec
