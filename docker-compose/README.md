# Elephant Docker Compose Files

This directory contains modular Docker Compose files for running Elephant services.

## Files Overview

### docker-compose.core.yml
**Required core services** - Everything needed for basic Elephant functionality

**Services:**
- PostgreSQL (main database)
- PostgreSQL (Keycloak database)
- Keycloak (authentication)
- MinIO (S3 storage)
- OpenSearch (search engine)
- elephant-repository (document management)
- elephant-index (search indexing) + automatic migration init container
- elephant-user (user events)

**Migration Handling:**
- elephant-repository: Automatic via MIGRATE_DB=true
- elephant-user: Automatic via MIGRATE_DB=true
- elephant-index: Automatic via init container (runs before service starts)
  - The init container will show as "Exited" in `docker ps -a` - this is expected
  - It only runs once to set up the database, then exits successfully

**Ports:**
- 1080 - elephant-repository
- 1082 - elephant-index
- 1083 - elephant-user
- 5432 - PostgreSQL
- 5433 - Keycloak PostgreSQL
- 8080 - Keycloak
- 9000 - MinIO API
- 9001 - MinIO Console
- 9200 - OpenSearch

**Resources:** ~4-6 GB RAM

**Note:** All services can be started together with `docker compose -f docker-compose.core.yml up -d`

---

### docker-compose.spell.yml
**Optional spellcheck service**

**Services:**
- elephant-spell (hunspell-based spellcheck)

**Ports:**
- 1084 - elephant-spell

**When to use:**
- Editorial workflows requiring spellcheck
- Custom dictionary management
- Multi-language spell checking

**Resources:** ~200-300 MB RAM

---

### docker-compose.observability.yml
**Optional monitoring stack**

**Services:**
- Prometheus (metrics collection)
- Grafana (dashboards)

**Ports:**
- 9090 - Prometheus
- 3000 - Grafana

**When to use:**
- Production-like monitoring
- Performance analysis
- Debugging performance issues

**Resources:** ~2-3 GB RAM

**Note:** Requires configuration files in `../../prometheus/` and `../../grafana/`


## Usage

### Quick Start (Interactive)

The easiest way to start Elephant:

```bash
cd elephant-handbook/scripts
./start-elephant.sh
```

This script will:
1. Start core services automatically
2. Configure Keycloak
3. Run database migrations
4. Ask if you want spell service
5. Ask if you want observability stack

---

### Manual Start (Core Only)

Start just the core services:

```bash
cd elephant-handbook/docker-compose

# Start core services (all migrations run automatically)
docker compose -f docker-compose.core.yml up -d

# Wait for Keycloak (60-90 seconds)
sleep 60

# Configure Keycloak
cd ../scripts
./setup-keycloak-fixed.sh

# Clean up init containers (optional but recommended)
docker rm elephant-index-migrate-1 elephant-user-migrate-1 elephant-minio-init-1 2>/dev/null || true

# Check status
cd ../docker-compose
docker compose -f docker-compose.core.yml ps
```

**Note:** Migrations for all services run automatically:
- elephant-repository and elephant-user use MIGRATE_DB=true
- elephant-index uses an init container that runs before the service starts
- Init containers (elephant-index-migrate, minio-init) can be removed after startup

---

### Add Optional Services

After core services are running, add optional services:

```bash
cd elephant-handbook/docker-compose

# Add spell service
docker compose -f docker-compose.spell.yml up -d

# Add observability
docker compose -f docker-compose.observability.yml up -d
```

---

### Stop Services

Stop services individually:

```bash
cd elephant-handbook/docker-compose

# Stop core services (keeps data)
docker compose -f docker-compose.core.yml stop

# Stop spell service
docker compose -f docker-compose.spell.yml stop

# Stop observability
docker compose -f docker-compose.observability.yml stop
```

Remove containers (keeps data):

```bash
docker compose -f docker-compose.core.yml down
docker compose -f docker-compose.spell.yml down
docker compose -f docker-compose.observability.yml down
```

Remove everything including data:

