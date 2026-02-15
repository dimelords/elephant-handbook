# System Architecture

## Overview

Elephant is a distributed document repository system built with event sourcing, CQRS, and microservices principles. The system consists of backend services written in Go, a React frontend, and supporting infrastructure.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client Layer                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐          ┌─────────────────┐            │
│  │ elephant-chrome  │          │  Mobile Apps    │            │
│  │  (React + Vite)  │          │   (Future)      │            │
│  └────────┬─────────┘          └────────┬────────┘            │
│           │                              │                      │
└───────────┼──────────────────────────────┼──────────────────────┘
            │                              │
            │          HTTPS/Twirp         │
            │                              │
┌───────────┴──────────────────────────────┴──────────────────────┐
│                      API Gateway / Ingress                       │
└────────┬────────────────────────┬────────────────────┬──────────┘
         │                        │                    │
    ┌────▼────────┐      ┌───────▼────────┐  ┌───────▼────────┐
    │  elephant-  │      │   elephant-    │  │   elephant-    │
    │ repository  │      │     index      │  │     user       │
    │             │      │                │  │                │
    │  (Go 1.23)  │      │   (Go 1.23)    │  │   (Go 1.23)    │
    │             │      │                │  │                │
    │  Twirp RPC  │      │   Twirp RPC    │  │   Twirp RPC    │
    └────┬────────┘      └───────┬────────┘  └───────┬────────┘
         │                       │                    │
         │ Event Log             │ Reads Events       │
         │ (sequential)          │                    │
         │                       │                    │
    ┌────▼───────────────────────▼────────┐  ┌───────▼────────┐
    │         PostgreSQL 16               │  │  PostgreSQL 16 │
    │                                     │  │                │
    │  ┌──────────┐    ┌──────────────┐  │  │  ┌──────────┐  │
    │  │Documents │    │  Event Log   │  │  │  │User Data │  │
    │  │Versions  │    │  (append)    │  │  │  │Messages  │  │
    │  │ACLs      │    │              │  │  │  └──────────┘  │
    │  └──────────┘    └──────────────┘  │  └────────────────┘
    └────────┬────────────────────────────┘
             │                      │
             │ Archive              │ Index
             │                      │
    ┌────────▼────────┐    ┌────────▼───────────┐
    │   MinIO / S3    │    │    OpenSearch      │
    │                 │    │                    │
    │  ┌───────────┐  │    │  ┌──────────────┐  │
    │  │ Archives  │  │    │  │ Full-text    │  │
    │  │ Signed    │  │    │  │ Indices      │  │
    │  │ Documents │  │    │  │ (per type/   │  │
    │  └───────────┘  │    │  │  language)   │  │
    └─────────────────┘    │  └──────────────┘  │
                           └────────────────────┘
