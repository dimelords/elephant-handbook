# Design Decisions

This document explains the architectural and design decisions made in the Elephant system, particularly by the original TT/Naviga team.

## Event Log vs Change Data Capture (CDC)

### Decision: Implement Custom Event Log

Elephant implements its own application-level event log rather than relying on database Change Data Capture (CDC) mechanisms like PostgreSQL's logical replication or Debezium.

### Rationale

**1. Business-Level Events**

CDC captures database changes (INSERT, UPDATE, DELETE), but Elephant's event log captures business events with semantic meaning:

```go
// Application-level event (what Elephant uses)
{
  "type": "document.published",
  "uuid": "doc-123",
  "version": 5,
  "by": "user-456",
  "metadata": {
    "previous_status": "draft",
    "new_status": "published",
    "workflow_name": "editorial_review"
  }
}

// vs CDC event (what you'd get from Postgres)
{
  "op": "UPDATE",
  "table": "documents",
  "new": {"uuid": "doc-123", "status": "published", "updated_at": "..."},
  "old": {"uuid": "doc-123", "status": "draft", "updated_at": "..."}
}
```

**2. Event Enrichment**

Application events can include context not stored in the database:
- User intent and actions
- Workflow information
- Business rules that triggered the change
- Aggregated data from multiple tables

**3. Schema Evolution**

Application events can evolve independently of database schema:
- Add new event fields without ALTER TABLE
- Maintain backward compatibility easily
- Version events explicitly

**4. Strong Ordering Guarantees**

Sequential event numbering provides total ordering:
```go
type Event struct {
    ID int64  // Sequential number, no gaps
    // ...
}
```

CDC tools may have:
- Gaps in sequence numbers
- Reordering across transactions
- Complexity with distributed databases

**5. Replay and Debugging**

Application events are easier to understand and replay:
- Human-readable event types
- Clear causality and intent
- Easy to simulate in tests
- Simpler debugging

**6. Multi-Table Transactions**

A single business operation may touch multiple tables, but should produce one event:

```go
// Single business event
{"type": "document.created", "uuid": "doc-123"}

// Might involve multiple database operations:
// - INSERT into documents
// - INSERT into versions
// - INSERT into acls
// - INSERT into metadata
```

CDC would produce multiple low-level change events that need correlation.

**7. Performance and Efficiency**

Application-level events:
- Only capture what matters for downstream consumers
- Avoid noise from internal tables (migrations, audit logs, etc.)
- Efficient serialization (no need to parse WAL)

### Trade-offs

**Advantages**
- ✅ Semantic, business-level events
- ✅ Strong ordering guarantees
- ✅ Easy to replay and debug
- ✅ Schema evolution flexibility
- ✅ Works with any database
- ✅ No CDC infrastructure needed

**Disadvantages**
- ❌ Must manually emit events in code
- ❌ Risk of forgetting to emit events
- ❌ Events and database changes in separate transactions
- ❌ Potential for event/state inconsistency

### Mitigation Strategies

To address the disadvantages:

1. **Transaction-level event emission**: Events emitted within same transaction as data changes
2. **Testing**: Integration tests verify events are emitted correctly
3. **Idempotent consumers**: Event consumers handle duplicate/out-of-order events
4. **Event validation**: Schema validation for events

## Protobuf + JSON API (Twirp)

### Decision: Use Twirp with Dual Protobuf/JSON Support

### Rationale

**1. Type Safety with Flexibility**

Protobuf provides strong typing and code generation, while JSON fallback enables:
- Easy debugging with curl/Postman
- Browser DevTools inspection
- Quick prototyping

**2. Language Agnostic**

Protobuf definitions generate clients for any language:
- TypeScript for frontend
- Go for backend services
- Python for tools and scripts
- Any language with Protobuf support

**3. Efficient Wire Format**

Protobuf binary format is compact:
- Smaller payloads than JSON
- Faster serialization/deserialization
- Lower bandwidth usage

**4. Schema Evolution**

Protobuf supports backward/forward compatibility:
- Add optional fields without breaking clients
- Deprecate fields gracefully
- Version APIs explicitly

**5. Simple HTTP/2 Transport**

Twirp uses standard HTTP/2:
- Works through firewalls and proxies
- No special infrastructure needed
- Standard load balancer compatibility