```bash
docker compose -f docker-compose.core.yml down -v
docker compose -f docker-compose.spell.yml down -v
docker compose -f docker-compose.observability.yml down -v
```

---

### View Logs

```bash
cd elephant-handbook/docker-compose

# All core services
docker compose -f docker-compose.core.yml logs -f

# Specific service
docker compose -f docker-compose.core.yml logs -f repository

# Spell service
docker compose -f docker-compose.spell.yml logs -f spell

# Observability
docker compose -f docker-compose.observability.yml logs -f prometheus
```

---

### Restart a Service

```bash
cd elephant-handbook/docker-compose

# Restart repository
docker compose -f docker-compose.core.yml restart repository

# Rebuild and restart
docker compose -f docker-compose.core.yml up -d --build repository
```

---

## Network Configuration

All services use the `elephant-net` network:

- **Core services** create the network
- **Optional services** connect to the existing network

This allows optional services to communicate with core services.

**Network name:** `elephant-net`

---

## Volume Management

### Core Volumes
- `postgres_data` - Main PostgreSQL database
- `keycloak_postgres_data` - Keycloak database
- `minio_data` - S3 object storage
- `opensearch_data` - Search indexes

### Observability Volumes
- `prometheus_data` - Metrics time-series data
- `grafana_data` - Dashboards and settings

### List Volumes

```bash
docker volume ls | grep elephant
```

### Backup a Volume

```bash
# Backup PostgreSQL data
docker run --rm \
  -v elephant_postgres_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/postgres-backup.tar.gz /data
```

### Remove All Volumes

```bash
docker volume rm elephant_postgres_data
docker volume rm elephant_keycloak_postgres_data
docker volume rm elephant_minio_data
docker volume rm elephant_opensearch_data
docker volume rm elephant_prometheus_data
docker volume rm elephant_grafana_data
docker volume rm elephant_loki_data
docker volume rm elephant_tempo_data
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check Docker is running
docker info

# Check for port conflicts
lsof -i :8080  # Keycloak
lsof -i :1080  # Repository
lsof -i :5432  # PostgreSQL

# View detailed logs
docker compose -f docker-compose.core.yml logs repository
```

### Network Issues

If optional services can't connect to core services:

```bash
# Check network exists
docker network ls | grep elephant

# Recreate network
docker network rm elephant-net
docker compose -f docker-compose.core.yml up -d
```

### Clean Slate

Remove everything and start fresh:

```bash
cd elephant-handbook/docker-compose

# Stop and remove all
docker compose -f docker-compose.core.yml down -v
docker compose -f docker-compose.spell.yml down -v
docker compose -f docker-compose.observability.yml down -v

# Remove network
docker network rm elephant-net

# Optional: Remove init containers
docker rm elephant-index-migrate-1 elephant-user-migrate-1 elephant-minio-init-1

# Start fresh
cd ../scripts
./start-elephant.sh
```

### Remove Init Containers

The init containers (`elephant-index-migrate-1`, `elephant-user-migrate-1`, `elephant-minio-init-1`) run once and exit. They're harmless to leave, but if you want to remove them:

```bash
# Remove the exited init containers
docker rm elephant-index-migrate-1 elephant-user-migrate-1 elephant-minio-init-1

# Or remove all exited containers
docker container prune
```

**Note:** The init containers will be recreated next time you run `docker compose up`, which is fine - they're idempotent (safe to run multiple times).

---

## Resource Requirements

### Minimal Setup (Core Only)
- RAM: 4-6 GB
- Disk: 2-3 GB
- CPU: 2+ cores

### With Spell
- RAM: 5-7 GB
- Disk: 2-3 GB
- CPU: 2+ cores

### Full Stack (Core + Spell + Observability)
- RAM: 8-10 GB
- Disk: 5-7 GB
- CPU: 4+ cores

---

## See Also

- [Fresh Start Guide](../docs/FRESH-START-GUIDE.md) - Complete setup instructions
- [Services Overview](../docs/SERVICES-OVERVIEW.md) - All services explained
- [Keycloak Setup Fixes](../docs/KEYCLOAK-SETUP-FIXES.md) - Authentication configuration
