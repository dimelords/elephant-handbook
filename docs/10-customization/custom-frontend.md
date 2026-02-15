# Building a Custom Frontend for Elephant

## Overview

**Yes, you can absolutely build a custom frontend instead of using elephant-chrome.** The Elephant system is designed with a clear separation between backend and frontend. The backend services expose Twirp RPC APIs that any client can consume.

This guide explains everything you need to know to build your own frontend application.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [API Communication (Twirp)](#api-communication-twirp)
3. [Authentication](#authentication)
4. [Document Structure (Newsdoc)](#document-structure-newsdoc)
5. [Schema Validation (Revisor)](#schema-validation-revisor)
6. [Collaborative Editing (Y.js) - Optional](#collaborative-editing-yjs---optional)
7. [Complete Example](#complete-example)
8. [Key Concepts](#key-concepts)

---

## Architecture Overview

### Backend Services (What You'll Connect To)

```
┌─────────────────────────────────────────────────┐
│              Your Custom Frontend                │
│         (React, Vue, Svelte, vanilla JS, etc.)  │
└─────────────────┬───────────────────────────────┘
                  │
                  │ HTTP/JSON or HTTP/Protobuf
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             ▼             ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│elephant-│  │elephant-│  │elephant-│
│repository│ │  index  │  │  user   │
└─────────┘  └─────────┘  └─────────┘
   Twirp        Twirp        Twirp
```

**Core Services:**

1. **elephant-repository** (port 1080)
   - Document CRUD operations
   - Versioning and history
   - Status management (draft, published, etc.)
   - File uploads (images, attachments)
   - Access control lists (ACLs)

2. **elephant-index** (optional, for search)
   - Document search across all content
   - Filtering by type, status, metadata
   - Full-text search

3. **elephant-user** (optional)
   - User inbox messages
   - User events and notifications

### What You DON'T Need

- You don't need to use React, TypeScript, or Vite
- You don't need textbit (the rich text editor) unless you want WYSIWYG editing
- You don't need Y.js unless you want real-time collaborative editing
- You don't need the elephant-ui component library

### What You DO Need

- HTTP client (fetch, axios, etc.)
- Authentication token handling
- JSON serialization/deserialization
- Understanding of the Twirp protocol (simple!)

---

## API Communication (Twirp)

### What is Twirp?

Twirp is a simple RPC framework that works over HTTP. It supports both JSON and Protobuf.

**For most custom frontends, use JSON mode** - it's simpler and doesn't require code generation.

### Base URL Structure

```
http://localhost:1080/twirp/{package}.{service}/{method}
```

Examples:
```
http://localhost:1080/twirp/repository.Documents/Get
http://localhost:1080/twirp/repository.Documents/Update
http://localhost:1080/twirp/repository.Documents/BulkGet
http://localhost:1080/twirp/index.Search/Query
```

### Making API Calls

#### Using fetch (vanilla JavaScript)

```javascript
async function getDocument(uuid, accessToken) {
  const response = await fetch('http://localhost:1080/twirp/repository.Documents/Get', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`
    },
    body: JSON.stringify({
      uuid: uuid,
      version: "0",  // 0 means latest version
      status: "",
      lock: false,
      metaDocument: 1,
      metaDocumentVersion: "0"
    })
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.msg || 'API request failed');
  }

  return await response.json();
}
```

#### Using TypeScript with API Client (recommended)

The elephant-chrome app uses generated TypeScript clients:

```typescript
import { TwirpFetchTransport } from '@protobuf-ts/twirp-transport';
import { DocumentsClient } from '@ttab/elephant-api/repository';

// Initialize client
const client = new DocumentsClient(
  new TwirpFetchTransport({
    baseUrl: 'http://localhost:1080/twirp',
    sendJson: true,  // Use JSON instead of Protobuf
    jsonOptions: {
      ignoreUnknownFields: true
    }
  })
);

// Make a call
const { response } = await client.get({
  uuid: documentId,
  version: 0n,  // BigInt for version
  status: '',
  lock: false,
  metaDocument: 1,
  metaDocumentVersion: 0n
}, {
  meta: {
    'Authorization': `Bearer ${accessToken}`
  }
});

console.log(response.document);
```

### Common API Methods

#### Get a Document

```http
POST /twirp/repository.Documents/Get
Content-Type: application/json
Authorization: Bearer <token>

{
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "version": "0",
  "status": "",
  "lock": false,
  "metaDocument": 1,
  "metaDocumentVersion": "0"
}
```

Response:
```json
{
  "document": {
    "uuid": "550e8400-e29b-41d4-a716-446655440000",
    "type": "core/article",
    "uri": "core://article/550e8400-e29b-41d4-a716-446655440000",
    "title": "Example Article",
    "language": "en",
    "content": [...],
    "meta": [...],
    "links": [...]
  },
  "version": "1",
  "meta": {...},
  "acl": [...]
}
```

#### Create/Update a Document

```http
POST /twirp/repository.Documents/Update
Content-Type: application/json
Authorization: Bearer <token>

{
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "document": {
    "uuid": "550e8400-e29b-41d4-a716-446655440000",
    "type": "core/article",
    "uri": "core://article/550e8400-e29b-41d4-a716-446655440000",
    "title": "My First Article",
    "language": "en",
    "content": [],
    "meta": [],
    "links": []
  },
  "status": [],
  "acl": [
    {
      "uri": "core://unit/myteam",
      "permissions": ["r", "w"]
    }
  ],
  "ifMatch": "0",
  "meta": {},
  "lockToken": "",
  "updateMetaDocument": false,
  "ifWorkflowState": "",
  "ifStatusHeads": {},
  "attachObjects": {},
  "detachObjects": []
}
```

#### Search Documents (requires elephant-index)

```http
POST /twirp/index.Search/Query
Content-Type: application/json
Authorization: Bearer <token>

{
  "documentType": "core/article",
  "size": 20,
  "from": 0,
  "loadDocument": false,
  "loadSource": true,
  "query": {
    "conditions": {
      "matchAll": {}
    }
  }
}
```

---

## Authentication

### Development (Mock Token)

For local development, elephant-repository provides a mock token endpoint:

```bash
curl http://localhost:1080/token \
  -d grant_type=password \
  -d 'username=Developer <user://dimelords/dev, unit://dimelords/unit/dev>' \
  -d 'scope=doc_read doc_write doc_delete'
```

Response:
```json
{
  "access_token": "eyJhbGciOiJFUzUxMiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

Store this token and send it in the `Authorization` header:
```
Authorization: Bearer <access_token>
```

### Production Authentication

In production, you'll use a real identity provider (Keycloak, Auth0, etc.).

The JWT must contain these claims:
```json
{
  "iss": "https://your-auth-provider.com",
  "sub": "user://your-org/user-id",
  "sub_name": "User Name",
  "exp": 1234567890,
  "scope": "doc_read doc_write",
  "units": [
    {
      "uri": "unit://your-org/unit/team-name",
      "role": "editor",
      "label": "Team Name"
    }
  ]
}
```

**Important:** elephant-repository only validates the JWT signature and extracts claims. It doesn't care which identity provider you use.

---

## Document Structure (Newsdoc)

### What is Newsdoc?

Newsdoc is a JSON-based document format designed for editorial content. Think of it as a structured, semantic alternative to HTML.

### Basic Document Structure

```json
{
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "type": "core/article",
  "uri": "core://article/550e8400-e29b-41d4-a716-446655440000",
  "title": "Article Title",
  "language": "en",
  "content": [
    {
      "id": "abc123",
      "type": "core/text",
      "role": "heading-1",
      "data": {
        "text": "My Heading"
      }
    },
    {
      "id": "def456",
      "type": "core/text",
      "role": "body",
      "data": {
        "text": "Paragraph content goes here."
      }
    }
  ],
  "meta": [
    {
      "type": "core/description",
      "data": {
        "text": "Article description/summary"
      }
    },
    {
      "type": "core/author",
      "rel": "author",
      "title": "John Doe",
      "links": [
        {
          "rel": "self",
          "type": "core/author",
          "uri": "core://author/john-doe"
        }
      ]
    }
  ],
  "links": []
}
```

### Document Fields

| Field | Type | Description |
|-------|------|-------------|
| `uuid` | string | Unique document identifier (UUID v4) |
| `type` | string | Document type (e.g., "core/article", "core/planning") |
| `uri` | string | Unique resource identifier (matches format: `{type}/{uuid}`) |
| `title` | string | Document title |
| `language` | string | ISO 639-1 language code (e.g., "en", "sv") |
| `content` | Block[] | Main content blocks (headings, paragraphs, images, etc.) |
| `meta` | Block[] | Metadata blocks (authors, categories, descriptions, etc.) |
| `links` | Link[] | Relationships to other documents |

### Block Structure

Every content and meta block has this structure:

```json
{
  "id": "unique-block-id",       // Optional for meta blocks
  "type": "core/text",            // Block type
  "role": "heading-1",            // Optional: semantic role
  "title": "Block Title",         // Optional: display title
  "data": {                       // Block-specific data
    "text": "Content here"
  },
  "links": [],                    // Optional: related documents
  "rel": "author"                 // Optional: relationship type (meta blocks)
}
```

### Common Block Types

**Content Blocks:**
- `core/text` - Text paragraphs, headings
- `core/image` - Images
- `core/table` - Tables
- `core/embed` - Embedded content (videos, tweets, etc.)

**Meta Blocks:**
- `core/author` - Author information
- `core/description` - Article summary
- `core/section` - Publication section
- `core/category` - Content category
- `core/article-meta` - Article metadata (word count, etc.)

### Can You Use Your Own JSON Format?

**Short answer: No, not directly.**

The elephant-repository expects documents in the Newsdoc format. However:

1. **You can create a transformation layer** - Convert your format to Newsdoc before saving
2. **You can extend Newsdoc** - Add custom block types and data fields
3. **You can use custom document types** - Define your own document types with custom schemas

Example transformation:

```javascript
// Your format
const myFormat = {
  title: "My Article",
  body: "<p>HTML content</p>",
  author: "John Doe"
};

// Convert to Newsdoc
const newsdoc = {
  uuid: crypto.randomUUID(),
  type: "core/article",
  uri: `core://article/${uuid}`,
  title: myFormat.title,
  language: "en",
  content: [
    {
      id: crypto.randomUUID(),
      type: "core/text",
      role: "body",
      data: {
        text: stripHtml(myFormat.body) // Convert HTML to plain text
      }
    }
  ],
  meta: [
    {
      type: "core/author",
      rel: "author",
      title: myFormat.author,
      links: []
    }
  ],
  links: []
};

// Save to repository
await saveDocument(newsdoc, accessToken);
```

---

## Schema Validation (Revisor)

### What is Revisor?

Revisor is Elephant's schema validation library. It validates that documents conform to defined schemas.

### Do You Need to Use Revisor?

**In your frontend: No, it's optional.**

Validation happens on the backend when you save documents. However, using revisor in your frontend provides:
- Instant feedback to users
- Better UX (catch errors before saving)
- Type safety if using TypeScript

### Can You Define Custom Schemas?

**Yes, absolutely!** Revisor schemas are flexible and can be customized.

### Schema Structure

A revisor schema defines:
- Required and optional fields
- Data types and formats
- Allowed block types
- Validation rules

Example schema (simplified):

```json
{
  "name": "core/article",
  "declares": "core/article",
  "version": "1.0.0",
  "properties": {
    "uuid": {
      "type": "string",
      "format": "uuid"
    },
    "type": {
      "const": "core/article"
    },
    "title": {
      "type": "string",
      "maxLength": 200
    },
    "language": {
      "type": "string",
      "pattern": "^[a-z]{2}(-[a-z]{2})?$"
    }
  },
  "content": {
    "allowed": [
      "core/text",
      "core/image",
      "core/table"
    ]
  },
  "meta": {
    "allowed": [
      "core/author",
      "core/description",
      "core/section"
    ]
  }
}
```

### Using Custom Schemas

1. **Define your schema** in JSON or JavaScript
2. **Register it with elephant-repository** (configured in backend)
3. **Use your custom document type** when creating documents

Example:

```javascript
// Create a document with your custom type
const document = {
  uuid: crypto.randomUUID(),
  type: "myorg/recipe",  // Your custom type
  uri: "myorg://recipe/" + uuid,
  title: "Chocolate Chip Cookies",
  language: "en",
  content: [
    {
      type: "myorg/ingredient-list",
      data: {
        ingredients: [
          { name: "Flour", amount: "2 cups" },
          { name: "Sugar", amount: "1 cup" }
        ]
      }
    }
  ],
  meta: [],
  links: []
};

await saveDocument(document, accessToken);
```

The backend will validate against your custom schema before saving.

### Validation in Frontend (Optional)

If you want to validate in your frontend:

```bash
npm install @ttab/revisor
npm install @ttab/revisorschemas
```

```javascript
import { validate } from '@ttab/revisor';
import { schemas } from '@ttab/revisorschemas';

const result = validate(document, schemas['core/article']);

if (!result.valid) {
  console.error('Validation errors:', result.errors);
}
```

---

## Collaborative Editing (Y.js) - Optional

### Do You Need Y.js?

**Only if you want real-time collaborative editing** (like Google Docs).

If you're building a simpler app where one user edits at a time, you can skip Y.js entirely.

### What is Y.js?

Y.js is a CRDT (Conflict-free Replicated Data Type) library that enables real-time collaboration. It:
- Syncs changes between users in real-time
- Handles conflicts automatically
- Provides undo/redo per user
- Works offline with sync when reconnected

### How Y.js Works with Elephant

```
┌─────────────┐         ┌─────────────┐
│   User A    │         │   User B    │
│   Browser   │         │   Browser   │
└──────┬──────┘         └──────┬──────┘
       │                       │
       │   WebSocket           │
       │                       │
       └───────┬───────────────┘
               │
        ┌──────▼──────┐
        │  Y.js WS    │
        │   Server    │
        │ (Hocuspocus)│
        └─────────────┘
```

1. Each user loads the document into a Y.Doc
2. Y.js syncs changes via WebSocket
3. Conflicts are resolved automatically
4. Changes are persisted to elephant-repository

### Y.js Integration Example

```javascript
import * as Y from 'yjs';
import { HocuspocusProvider } from '@hocuspocus/provider';

// Create Y.Doc
const ydoc = new Y.Doc();

// Connect to collaboration server
const provider = new HocuspocusProvider({
  url: 'ws://localhost:1234',
  name: documentId,
  document: ydoc,
  token: accessToken
});

// Get shared data structure
const yContent = ydoc.getArray('content');

// Listen for changes
yContent.observe((event) => {
  console.log('Content changed:', event);
});

// Make changes
ydoc.transact(() => {
  yContent.push([{
    type: 'core/text',
    data: { text: 'New paragraph' }
  }]);
});
```

### Do You Need a Y.js Server?

If you want collaboration, yes. Options:

1. **Hocuspocus** (recommended) - Full-featured Y.js server
2. **y-websocket** - Simple Y.js WebSocket server
3. **Custom server** - Build your own using Y.js protocols

elephant-chrome includes a Hocuspocus server in `src-srv/collaboration/`.

### Skip Y.js and Use Simple Editing

For non-collaborative editing:

```javascript
// Load document from repository
const { document } = await getDocument(uuid, accessToken);

// Edit in plain JavaScript
document.title = "Updated Title";
document.content.push({
  id: crypto.randomUUID(),
  type: "core/text",
  role: "body",
  data: { text: "New paragraph" }
});

// Save back to repository
await saveDocument(document, accessToken);
```

This is much simpler if you don't need real-time collaboration.

---

## Complete Example

Here's a minimal custom frontend:

```html
<!DOCTYPE html>
<html>
<head>
  <title>Elephant Custom Frontend</title>
</head>
<body>
  <h1>My Custom Elephant Frontend</h1>

  <div id="login">
    <button onclick="login()">Get Dev Token</button>
  </div>

  <div id="app" style="display:none;">
    <h2>Create Article</h2>
    <input id="title" placeholder="Title" />
    <textarea id="content" placeholder="Content"></textarea>
    <button onclick="createArticle()">Save</button>

    <h2>Documents</h2>
    <ul id="documents"></ul>
  </div>

  <script>
    const REPO_URL = 'http://localhost:1080';
    let accessToken = null;

    async function login() {
      const response = await fetch(`${REPO_URL}/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'password',
          username: 'Dev User <user://dev/1, unit://dev/team>',
          scope: 'doc_read doc_write doc_delete'
        })
      });

      const data = await response.json();
      accessToken = data.access_token;

      document.getElementById('login').style.display = 'none';
      document.getElementById('app').style.display = 'block';

      loadDocuments();
    }

    async function createArticle() {
      const uuid = crypto.randomUUID();
      const title = document.getElementById('title').value;
      const content = document.getElementById('content').value;

      const document = {
        uuid,
        type: 'core/article',
        uri: `core://article/${uuid}`,
        title,
        language: 'en',
        content: [
          {
            id: crypto.randomUUID(),
            type: 'core/text',
            role: 'body',
            data: { text: content }
          }
        ],
        meta: [],
        links: []
      };

      const response = await fetch(`${REPO_URL}/twirp/repository.Documents/Update`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        body: JSON.stringify({
          uuid,
          document,
          status: [],
          acl: [{ uri: 'core://unit/dev', permissions: ['r', 'w'] }],
          ifMatch: '0',
          meta: {},
          lockToken: '',
          updateMetaDocument: false,
          ifWorkflowState: '',
          ifStatusHeads: {},
          attachObjects: {},
          detachObjects: []
        })
      });

      if (response.ok) {
        alert('Article created!');
        document.getElementById('title').value = '';
        document.getElementById('content').value = '';
        loadDocuments();
      } else {
        const error = await response.json();
        alert('Error: ' + error.msg);
      }
    }

    async function loadDocuments() {
      // Note: This requires elephant-index to be running
      // For simplicity, we'll just show a message
      document.getElementById('documents').innerHTML =
        '<li>Search requires elephant-index service</li>';
    }
  </script>
</body>
</html>
```

Save this as `index.html` and open in a browser. You'll need elephant-repository running.

---

## Key Concepts

### 1. Versioning

Every document save creates a new version. Versions are sequential (1, 2, 3, ...).

```javascript
// Get specific version
const v1 = await getDocument(uuid, accessToken, 1);
const v2 = await getDocument(uuid, accessToken, 2);

// Get latest version
const latest = await getDocument(uuid, accessToken, 0);
```

### 2. Status Workflow

Documents can have statuses to track their lifecycle:

```javascript
// Common statuses
'draft'      // Being worked on
'ready'      // Ready for review
'published'  // Published
'archived'   // Archived
```

Set status when saving:

```javascript
await fetch(`${REPO_URL}/twirp/repository.Documents/Update`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${accessToken}`
  },
  body: JSON.stringify({
    uuid: documentId,
    document: document,
    status: [{
      name: 'published',
      version: '0',
      meta: {},
      ifMatch: '0'
    }],
    // ... rest of fields
  })
});
```

### 3. Access Control Lists (ACLs)

Control who can read/write documents:

```javascript
{
  acl: [
    {
      uri: 'core://unit/editorial',
      permissions: ['r', 'w']  // read and write
    },
    {
      uri: 'core://unit/public',
      permissions: ['r']  // read only
    }
  ]
}
```

### 4. Document Types

Common document types:
- `core/article` - News articles
- `core/planning` - Editorial planning
- `core/image` - Images
- `core/author` - Author profiles
- `core/section` - Publication sections

You can define custom types (e.g., `myorg/recipe`).

### 5. Event Log

elephant-repository maintains an event log of all changes. You can:
- Subscribe to events via Server-Sent Events (SSE)
- Build custom consumers (indexing, replication, etc.)

```javascript
const eventSource = new EventSource(
  `${REPO_URL}/api/repository/events?offset=0`,
  { headers: { 'Authorization': `Bearer ${accessToken}` } }
);

eventSource.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Document changed:', data);
};
```

---

## Next Steps

1. **Start Simple**
   - Get elephant-repository running
   - Get a dev token
   - Create a simple HTML page that creates/reads documents
   - Don't worry about Y.js, schemas, or collaboration yet

2. **Add Features Gradually**
   - Add document listing (requires elephant-index)
   - Add more complex document structures
   - Add image uploads
   - Add status management

3. **Consider Your Needs**
   - Do you need real-time collaboration? → Add Y.js
   - Do you need search? → Set up elephant-index
   - Do you need custom document types? → Define custom schemas
   - Do you need user notifications? → Set up elephant-user

4. **Choose Your Stack**
   - React, Vue, Svelte, Angular → All work fine
   - TypeScript → Use generated API clients
   - JavaScript → Use plain fetch with JSON
   - Mobile → Use any HTTP client

---

## FAQ

**Q: Can I use REST instead of Twirp?**
A: Twirp IS essentially REST. It uses POST requests with JSON payloads. The main difference is the URL structure.

**Q: Do I need to use Protobuf?**
A: No. Twirp supports JSON mode, which is easier for custom frontends.

**Q: Can I use GraphQL?**
A: Not natively, but you could build a GraphQL wrapper around the Twirp APIs.

**Q: How do I handle file uploads (images)?**
A: Use the `CreateUpload` → `PUT to S3` → `Update document` flow (see Repository.ts:346-416).

**Q: Can I skip newsdoc and use my own format?**
A: You must save documents in newsdoc format, but you can transform your format to newsdoc before saving.

**Q: Is elephant-chrome required?**
A: No. It's just a reference implementation. Build your own!

**Q: Can I use Elephant for non-editorial content?**
A: Absolutely. The document model is flexible. Define custom types and schemas for any content.

---

## Resources

- **Elephant GitHub**: https://github.com/dimelords
- **Twirp Protocol**: https://twitchtv.github.io/twirp/docs/intro.html
- **Y.js Docs**: https://docs.yjs.dev/
- **Newsdoc Spec**: https://github.com/ttab/newsdoc
- **Revisor**: https://github.com/ttab/revisor

---

**Summary:**

Yes, you can absolutely build a custom frontend! The Elephant backend is designed to be frontend-agnostic. Use any technology stack you want, communicate via the Twirp API, and save documents in the newsdoc format (which you can generate from your own data structures). Y.js is optional and only needed for real-time collaboration. Start simple with basic CRUD operations and add features as needed.
