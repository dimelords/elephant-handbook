# Elephant Documentation

This directory contains detailed technical documentation for Elephant. For quick start and overview, see the [main README](../../README.md).

## Documentation Index

### 🚀 Getting Started

Start here if you're new to Elephant:

- **[Main README](../../README.md)** - Quick start, architecture overview, and service descriptions
- **[Docker Compose Guide](../docker-compose/README.md)** - Running services with Docker
- **[Start Script](../scripts/start-elephant.sh)** - Interactive setup script

### 🔧 Configuration

Setting up schemas, workflows, and document types:

- **[Schema Workflow Guide](configuration/schema-workflow-guide.md)** - Complete schema management workflow
- **[Customer Schemas](configuration/customer-schemas.md)** - Creating custom schemas for your organization
- **[Schema Loading](configuration/schema-loading.md)** - How schemas are loaded from GitHub
- **[Eleconf Usage](configuration/eleconf-usage.md)** - Using the eleconf CLI tool

### 🧪 API Testing

Testing Elephant APIs:

- **[cURL Examples](api/curl-examples.md)** - Command-line API testing examples
- **[Postman Guide](api/postman.md)** - Using Postman collections

### 💻 Development

Local development and testing:

- **[Minikube Setup](development/minikube.md)** - Running Elephant on Kubernetes locally
- **[Database Configuration](../configs/database/README.md)** - PostgreSQL setup and password rotation

### 🔍 Operations

Running and monitoring Elephant in production:

- **[Database Queries](operations/database-queries.md)** - Useful SQL queries for operations
- **[Observability](operations/observability.md)** - Monitoring with Prometheus, Grafana, and Faro
- **[Observability Configs](../configs/observability/)** - Prometheus, Grafana, Loki, Tempo configurations

### 🏗️ Architecture

Understanding Elephant's design:

- **[System Architecture](architecture/system-architecture.md)** - Detailed architecture overview
- **[Component Map](architecture/component-map.md)** - How components interact
- **[Design Decisions](architecture/design-decisions.md)** - ADRs and architectural rationale

## Service-Specific Documentation

Each service has its own README with detailed information:

- **[elephant-repository](../../elephant-repository/README.md)** - Document storage and versioning
- **[elephant-index](../../elephant-index/README.md)** - Search indexing and percolation
- **[elephant-user](../../elephant-user/README.md)** - User events and inbox
- **[elephant-spell](../../elephant-spell/README.md)** - Spellcheck service
- **[elephant-chrome](../../elephant-chrome/README.md)** - Web UI (React)
- **[eleconf](../../eleconf/README.md)** - Configuration management tool
- **[clitools](../../clitools/README.md)** - CLI helpers library

## Configuration Files

- **[Database Init](../configs/database/)** - PostgreSQL extensions, roles, and initialization
- **[Observability](../configs/observability/)** - Prometheus, Grafana, Loki, Tempo configs
- **[OpenSearch](../configs/opensearch/)** - Custom OpenSearch with ICU plugin

## Quick Links

### Common Tasks

- **Start services**: `cd elephant-handbook/scripts && ./start-elephant.sh`
- **Configure schemas**: `cd eleconf && go run ./cmd/eleconf apply -env local -dir ../eleconf-config`
- **Start frontend**: `cd elephant-chrome && npm run dev:web`
- **View logs**: `cd elephant-handbook/docker-compose && docker compose -f docker-compose.core.yml logs -f`

### Troubleshooting

- Check service health: `docker compose -f docker-compose.core.yml ps`
- View PostgreSQL logs: `docker logs elephant-postgres-1`
- Test API: See [cURL Examples](api/curl-examples.md)
- Database issues: See [Database README](../configs/database/README.md)

## Contributing

When adding new documentation:

1. Place it in the appropriate category directory
2. Update this README with a link
3. Use clear, concise language
4. Include code examples where helpful
5. Link to related documentation

## Documentation Structure

```
docs/
├── README.md                          # This file
├── api/
│   ├── curl-examples.md              # API testing with cURL
│   └── postman.md                    # Postman collections
├── configuration/
│   ├── schema-workflow-guide.md      # Schema management
│   ├── customer-schemas.md           # Custom schemas
│   ├── schema-loading.md             # Schema loading process
│   └── eleconf-usage.md              # Eleconf CLI tool
├── development/
│   └── minikube.md                   # Kubernetes local dev
├── operations/
│   ├── database-queries.md           # Operational SQL queries
│   └── observability.md              # Monitoring setup
└── architecture/
    ├── system-architecture.md        # Architecture overview
    ├── component-map.md              # Component relationships
    └── design-decisions.md           # ADRs
```

## External Resources

- **Elephant API Specs**: See `elephant-api/docs/` for OpenAPI specifications
- **Kubernetes Manifests**: See `elephant-handbook/kubernetes/` for K8s deployment
- **Docker Compose Files**: See `elephant-handbook/docker-compose/` for local development
