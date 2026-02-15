# Running Elephant with Docker Compose

Docker Compose provides the quickest way to run Elephant locally for development. All services run in containers with networking and volumes managed automatically.

## Quick Start

### 1. Prerequisites

```bash
# Install Docker Desktop (includes Docker Compose)
# macOS: https://docs.docker.com/desktop/install/mac-install/
# Linux: https://docs.docker.com/desktop/install/linux-install/
# Windows: https://docs.docker.com/desktop/install/windows-install/

# Verify installation
docker --version
docker compose version
```

### 2. Start All Services

```bash
# Clone elephant-handbook
git clone https://github.com/dimelords/elephant-handbook
cd elephant-handbook/docker-compose

# Start infrastructure services
docker compose -f docker-compose.dev.yml up -d postgres minio opensearch

# Wait for services to be ready (30 seconds)
sleep 30

# Run database migrations (if using real services, not just Docker Compose)
# This would typically be done by elephant-repository on startup

# Start application services
docker compose -f docker-compose.dev.yml up -d repository index user

# View logs
docker compose -f docker-compose.dev.yml logs -f
```

### 3. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Repository API | http://localhost:1080 | N/A |
| Index API | http://localhost:1081 | N/A |
| User API | http://localhost:1082 | N/A |
| PostgreSQL | localhost:5432 | postgres/postgres |
| MinIO Console | http://localhost:9001 | minioadmin/minioadmin |
| MinIO API | http://localhost:9000 | minioadmin/minioadmin |
| OpenSearch | http://localhost:9200 | No auth |

### 4. Test the API

```bash
# Health check
curl http://localhost:1080/healthz

# Get mock token
curl -X POST http://localhost:1080/token \
  -d grant_type=password \
  -d 'username=Dev User <user://dev/user1, unit://dev/unit1>' \
  -d 'scope=doc_read doc_write doc_delete'

# Save token
export TOKEN="<access_token_from_response>"

# Create a document
curl -X POST http://localhost:1080/twirp/elephant.repository.Documents/Create \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "document": {
      "type": "core/article",
      "title": "Test Article",
      "content": []
    }
  }'
```

## Configuration

### Environment Variables

Edit `.env` file in the docker-compose directory:

```bash
# PostgreSQL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=elephant

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
S3_BUCKET=elephant-archive

# OpenSearch
OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m

# Application
LOG_LEVEL=debug
```

### Volume Persistence

Data is persisted in Docker volumes:

```bash
# List volumes
docker volume ls | grep elephant

# Inspect volume
docker volume inspect elephant-postgres-data

# Backup volume
docker run --rm -v elephant-postgres-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/postgres-backup.tar.gz /data
```

## Development Workflow

### 1. Running Frontend Locally

The frontend should run outside Docker for hot reloading:

```bash
# Clone elephant-chrome
git clone https://github.com/dimelords/elephant-chrome
cd elephant-chrome

# Install dependencies
npm install

# Create .env
cat > .env << 'EOF'
VITE_REPOSITORY_URL=http://localhost:1080
VITE_DEV_SERVER_PORT=5173
VITE_HMR_PORT=6000
EOF

# Start dev servers (in separate terminals)
npm run dev:web   # Terminal 1
npm run dev:css   # Terminal 2

# Access at http://localhost:5173
```

### 2. Rebuilding Backend Services

If you make changes to backend code:

```bash
# Rebuild specific service
docker compose -f docker-compose.dev.yml build repository

# Restart service
docker compose -f docker-compose.dev.yml up -d repository

# Follow logs
docker compose -f docker-compose.dev.yml logs -f repository
```

### 3. Using Local Code

Mount your local code into containers:

```yaml
# docker-compose.override.yml
services:
  repository:
    build:
      context: ../../elephant-repository
      dockerfile: Dockerfile
    volumes:
      - ../../elephant-repository:/app
    command: |
      sh -c "go build -o elephant-repository ./cmd/elephant-repository && ./elephant-repository"
```

```bash
# Create override file
docker compose -f docker-compose.dev.yml -f docker-compose.override.yml up -d
```

## Debugging

### View Logs

```bash
# All services
docker compose -f docker-compose.dev.yml logs -f

# Specific service
docker compose -f docker-compose.dev.yml logs -f repository

# Last 100 lines
docker compose -f docker-compose.dev.yml logs --tail=100 repository

# Since specific time
docker compose -f docker-compose.dev.yml logs --since 10m repository
```

### Exec into Container

```bash
# Repository service
docker compose -f docker-compose.dev.yml exec repository sh

# PostgreSQL
docker compose -f docker-compose.dev.yml exec postgres psql -U postgres -d elephant

# Check environment variables
docker compose -f docker-compose.dev.yml exec repository env
```

### Inspect Networks

```bash
# List networks
docker network ls | grep elephant

# Inspect network
docker network inspect elephant-compose_elephant-net

# Test connectivity
docker compose -f docker-compose.dev.yml exec repository ping postgres
```

### Database Operations

```bash
# Connect to PostgreSQL
docker compose -f docker-compose.dev.yml exec postgres psql -U postgres -d elephant

# Run SQL file
docker compose -f docker-compose.dev.yml exec -T postgres psql -U postgres -d elephant < schema.sql

# Create backup
docker compose -f docker-compose.dev.yml exec postgres pg_dump -U postgres elephant > backup.sql

# Restore backup
docker compose -f docker-compose.dev.yml exec -T postgres psql -U postgres elephant < backup.sql
```

### MinIO Operations

