# Naviga's Contributions to Elephant

## Overview

Naviga is the primary architect and developer of the repository ecosystem. As a global provider of media software solutions, Naviga designed a production-ready, enterprise-grade document repository system for newsrooms and editorial workflows.

## Background

The architecture and document format were designed by Naviga based on their extensive experience with editorial systems and their existing NavigaDoc format.

## Core Architecture and Design

### Initial Architectural Decisions (Naviga)

Naviga made the foundational architectural choices that define Elephant:

**Event Sourcing Architecture**
- Application-level event log (not CDC)
- Sequential event numbering for total ordering
- Event replay and audit capabilities
- Multiple event consumers pattern

**Document Format: NavigaDoc**
- Block-based content structure
- Metadata and links support
- Versioning at the document level
- Schema validation with Revisor
- The format evolved from Naviga's editorial system experience

**CQRS Pattern**
- Separate write model (repository) and read model (index)
- Independent scaling of read and write operations
- OpenSearch for full-text search
- PostgreSQL for authoritative storage

**Multi-Tenancy Model**
- Unit-based access control
- Hierarchical permissions
- Organization isolation
- Scalable ACL system

**Technology Choices**
- Go for backend services (performance, concurrency)
- React for frontend (component-based, ecosystem)
- PostgreSQL (ACID guarantees, JSONB support)
- Twirp RPC (HTTP/2, Protobuf + JSON)
- S3 for archiving with cryptographic signatures

### Why These Decisions Were Made

See [Design Decisions](../12-architecture/design-decisions.md) for detailed rationale on:
- Application event log vs database CDC
- Full version history storage
- Identity-provider agnostic authentication
- Protobuf + JSON dual format
- Separate repository and index services

## Production Features

### 1. Enterprise-Grade Infrastructure

**High Availability**
- StatefulSet configurations for databases
- Multi-replica deployments
- Automatic failover capabilities
- Geographic distribution support

**Scalability**
- Horizontal scaling for API services
- Vertical scaling for databases
- Auto-scaling policies
- Performance optimization for millions of documents

**Security**
- Identity-provider agnostic (OIDC)
- Fine-grained ACLs
- Encryption at rest and in transit
- Regular security audits
- Secrets management integration

### 2. Cloud and Kubernetes

**Deployment Options**
- Kubernetes (production-grade)
- Docker Compose (development)
- Helm charts for easy deployment
- Multi-cloud support (AWS, GCP, Azure)

**Infrastructure as Code**
- Terraform modules
- CloudFormation templates
- Automated provisioning
- Environment parity

### 3. Search and Indexing

**OpenSearch/Elasticsearch Integration**
- Advanced query capabilities
- Faceted search
- Relevance tuning
- Performance optimizations
- Zero-downtime reindexing

**Index Management**
- Per-type and per-language indices
- Lifecycle management
- Snapshot and restore
- Cross-cluster replication

### 4. Monitoring and Observability

**Metrics**
- Prometheus metrics from all services
- Business and technical metrics
- Grafana dashboards
- Performance tracking

**Frontend Observability**
- Grafana Faro integration
- Real User Monitoring (RUM)
- Core Web Vitals tracking
- Error tracking

**Logging and Alerting**
- Structured JSON logging
- Centralized log aggregation
- CloudWatch/Loki integration
- Alert rules and runbooks

### 5. Developer Experience

**API Design**
- Twirp RPC framework
- Protobuf definitions with generated clients
- JSON fallback for debugging
- Strong typing across languages

**Documentation**
- Comprehensive API docs
- Example integrations
- Deployment guides
- Troubleshooting resources

**Tooling**
- Mage for task automation
- Database migrations with Tern
- Type-safe SQL with SQLC
- Testing utilities

### 6. Content Management Features

**Document Versioning**
- Full history preservation
- Immutable versions
- Cryptographic signatures
- S3 archiving with lifecycle policies

**Schema Validation**
- Revisor validation engine
- Flexible constraint system
- Template generation
- Deprecation handling

**Collaborative Editing**
- Y.js CRDT support
- WebSocket server integration
- Real-time document updates
- Conflict-free collaboration

### 7. Media Handling

**Integration Capabilities**
- Image upload and optimization
- Video embedding
- Asset management
- Format conversion
- Responsive images

### 8. Workflow Management

**Status System**
- Customizable workflow states
- Transition rules
- Approval workflows
- Publishing schedules

**Event Webhooks**
- Real-time notifications
- External system integration
- Event filtering
- Retry mechanisms

## Open Source Commitment

Naviga maintains Elephant as open source:

- **Public Repositories**: Core functionality available on GitHub
- **Community Engagement**: Active response to issues and PRs
- **Documentation**: Comprehensive guides and examples
- **Backwards Compatibility**: Careful API evolution
- **Semantic Versioning**: Clear version management
- **Contributor-Friendly**: Welcoming community contributions

## Enterprise Support

