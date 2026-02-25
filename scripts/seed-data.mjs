#!/usr/bin/env node

const REPO_URL = 'http://localhost:1080';
const KEYCLOAK_URL = 'http://localhost:8180';

console.log('🌱 Seeding Elephant development database...\n');

// Get access token
console.log('🔑 Getting access token...');
const tokenRes = await fetch(`${KEYCLOAK_URL}/realms/elephant/protocol/openid-connect/token`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    client_id: 'elephant',
    client_secret: 'elephant-secret',
    grant_type: 'password',
    username: 'dev',
    password: 'dev',
    scope: 'doc_read doc_write'
  })
});

const { access_token } = await tokenRes.json();
console.log('✅ Got access token\n');

// Helper function to create document
async function createDocument(doc, description) {
  const payload = {
    document: doc,
    uuid: doc.uuid,
    status: [{ name: 'usable' }],  // CRITICAL: Add status!
    ifMatch: "0",
    acl: [{ uri: 'core://unit/redaktionen', permissions: ['r', 'w'] }]
  };

  const res = await fetch(`${REPO_URL}/twirp/elephant.repository.Documents/Update`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${access_token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });

  const result = await res.json();
  if (result.version) {
    console.log(`✅ Created ${description} (${doc.uuid}) v${result.version}`);
    return doc.uuid;
  } else {
    console.error(`❌ Failed to create ${description}:`, result.msg || result.code);
    return null;
  }
}

// Create Sections
console.log('📁 Creating sections...');
const sections = [
  { title: 'Nyheter', code: 'nyheter' },
  { title: 'Sport', code: 'sport' },
  { title: 'Kultur', code: 'kultur' },
  { title: 'Ekonomi', code: 'ekonomi' },
  { title: 'Nöje', code: 'noje' },
  { title: 'Debatt', code: 'debatt' }
];

const sectionIds = [];
for (const section of sections) {
  const uuid = crypto.randomUUID();
  const id = await createDocument({
    uuid,
    type: 'core/section',
    uri: `core://section/${uuid}`,
    url: '',
    title: section.title,
    language: 'sv-se',
    meta: [{
      type: 'core/section',
      data: { code: section.code }
    }],
    content: [],
    links: []
  }, `section "${section.title}"`);

  if (id) sectionIds.push({ id, title: section.title });
}
console.log('');

console.log('✨ Seeding complete!');
console.log(`  • ${sectionIds.length} sections created with status "usable"`);
console.log('');
console.log('💡 Wait 10-20 seconds for elephant-index to index the documents,');
console.log('   then refresh your browser.');
