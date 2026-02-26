# Elephant Handbook

> Comprehensive operations, deployment, and development guide for the Elephant document repository system

**Organization**: Dimelords
**Upstream**: [TT/Naviga](https://github.com/ttab)
**Tagline**: The doc of fate

## What is Elephant?

Elephant is a document repository system designed for editorial content management, using the NewsDoc format (originated from Naviga's NavigaDoc). It provides:

- **Version Control**: Full history tracking for all document changes
- **Access Control**: Fine-grained ACLs for documents and operations
- **Schema Validation**: Flexible content validation with Revisor
- **Search**: Full-text search with OpenSearch
- **Archiving**: S3-based archiving with cryptographic signatures
- **Collaboration**: Real-time collaborative editing with Y.js CRDTs
- **Event Streaming**: Event log for real-time integrations

## Quick Start

### For Developers

```bash
# Clone this repository
git clone https://github.com/dimelords/elephant-handbook
cd elephant-handbook

# Start all services with interactive script
./scripts/start-elephant.sh
```

This script will:
- Start core services (PostgreSQL, Keycloak, MinIO, OpenSearch, Elephant services)
- Optionally start spell service
- Optionally start observability stack (Prometheus, Grafana, Loki, Tempo)
- Show service URLs and credentials

### For Operators

- [Production Deployment Overview](docs/04-deployment/production-overview.md)
- [Kubernetes Setup](docs/04-deployment/kubernetes/setup.md)
- [Docker Compose Production](docs/04-deployment/docker-compose-prod.md)

## Documentation Structure

### 📚 01. Overview
- [System Architecture](docs/01-overview/system-architecture.md) - High-level architecture and component interaction
- [Component Map](docs/01-overview/component-map.md) - All services, libraries, and their roles
- [Dependencies](docs/01-overview/dependencies.md) - Dependency graph and version requirements

### 🔧 02. Components
- [elephant-repository](docs/02-components/elephant-repository.md) - Core document storage with versioning and ACLs
- [elephant-index](docs/02-components/elephant-index.md) - Search indexing following the event log
- [elephant-user](docs/02-components/elephant-user.md) - User events and inbox messages
- [elephant-chrome](docs/02-components/elephant-chrome.md) - React frontend application
- [textbit](docs/02-components/textbit.md) - Rich text editor with collaborative editing
- [revisor](docs/02-components/revisor.md) - Schema validation engine
- [newsdoc](docs/02-components/newsdoc.md) - Editorial document format
- [elephantine](docs/02-components/elephantine.md) - Shared Go libraries

### 💻 03. Development
- [Local Setup](docs/03-development/local-setup.md) - Getting started for developers
- [Docker Compose](docs/03-development/docker-compose.md) - Running with Docker Compose
- [Minikube](docs/03-development/minikube.md) - Local Kubernetes development
- [Hot Reload](docs/03-development/hot-reload.md) - Development workflow tips
- [Testing](docs/03-development/testing.md) - Running tests locally

### 🚀 04. Deployment
- [Production Overview](docs/04-deployment/production-overview.md) - Production architecture patterns
- **Kubernetes**
  - [Setup](docs/04-deployment/kubernetes/setup.md) - k8s deployment guide
  - [Helm Charts](docs/04-deployment/kubernetes/helm-charts.md) - Helm configuration
  - [Ingress](docs/04-deployment/kubernetes/ingress.md) - Ingress and routing
  - [Scaling](docs/04-deployment/kubernetes/scaling.md) - Horizontal and vertical scaling
- [Docker Compose Production](docs/04-deployment/docker-compose-prod.md) - Simple production deployment
- **Terraform**
  - [AWS](docs/04-deployment/terraform/aws.md) - AWS infrastructure as code
  - [GCP](docs/04-deployment/terraform/gcp.md) - GCP infrastructure (if applicable)
  - [Modules](docs/04-deployment/terraform/modules.md) - Reusable Terraform modules

### 🏗️ 05. Infrastructure
- [PostgreSQL](docs/05-infrastructure/postgresql.md) - Database setup, migrations, and replication
- [OpenSearch](docs/05-infrastructure/opensearch.md) - Search infrastructure setup
- [MinIO/S3](docs/05-infrastructure/minio-s3.md) - Object storage configuration
- [Redis](docs/05-infrastructure/redis.md) - Caching layer (if used)
- [Networking](docs/05-infrastructure/networking.md) - Network architecture and security

### 🔐 06. Authentication & API Testing
- [OIDC Setup](docs/06-authentication/oidc-setup.md) - OpenID Connect configuration
- [Keycloak](docs/06-authentication/keycloak.md) - Keycloak integration guide
- [Auth0](docs/06-authentication/auth0.md) - Auth0 integration guide
- [JWT Claims](docs/06-authentication/jwt-claims.md) - Required JWT structure and claims
- [Mock Auth](docs/06-authentication/mock-auth.md) - Development mock authentication
- **API Testing**
  - [Postman Guide](docs/06-api-testing/postman.md) - Testing APIs with Postman collections
  - [cURL Examples](docs/06-api-testing/curl-examples.md) - Command-line API testing

### ⚙️ 07. Configuration
- [Database Initialization](docs/07-configuration/database-init.md) - Initial database configuration and seeding
- [Environment Variables](docs/07-configuration/environment-variables.md) - All environment variables documented
- [Secrets Management](docs/07-configuration/secrets-management.md) - Handling secrets in production
- [Feature Flags](docs/07-configuration/feature-flags.md) - Feature flag system

### 📊 08. Observability
- [Overview](docs/08-observability/overview.md) - Observability strategy and tools
- [Prometheus](docs/08-observability/prometheus.md) - Metrics collection and configuration
- [Grafana](docs/08-observability/grafana.md) - Dashboards and visualization
- [Faro](docs/08-observability/faro.md) - Frontend observability and RUM
- [Logging](docs/08-observability/logging.md) - Centralized logging strategy
- [Alerting](docs/08-observability/alerting.md) - Alert configuration and runbooks

### 🔨 09. Operations
- [Backup & Restore](docs/09-operations/backup-restore.md) - Backup procedures and disaster recovery
- [Database Queries](docs/09-operations/database-queries.md) - PostgreSQL query reference for debugging and monitoring
- [Disaster Recovery](docs/09-operations/disaster-recovery.md) - DR plan and procedures
- [Upgrades](docs/09-operations/upgrades.md) - Safe upgrade procedures
- [Troubleshooting](docs/09-operations/troubleshooting.md) - Common issues and solutions
- [Performance Tuning](docs/09-operations/performance-tuning.md) - Performance optimization guide

### 🎨 10. Customization
- [Custom Frontend](docs/10-customization/custom-frontend.md) - Building your own frontend instead of elephant-chrome
- [Custom NewsDoc](docs/10-customization/custom-newsdoc.md) - Creating your own NewsDoc format
- [Custom Schemas](docs/10-customization/custom-schemas.md) - Revisor schema customization
- [Custom Plugins](docs/10-customization/custom-plugins.md) - Textbit editor plugins
- [Branding](docs/10-customization/branding.md) - UI customization and white-labeling

### 🏗️ 12. Architecture (Advanced)
- [Design Decisions](docs/12-architecture/design-decisions.md) - Why messages vs CDC, architectural choices and rationale

## Repository Organization

### Elephant Repositories (Dimelords Forks)

**Backend Services**
- [elephant-repository](https://github.com/dimelords/elephant-repository) - Core document repository
- [elephant-index](https://github.com/dimelords/elephant-index) - Search indexing service
- [elephant-user](https://github.com/dimelords/elephant-user) - User events and inbox

**Frontend**
- [elephant-chrome](https://github.com/dimelords/elephant-chrome) - Main React application
- [elephant-ui](https://github.com/dimelords/elephant-ui) - Shared UI components
- [textbit](https://github.com/dimelords/textbit) - Rich text editor
- [textbit-plugins](https://github.com/dimelords/textbit-plugins) - Editor plugins

**APIs and Libraries**
- [elephant-api](https://github.com/dimelords/elephant-api) - Protobuf API definitions
- [elephant-api-npm](https://github.com/dimelords/elephant-api-npm) - TypeScript API client
- [elephantine](https://github.com/dimelords/elephantine) - Shared Go libraries
- [newsdoc](https://github.com/dimelords/newsdoc) - Document format library
- [revisor](https://github.com/dimelords/revisor) - Schema validation
- [revisorschemas](https://github.com/dimelords/revisorschemas) - Content schemas
- [media-client](https://github.com/dimelords/media-client) - Media handling

**Upstream (TT/Naviga)**
- Many repositories have corresponding upstream at `https://github.com/ttab/*`

## Useful Scripts

All scripts are in the `scripts/` directory:

- `start-elephant.sh` - Interactive script to start all services with Docker Compose
- `setup-keycloak-fixed.sh` - Configure Keycloak realm and clients (called by start-elephant.sh)

Additional scripts can be added for:
- Cloning all Elephant repositories
- Syncing forks with upstream TT repositories
- Deploying to Kubernetes
- Backing up databases and storage

## Infrastructure as Code

### Terraform
Pre-configured Terraform modules for:
- AWS (S3, RDS PostgreSQL, OpenSearch, VPC)
- GCP (Cloud Storage, Cloud SQL, networking)
- Shared modules for common patterns

### Kubernetes
Customize-based manifests with overlays for:
- Development
- Staging
- Production

Helm chart available at `kubernetes/helm/elephant/`

### Docker Compose
Multiple compose files for different scenarios:
- `docker-compose.dev.yml` - Full development stack
- `docker-compose.prod.yml` - Production-like deployment
- `docker-compose.minimal.yml` - Minimal services for testing

## Design Philosophy

### Why Elephant Uses Its Own Message Log

Elephant implements its own event log rather than relying on Change Data Capture (CDC) for several reasons:

1. **Explicit Events**: Business events are explicitly defined in the application layer
2. **Event Enrichment**: Events contain domain context, not just database changes
3. **Schema Evolution**: Event structure can evolve independently of database schema
4. **Ordering Guarantees**: Sequential numbering provides strong ordering
5. **Replay Capability**: Full system state can be reconstructed from event log

See [Design Decisions](docs/01-overview/design-decisions.md) for more details.

### Key Architectural Patterns

- **Event Sourcing**: All changes captured as immutable events
- **CQRS**: Separate read (index) and write (repository) models
- **Document Versioning**: Full history preservation with cryptographic signing
- **Multi-tenancy**: Unit-based access control and data isolation

## Technology Stack

**Backend**
- Go 1.23
- PostgreSQL 16
- Twirp (RPC framework)
- SQLC (type-safe SQL)
- Tern (migrations)

**Frontend**
- React 18
- TypeScript
- Vite
- Y.js (CRDT for collaboration)

**Infrastructure**
- Kubernetes / Docker
- OpenSearch / Elasticsearch
- MinIO / AWS S3
- Prometheus + Grafana
- Grafana Faro (frontend observability)

## Contributing

This handbook is maintained by Dimelords for our Elephant deployment. Contributions are welcome:

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This handbook is licensed under MIT. The Elephant system components maintain their original licenses from TT/Naviga.

## Support

- **Issues**: [GitHub Issues](https://github.com/dimelords/elephant-handbook/issues)
- **Discussions**: [GitHub Discussions](https://github.com/dimelords/elephant-handbook/discussions)
- **Upstream**: [TT Elephant Repositories](https://github.com/ttab)

## Version History

- **v1.0.0** (2026-02-14) - Initial release with comprehensive documentation structure