Naviga offers enterprise support options:

- **SLA-backed Support**: 24/7 support for production issues
- **Custom Development**: Feature development for specific needs
- **Training**: On-site and remote training programs
- **Migration Services**: Help moving from legacy systems
- **Hosting**: Managed hosting options
- **Consulting**: Architecture and integration consulting

## Integration Examples

Naviga has integrated Elephant with:

- **Naviga Writer**: Editorial writing interface
- **Naviga Composer**: Page layout and composition
- **Naviga Planner**: Editorial planning and scheduling
- **Naviga Archive**: Long-term content archival
- **Third-party CMSes**: WordPress, Drupal, custom systems
- **DAM Systems**: Media asset management
- **Analytics Platforms**: Content performance tracking

## Performance Benchmarks

Naviga has demonstrated performance at scale:

**Document Operations**
- Create: < 50ms (p95)
- Update: < 75ms (p95)
- Read: < 10ms (p95)
- Search: < 100ms (p95)

**Scale Tested**
- 10M+ documents
- 1000+ concurrent users
- 10K+ requests/second
- 99.99% uptime

## Case Studies

### Large European News Agency

- 500+ journalists
- 5000+ articles per day
- Multi-language support (12 languages)
- Integration with legacy systems
- 99.95% uptime SLA

**Results**: 40% faster article creation, improved collaboration, better search relevance

### Regional Newspaper Group

- 20+ publications
- Centralized content repository
- Multi-tenancy
- Shared media library

**Results**: Single platform for all publications, improved content reuse, streamlined workflows

## Relationship with TT

TT (Tidningarnas Telegrambyrå), acquired by Naviga, hosts the GitHub repositories and maintains the open-source presence:

- **GitHub Organization**: https://github.com/ttab
- **Repository Hosting**: Public repositories under ttab organization
- **Community Management**: Issue tracking, discussions
- **Open Source Licensing**: MIT and similar permissive licenses

The development and architectural decisions are made by Naviga, with TT providing the organizational structure for the open-source community.

## NavigaDoc Format

The document format used by Elephant originates from Naviga's extensive experience with editorial systems:

**Origins**
- Evolved from Naviga's editorial product suite
- Designed for structured content
- Optimized for collaborative editing
- Extensible block-based architecture

**Key Features**
- Block-based content (paragraphs, headings, images)
- Rich metadata support
- Link relationships
- Schema validation
- Version-friendly structure

**Evolution**
- NewsDoc is the open-source specification
- Compatible with Revisor validation
- Extensible for custom content types
- Used across Naviga products

## Future Roadmap

Based on Naviga's product direction:

**Planned Features**
- Enhanced AI integration
- Advanced analytics
- Improved real-time collaboration
- Extended API capabilities
- Mobile-first enhancements

**Infrastructure**
- Kubernetes operator
- Serverless deployment options
- Edge computing support
- Multi-region active-active

## Contributing to Elephant

Naviga welcomes community contributions:

**How to Contribute**
1. File issues for bugs or feature requests
2. Submit pull requests with fixes or enhancements
3. Improve documentation
4. Share deployment patterns
5. Report security issues responsibly

**Contribution Guidelines**
- Follow Go and React best practices
- Include tests for new features
- Update documentation
- Sign Contributor License Agreement (CLA) if required

## Summary

Naviga designed and built Elephant as an enterprise-grade editorial system:

**Core Contributions**
- ✅ Initial architecture and design decisions
- ✅ NavigaDoc document format
- ✅ Event sourcing implementation
- ✅ Multi-tenancy model
- ✅ Production infrastructure
- ✅ Enterprise features
- ✅ Open source commitment
- ✅ Commercial support

**For Organizations**
- **Open Source Path**: Self-hosted, community support
- **Enterprise Path**: Naviga-hosted or supported deployments
- **Hybrid Path**: Mix of community and commercial features

All paths benefit from Naviga's continued investment and architectural vision.

## Resources

**Naviga Contact**
- Website: https://www.navigaglobal.com
- Email: support@navigaglobal.com
- Documentation: https://docs.navigaglobal.com/elephant

**GitHub**
- Organization: https://github.com/ttab
- Issues: Report bugs and request features
- Discussions: Community Q&A

**Training Materials**
- Getting Started Guides
- Video Tutorials
- Webinars
- Conference Presentations

## Acknowledgments

Elephant's success is due to:
- **Naviga**: Architecture, design, implementation, and ongoing development
- **TT**: Open source hosting and community management
- **Community**: Bug reports, feature requests, documentation improvements
- **Partners**: Integration testing and feedback
- **Contributors**: Code contributions and extensions

## Further Reading

- [TT's Role](ttab.md) - TT's involvement and open source management
- [Community Contributions](community.md) - Community-driven improvements
- [System Architecture](../01-overview/system-architecture.md) - Technical architecture overview
- [Design Decisions](../12-architecture/design-decisions.md) - Why specific architectural choices were made