```

## Component Layers

### 1. Client Layer

**elephant-chrome** - Primary web interface
- React 18 + TypeScript
- Vite for fast builds
- TanStack Query for data fetching
- Y.js for collaborative editing
- Connects via Twirp RPC over HTTP

### 2. API Layer (Backend Services)

**elephant-repository** - Core document management
- Document CRUD operations
- Version control (all changes stored)
- Access Control Lists (ACLs)
- Event log (sequential, append-only)
- S3 archiving with cryptographic signatures
- Status workflow management
- Twirp API (Protobuf + JSON support)

**elephant-index** - Search service
- Follows repository event log
- Creates OpenSearch indices per document type and language
- Real-time indexing
- Zero-downtime reindexing
- Twirp API for search queries

**elephant-user** - User service
- User events and activities
- Inbox messages
- User preferences
- Separate from authentication (identity-agnostic)
- Twirp API

### 3. Data Layer

**PostgreSQL 16** - Primary data store
- Document storage with full versioning
- Event log (append-only table)
- ACL storage
- User data and messages
- Logical replication enabled for reporting

**OpenSearch / Elasticsearch** - Search engine
- Full-text search indices
- Per-type and per-language indices
- Faceted search capabilities
- Supports complex queries

**MinIO / AWS S3** - Object storage
- Archived document versions
- Cryptographic signatures
- Signing key rotation (every 180 days)
- Immutable storage for compliance

## Data Flow

### Write Path (Document Update)

1. Client sends document update via Twirp to **elephant-repository**
2. Repository validates with **revisor** schema validation
3. Repository checks ACLs for write permission
4. New version created in PostgreSQL
5. Event appended to event log with sequential number
6. Document archived to S3 with signature
7. Response returned to client

### Read Path (Document Retrieval)

1. Client requests document via Twirp from **elephant-repository**
2. Repository checks ACL for read permission
3. Latest version (or specific version) fetched from PostgreSQL
4. Document returned to client

### Search Path

1. Client sends search query to **elephant-index**
2. Index service queries OpenSearch
3. Results returned with document references
4. Client fetches full documents from **elephant-repository**

### Indexing Path

1. **elephant-index** polls event log from **elephant-repository**
2. New events processed sequentially
3. Documents indexed in OpenSearch
4. Index position stored for resumption

## Event Sourcing

Elephant uses event sourcing for audit, replay, and eventual consistency:

### Event Log Structure

```go
type Event struct {
    ID        int64     // Sequential number
    Type      string    // "document.created", "document.updated", etc.
    Timestamp time.Time
    UUID      string    // Document UUID
    Version   int       // Document version
    Data      JSONB     // Event payload
}
```

### Event Types

- `document.created` - New document created
- `document.updated` - Document content changed
- `document.status_changed` - Workflow status changed
- `document.acl_changed` - Permissions modified
- `document.archived` - Document archived to S3
- `document.deleted` - Document marked as deleted

### Event Consumers

Multiple services can consume events independently:
- **elephant-index**: Search indexing
- **External systems**: Workflow engines, notifications
- **Analytics**: Reporting and metrics
- **Replication**: Data sync to other systems

## Security Architecture

### Authentication

- System is identity-provider agnostic
- Supports any OIDC-compliant provider (Keycloak, Auth0, etc.)
- JWT tokens with required claims structure
- Mock auth endpoint for development (removed in production)

### Authorization

- ACLs stored per document
- Permissions: read, write, delete
- Unit-based access (users belong to units)
- Hierarchical permissions inheritance

### Data Security

- All documents archived with cryptographic signatures
- Signing keys rotated every 180 days
- TLS for all network communication
- Secrets managed via environment variables or secret managers

## Scalability

### Horizontal Scaling

- All services are stateless (except databases)
- Can run multiple instances behind load balancer
- Event log enables distributed read replicas

### Vertical Scaling

- PostgreSQL can be scaled with more CPU/RAM
- OpenSearch cluster can add more nodes
- S3 scales automatically

### Caching

- Client-side caching with TanStack Query
- Potential for Redis cache layer (not yet implemented)

## High Availability

### Database HA

- PostgreSQL replication (primary-replica)
- Point-in-time recovery with WAL archiving
- Automated failover with Patroni (in k8s)

### Service HA

- Multiple replicas in Kubernetes
- Health checks and automatic restart
- Rolling updates with zero downtime

### Storage HA

- S3 cross-region replication (optional)
- OpenSearch cluster with replicas

## Observability

### Metrics

- Prometheus metrics exposed by all Go services
- Standard metrics: requests, latency, errors
- Business metrics: documents created, versions, index lag

### Logging

- Structured JSON logging
- Centralized log aggregation (Loki or CloudWatch)
- Log levels: DEBUG, INFO, WARN, ERROR

### Tracing

- Potential for distributed tracing with OpenTelemetry
- Request ID propagation across services

### Frontend Observability

- Grafana Faro for Real User Monitoring (RUM)
- Error tracking and session replay
- Performance metrics

## Design Principles

1. **Event Sourcing**: All changes captured as immutable events
2. **CQRS**: Separate write and read models
3. **Microservices**: Loosely coupled services with clear boundaries
4. **API-First**: Well-defined Twirp/Protobuf APIs
5. **Stateless Services**: All state in databases, easy to scale
6. **Immutable History**: Full audit trail, never delete data
7. **Schema Validation**: Flexible content validation with revisor

## Technology Choices

### Why Go?

- Fast compilation and execution
- Excellent concurrency with goroutines
- Strong typing and tooling
- Small deployment artifacts
- Great for microservices

### Why Twirp?

- Simple RPC framework over HTTP
- Supports both Protobuf (efficient) and JSON (debugging)
- Language-agnostic client generation
- HTTP/2 support for multiplexing

### Why PostgreSQL?

- Robust ACID guarantees
- JSON/JSONB support for flexible schemas
- Logical replication for read replicas
- Mature ecosystem and tooling

### Why OpenSearch?

- Full-text search capabilities
- Open source (no licensing concerns)
- API-compatible with Elasticsearch
- Per-type and per-language indexing

### Why React?

- Component-based architecture
- Large ecosystem
- TypeScript support
- Excellent developer experience with Vite

## Network Architecture

### Development

```
localhost:5173 (elephant-chrome)
    ↓
localhost:1080 (elephant-repository)
localhost:1081 (elephant-index)
localhost:1082 (elephant-user)
    ↓
localhost:5432 (PostgreSQL)
localhost:9200 (OpenSearch)
localhost:9000 (MinIO)
```

### Production

```
HTTPS → Load Balancer → Ingress Controller
    ↓
    ├─→ elephant-repository (ClusterIP Service)
    ├─→ elephant-index (ClusterIP Service)
    └─→ elephant-user (ClusterIP Service)
        ↓
        ├─→ PostgreSQL (RDS or StatefulSet)
        ├─→ OpenSearch (Managed or StatefulSet)
        └─→ S3 (AWS or MinIO)
```

## Next Steps

- [Component Map](component-map.md) - Detailed component descriptions
- [Dependencies](dependencies.md) - Version requirements and dependency graph
- [Design Decisions](../12-architecture/design-decisions.md) - Architectural rationale
