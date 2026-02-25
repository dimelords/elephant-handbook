#!/usr/bin/env node

import { readFileSync, readdirSync } from 'fs';

const REPO_URL = 'http://localhost:1080';
const KEYCLOAK_URL = 'http://localhost:8180';

console.log('📋 Loading all missing schemas...\n');

// Get access token with schema_admin scope
console.log('🔑 Getting access token with schema_admin scope...');
const tokenRes = await fetch(`${KEYCLOAK_URL}/realms/elephant/protocol/openid-connect/token`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    client_id: 'elephant',
    client_secret: 'elephant-secret',
    grant_type: 'password',
    username: 'dev',
    password: 'dev',
    scope: 'schema_admin'
  })
});

if (!tokenRes.ok) {
  console.error('❌ Failed to get access token:', await tokenRes.text());
  process.exit(1);
}

const { access_token } = await tokenRes.json();
console.log('✅ Got access token\n');

// Get currently active schemas
console.log('📖 Getting active schemas...');
const activeRes = await fetch(`${REPO_URL}/twirp/elephant.repository.Schemas/ListActive`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: '{}'
});

const activeSchemas = await activeRes.json();
const activeNames = new Set((activeSchemas.schemas || []).map(s => s.name));
console.log(`✅ Found ${activeNames.size} active schemas\n`);

// Find all schema files
const schemaFiles = readdirSync('./revisorschemas')
  .filter(f => f.endsWith('.json') && !f.includes('testdata'));

console.log(`📚 Found ${schemaFiles.length} schema files in revisorschemas/\n`);

// Load each schema
let loaded = 0;
let skipped = 0;
let failed = 0;

for (const file of schemaFiles) {
  const schemaSpec = readFileSync(`./revisorschemas/${file}`, 'utf-8');
  const schema = JSON.parse(schemaSpec);

  if (!schema.name || !schema.version) {
    console.log(`⚠️  Skipping ${file} (missing name or version)`);
    skipped++;
    continue;
  }

  if (activeNames.has(schema.name)) {
    console.log(`⏭️  Skipping ${schema.name} (already active)`);
    skipped++;
    continue;
  }

  console.log(`📤 Registering ${schema.name} v${schema.version}...`);

  const registerRes = await fetch(`${REPO_URL}/twirp/elephant.repository.Schemas/Register`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${access_token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      schema: {
        name: schema.name,
        version: `v${schema.version}.0`,
        spec: schemaSpec
      },
      activate: true
    })
  });

  if (!registerRes.ok) {
    const error = await registerRes.json();
    console.error(`   ❌ Failed: ${error.msg || error.code}`);
    failed++;
  } else {
    console.log(`   ✅ Registered and activated`);
    loaded++;
  }
}

console.log('\n' + '='.repeat(50));
console.log('📊 Summary:');
console.log(`   ✅ Loaded: ${loaded}`);
console.log(`   ⏭️  Skipped: ${skipped}`);
console.log(`   ❌ Failed: ${failed}`);
console.log('='.repeat(50) + '\n');

if (loaded > 0) {
  console.log('🔄 Restarting elephant-repository to pick up new schemas...');
  console.log('   Run: docker compose restart elephant-repository');
}