### Alternative Considered: gRPC

gRPC was considered but rejected because:
- More complex setup (HTTP/2 required, not HTTP/1.1)
- Browser support requires grpc-web proxy
- Twirp is simpler and "good enough"

## Document Versioning: Full History Storage

### Decision: Store Complete Version History

Every document update creates a new complete version in the database, not just deltas.

### Rationale

**1. Simplicity**

Retrieving any version is a simple query:
```sql
SELECT * FROM versions WHERE uuid = $1 AND version = $2
```

No need to:
- Reconstruct from deltas
- Apply patches
- Complex version traversal

**2. Performance**

Reading historical versions is fast:
- No computation needed
- Direct database query
- Same performance as current version

**3. Audit and Compliance**

Complete history provides:
- Full audit trail
- Legal compliance (GDPR, etc.)
- Forensic capabilities

**4. Parallel Access**

Multiple versions can be read simultaneously:
- No lock contention
- Easy to diff versions
- Historical analysis

### Trade-offs

**Advantages**
- ✅ Simple implementation
- ✅ Fast retrieval
- ✅ Complete audit trail
- ✅ Easy version comparison

**Disadvantages**
- ❌ More storage required
- ❌ Larger database size

**Mitigation**: Storage is cheap, and compression helps significantly. S3 archiving offloads old versions.

## Multi-Tenancy: Unit-Based Access Control

### Decision: Use "Units" as Organization Boundary

Documents and users belong to organizational units. ACLs grant permissions to units, not individual users.

### Rationale

**1. Scalability**

Unit-based ACLs scale better than user-based:
- Fewer ACL entries per document
- Easier to manage large organizations
- Simple permission inheritance

**2. Organizational Structure**

Units map to real-world organization:
- Departments, teams, projects
- Natural permission boundaries
- Matches editorial workflows

**3. User Management**

Adding/removing users is simple:
- Change user's unit membership
- No need to update document ACLs
- Immediate permission changes

**4. Flexible Hierarchy**

Units can have parent/child relationships:
- Permission inheritance
- Delegated administration
- Flexible organizational models

### Alternative Considered: Row-Level Security (RLS)

PostgreSQL Row-Level Security was considered but rejected:
- Less flexible than application-level ACLs
- Harder to test and debug
- Complicates database migrations
- Application-level control is clearer

## Separate Repository and Index Services

### Decision: CQRS Pattern with Separate Services

Write model (repository) and read model (index) are separate services.

### Rationale

**1. Independent Scaling**

Scale services based on load:
- Repository handles writes (typically lower volume)
- Index handles searches (typically higher volume)
- Different resource requirements

**2. Technology Choice**

Use best tool for each job:
- PostgreSQL for ACID writes
- OpenSearch for full-text search
- No compromise on either

**3. Eventual Consistency**

Index can lag slightly behind repository:
- Acceptable for search use case
- Simplifies architecture
- Better performance

**4. Independent Deployment**

Services can be updated independently:
- Repository changes don't affect index
- Reindex without repository downtime
- Easier maintenance

**5. Event-Driven Integration**

Event log provides clean integration:
- Loose coupling
- Multiple consumers possible
- Resilient to failures

### Trade-offs

**Advantages**
- ✅ Better scalability
- ✅ Technology flexibility
- ✅ Independent deployment
- ✅ Clear separation of concerns

**Disadvantages**
- ❌ Eventual consistency
- ❌ More operational complexity
- ❌ Multiple services to monitor

## S3 Archiving with Cryptographic Signatures

### Decision: Archive Documents to S3 with Digital Signatures

### Rationale

**1. Immutable Archive**

S3 provides:
- Immutable storage (object lock)
- Durability (99.999999999%)
- Compliance capabilities
- Lifecycle management

**2. Cryptographic Proof**

Digital signatures provide:
- Tamper detection
- Non-repudiation
- Legal validity
- Audit trail integrity

**3. Cost Efficiency**

S3 is cheaper than database storage:
- Glacier for long-term retention
- Lifecycle rules for automatic tiering
- No database overhead

**4. Key Rotation**

Signing keys rotate every 180 days:
- Limited blast radius if key compromised
- Compliance with security policies
- Keys stored securely

### Implementation

