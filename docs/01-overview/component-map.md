# Component Map

## Backend Services

### elephant-repository
**Purpose**: Core document repository with versioning and ACLs
**Technology**: Go 1.23, PostgreSQL, S3
**Port**: 1080
**Repository**: https://github.com/dimelords/elephant-repository

**Responsibilities**:
- Document CRUD operations
- Version control
- Access control (ACLs)
- Event log management
- S3 archiving
- Status workflow

### elephant-index
**Purpose**: Search indexing service
**Technology**: Go 1.23, OpenSearch
**Port**: 1081
**Repository**: https://github.com/dimelords/elephant-index

**Responsibilities**:
- Follow repository event log
- Index documents in OpenSearch
- Provide search API
- Maintain index health

### elephant-user
**Purpose**: User events and inbox service
**Technology**: Go 1.23, PostgreSQL
**Port**: 1082
**Repository**: https://github.com/dimelords/elephant-user

**Responsibilities**:
- User activity tracking
- Inbox messages
- User preferences
- Notifications (future)

## Frontend Applications

### elephant-chrome
**Purpose**: Main web application
**Technology**: React 18, TypeScript, Vite
**Port**: 5173 (dev)
**Repository**: https://github.com/dimelords/elephant-chrome

**Features**:
- Document editing
- Search interface
- User management
- Collaborative editing

### elephant-ui
**Purpose**: Shared UI component library
**Technology**: React, TypeScript
**Repository**: https://github.com/dimelords/elephant-ui

**Components**:
- Buttons, inputs, forms
- Layout components
- Document viewers
- Reusable patterns

## Editors

### textbit
**Purpose**: Rich text editor
**Technology**: React, ProseMirror, Y.js
**Repository**: https://github.com/dimelords/textbit

**Features**:
- Rich text editing
- Block-based content
- Collaborative editing (Y.js CRDT)
- Plugin architecture

### textbit-plugins
**Purpose**: Editor plugins
**Technology**: React, TypeScript
**Repository**: https://github.com/dimelords/textbit-plugins

**Plugins**:
- Image insertion
- Link management
- Tables
- Embeds

## APIs and Libraries

### elephant-api
**Purpose**: Protobuf API definitions
**Technology**: Protobuf, Twirp
**Repository**: https://github.com/dimelords/elephant-api

**Contents**:
- Proto files for all services
- Generated Go code
- API documentation

### elephant-api-npm
**Purpose**: TypeScript API client
**Technology**: TypeScript
**Repository**: https://github.com/dimelords/elephant-api-npm

**Provides**:
- TypeScript types
- API client functions
- Request/response handling

### elephantine
**Purpose**: Shared Go libraries
**Technology**: Go
**Repository**: https://github.com/dimelords/elephantine

**Libraries**:
- Common utilities
- Shared types
- Helper functions

### newsdoc
**Purpose**: NewsDoc document format
**Technology**: Go, JSON Schema
**Repository**: https://github.com/dimelords/newsdoc

**Defines**:
- Document structure
- Block types
- Metadata schemas

### revisor
**Purpose**: Schema validation
**Technology**: Go
**Repository**: https://github.com/dimelords/revisor

**Features**:
- Schema validation
- Constraint checking
- Template generation

### revisorschemas
**Purpose**: Content schemas
**Technology**: JSON
**Repository**: https://github.com/dimelords/revisorschemas

**Contains**:
- Core schemas
- Block definitions
- Validation rules

### media-client
**Purpose**: Media handling
**Technology**: Go
**Repository**: https://github.com/dimelords/media-client

**Features**:
- Image upload
- Media metadata
- Format conversion

## Infrastructure Components

### PostgreSQL 16
**Purpose**: Primary database
**Used by**: repository, user services

**Storage**:
- Documents and versions
- Event log
- ACLs
- User data

### OpenSearch
**Purpose**: Search engine
**Used by**: index service

**Storage**:
- Document indices
- Search metadata

### MinIO / S3
**Purpose**: Object storage
**Used by**: repository service

**Storage**:
- Archived documents
- Signed document versions
- Reports

## Dependency Graph

```
elephant-chrome
    ├── elephant-api-npm
    ├── elephant-ui
    ├── textbit
    │   └── textbit-plugins
    └── newsdoc (types)

elephant-repository
    ├── elephant-api
    ├── elephantine
    ├── newsdoc
    ├── revisor
    │   └── revisorschemas
    ├── PostgreSQL
    └── MinIO/S3

elephant-index
    ├── elephant-api
    ├── elephantine
    └── OpenSearch

elephant-user
    ├── elephant-api
    ├── elephantine
    └── PostgreSQL
```

## Communication Patterns

### Client → Backend
- Protocol: Twirp (HTTP/2)
- Format: JSON or Protobuf
- Authentication: JWT Bearer token

### Service → Database
- Protocol: PostgreSQL wire protocol
- Library: pgx (Go)

### Service → S3
- Protocol: S3 API
- Library: aws-sdk-go

### Service → OpenSearch
- Protocol: REST API
- Format: JSON

## Port Assignments

| Service | Port | Protocol |
|---------|------|----------|
| elephant-repository | 1080 | HTTP/Twirp |
| elephant-index | 1081 | HTTP/Twirp |
| elephant-user | 1082 | HTTP/Twirp |
| elephant-chrome (dev) | 5173 | HTTP |
| PostgreSQL | 5432 | PostgreSQL |
| OpenSearch | 9200 | HTTP |
| MinIO API | 9000 | S3/HTTP |
| MinIO Console | 9001 | HTTP |

## Environment Variables by Component

See [Environment Variables](../07-configuration/environment-variables.md) for complete reference.

## Next Steps

- [System Architecture](system-architecture.md)
- [Dependencies](dependencies.md)
- [Design Decisions](design-decisions.md)