```bash
# Access MinIO console
open http://localhost:9001

# Or use mc (MinIO client)
docker run --rm --network elephant-compose_elephant-net \
  minio/mc alias set myminio http://minio:9000 minioadmin minioadmin

# List buckets
docker run --rm --network elephant-compose_elephant-net \
  minio/mc ls myminio

# Create bucket
docker run --rm --network elephant-compose_elephant-net \
  minio/mc mb myminio/elephant-archive
```

## Performance Optimization

### Resource Limits

Edit docker-compose.dev.yml to adjust resources:

```yaml
services:
  repository:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### Reduce OpenSearch Memory

For development with limited RAM:

```yaml
opensearch:
  environment:
    - "OPENSEARCH_JAVA_OPTS=-Xms256m -Xmx256m"
```

### Use BuildKit

Enable Docker BuildKit for faster builds:

```bash
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

docker compose build
```

## Common Issues

### Port Already in Use

```bash
# Find process using port
lsof -i :1080

# Kill process
kill -9 <PID>

# Or change port in docker-compose.yml
ports:
  - "11080:1080"  # Use different host port
```

### Container Won't Start

```bash
# Check container status
docker compose -f docker-compose.dev.yml ps

# View container logs
docker compose -f docker-compose.dev.yml logs repository

# Restart container
docker compose -f docker-compose.dev.yml restart repository

# Remove and recreate
docker compose -f docker-compose.dev.yml up -d --force-recreate repository
```

### Database Connection Issues

```bash
# Check if PostgreSQL is ready
docker compose -f docker-compose.dev.yml exec postgres pg_isready

# Check connection string
docker compose -f docker-compose.dev.yml exec repository env | grep CONN_STRING

# Test connection from repository container
docker compose -f docker-compose.dev.yml exec repository \
  psql "postgres://postgres:postgres@postgres:5432/elephant?sslmode=disable"
```

### Volume Permission Issues

```bash
# Fix volume permissions
docker compose -f docker-compose.dev.yml down -v
docker volume prune -f
docker compose -f docker-compose.dev.yml up -d
```

## Multiple Environments

### Development Environment

```bash
# docker-compose.dev.yml (already exists)
docker compose -f docker-compose.dev.yml up -d
```

### Testing Environment

```yaml
# docker-compose.test.yml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: elephant_test
    tmpfs:
      - /var/lib/postgresql/data  # Use tmpfs for speed

  repository:
    environment:
      - LOG_LEVEL=warn
      - CONN_STRING=postgres://postgres:postgres@postgres:5432/elephant_test
```

```bash
docker compose -f docker-compose.test.yml up -d
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test with Docker Compose

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Start services
        run: |
          cd docker-compose
          docker compose -f docker-compose.dev.yml up -d
          sleep 30

      - name: Run tests
        run: |
          curl -f http://localhost:1080/healthz || exit 1

      - name: Cleanup
        if: always()
        run: |
          cd docker-compose
          docker compose -f docker-compose.dev.yml down -v
```

## Cleanup

### Stop Services

```bash
# Stop (keeps volumes)
docker compose -f docker-compose.dev.yml stop

# Stop and remove containers
docker compose -f docker-compose.dev.yml down

# Stop, remove containers and volumes (deletes data!)
docker compose -f docker-compose.dev.yml down -v

# Stop, remove everything including images
docker compose -f docker-compose.dev.yml down -v --rmi all
```

### Clean Up Docker

```bash
# Remove all stopped containers
docker container prune -f

# Remove unused volumes
docker volume prune -f

# Remove unused networks
docker network prune -f

# Remove unused images
docker image prune -a -f

# Nuclear option: clean everything
docker system prune -a --volumes -f
```

## Production Considerations

### Don't Use docker-compose.dev.yml in Production

The dev compose file is for development only. For production:

1. Use Kubernetes (see [Kubernetes Guide](../../kubernetes/README.md))
2. Or create a production compose file with:
   - No host port bindings
   - Production-grade secrets management
   - Resource limits
   - Health checks
   - Restart policies
   - External volumes
   - Proper logging

Example production compose structure:

```yaml
# docker-compose.prod.yml
services:
  repository:
    image: ghcr.io/dimelords/elephant-repository:v1.2.3
    restart: always
    secrets:
      - db_password
      - s3_credentials
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G

secrets:
  db_password:
    external: true
  s3_credentials:
    external: true
```

## Comparison with Other Methods

| Feature | Docker Compose | Minikube | Direct (Mage) |
|---------|----------------|----------|---------------|
| **Setup Time** | Fast (~2 min) | Medium (~5 min) | Very Fast (~30 sec) |
| **Resource Usage** | Medium (2-3 GB) | High (4-6 GB) | Low (< 1 GB) |
| **Complexity** | Low | Medium | Low |
| **Production Similarity** | Low | High | Low |
| **Best For** | Quick dev, testing | K8s development | Active development |
| **Hot Reload** | Manual rebuild | Manual rebuild | Built-in (Go) |

## Best Practices

1. **Use .env files**: Never commit secrets
2. **Volume mounts**: Mount code for development, not in production
3. **Health checks**: Add health checks for dependent services
4. **Separate networks**: Use networks to isolate service groups
5. **Named volumes**: Use named volumes for important data
6. **Logging**: Configure appropriate log drivers
7. **Resource limits**: Set limits to avoid consuming all host resources

## Further Reading

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Compose File Reference](https://docs.docker.com/compose/compose-file/)
- [Minikube Development](minikube.md)
- [Local Setup Guide](local-setup.md)