```go
// Sign document with current key
signature := Sign(documentJSON, currentSigningKey)

// Store in S3
s3.Put(
    bucket: "elephant-archive",
    key: "uuid/version",
    body: documentJSON,
    metadata: {
        "signature": signature,
        "key_id": currentSigningKey.ID,
    }
)
```

## Identity-Provider Agnostic Authentication

### Decision: No Built-in Authentication, Use OIDC

### Rationale

**1. Flexibility**

Organizations can use their existing identity provider:
- Keycloak (open source)
- Auth0
- Okta
- Azure AD
- Google Workspace
- Any OIDC-compliant provider

**2. Security**

Authentication is handled by specialized systems:
- OAuth2/OIDC best practices
- MFA support
- SSO integration
- Password policies

**3. Simplicity**

Elephant doesn't need to manage:
- User credentials
- Password resets
- MFA setup
- Account lockout

**4. Compliance**

Organizations maintain control:
- Meet internal security policies
- Compliance requirements (SOC2, ISO27001)
- Audit logging in their IdP

### Requirements

JWT tokens must contain:
```json
{
  "iss": "https://idp.example.com",
  "sub": "user-uuid",
  "sub_name": "Display Name",
  "exp": 1234567890,
  "units": ["unit-uuid-1", "unit-uuid-2"],
  "scope": "doc_read doc_write"
}
```

### Mock Authentication for Development

Development environment includes mock token endpoint:
```bash
curl http://localhost:1080/token \
  -d grant_type=password \
  -d 'username=Dev User <user://dev/user1>' \
  -d 'scope=doc_read doc_write'
```

**Removed in production builds** for security.

## Why React + Vite (Not Next.js or Other Meta-Frameworks)

### Decision: React SPA with Vite

### Rationale

**1. Simplicity**

Single-page application is simpler for editorial tool:
- No SSR needed (content not public-facing)
- Client-side routing sufficient
- Faster development cycle

**2. Vite Performance**

Vite provides:
- Instant dev server start
- Lightning-fast HMR
- Optimized production builds
- Simple configuration

**3. Backend API Separation**

Clean separation between frontend and backend:
- Backend is pure API (Twirp)
- Frontend is static files
- Can deploy independently
- Can use CDN for frontend

**4. Collaborative Editing**

Y.js requires WebSocket connections:
- Easier with SPA architecture
- Direct WebSocket to collaboration server
- No SSR complications

### Alternative Considered: Next.js

Next.js was considered but rejected:
- SSR not needed for authenticated editorial tool
- Added complexity without benefits
- Vite is faster for development
- Simpler deployment model

## Why Go (Not Node.js or Rust)

### Decision: Go 1.23 for Backend Services

### Rationale

**1. Performance**

Go provides:
- Fast execution (compiled, not interpreted)
- Excellent concurrency with goroutines
- Low memory footprint
- Fast startup time

**2. Simplicity**

Go is simple and readable:
- Small language specification
- Easy to onboard new developers
- Clear idioms and patterns
- Good standard library

**3. Tooling**

Go has excellent tools:
- Fast compilation
- Built-in testing
- Race detector
- Profiling tools
- Linting (golangci-lint)

**4. Deployment**

Go produces:
- Single binary (no runtime needed)
- Small Docker images
- Easy cross-compilation
- Fast container startup

### Alternative Considered: Node.js

Node.js was rejected:
- Single-threaded event loop limiting
- Higher memory usage
- Runtime dependency
- Less type safety (even with TypeScript)

### Alternative Considered: Rust

Rust was rejected:
- Steeper learning curve
- Longer compile times
- Smaller ecosystem for web services
- Overkill for this use case

## Summary

Elephant's design decisions prioritize:

1. **Simplicity**: Easy to understand and maintain
2. **Flexibility**: Support different deployment models and providers
3. **Performance**: Fast enough for editorial workflows
4. **Scalability**: Can grow with organization
5. **Audit**: Complete history and traceability
6. **Security**: Multiple layers of protection

These decisions create a system that is:
- ✅ Production-ready
- ✅ Maintainable
- ✅ Extensible
- ✅ Compliant
- ✅ Performant

## Further Reading

- [System Architecture](system-architecture.md)
- [Component Map](component-map.md)
- [Dependencies](dependencies.md)
