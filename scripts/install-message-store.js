#!/usr/bin/env node

/**
 * Install Message DB schema to the message store database
 *
 * This script installs the @eventide/message-db schema which includes:
 * - message_store schema
 * - messages table
 * - write_message() function
 * - read functions and views
 *
 * Usage:
 *   npm run install-message-store
 *
 * Or with custom connection string:
 *   MESSAGE_STORE_CONNECTION_STRING=postgresql://... npm run install-message-store
 */

require('dotenv').config()
const { execSync } = require('child_process')
const path = require('path')
const fs = require('fs')

const connectionString = process.env.MESSAGE_STORE_CONNECTION_STRING

if (!connectionString) {
  console.error('ERROR: MESSAGE_STORE_CONNECTION_STRING environment variable is required')
  console.error('Example: MESSAGE_STORE_CONNECTION_STRING=postgresql://user:pass@host:5432/dbname npm run install-message-store')
  process.exit(1)
}

console.log('Installing Message DB schema...')
console.log('Connection string:', connectionString.replace(/:[^:@]+@/, ':****@'))

// Find the message-db installation script
const messageDbPath = path.join(__dirname, '../node_modules/@eventide/message-db')

if (!fs.existsSync(messageDbPath)) {
  console.error('ERROR: @eventide/message-db package not found')
  console.error('Run: npm install @eventide/message-db')
  process.exit(1)
}

const installScriptPath = path.join(messageDbPath, 'database', 'install.sh')

if (!fs.existsSync(installScriptPath)) {
  console.error('ERROR: install.sh script not found in @eventide/message-db package')
  process.exit(1)
}

try {
  // Parse connection string to extract database name
  const url = new URL(connectionString)
  const database = url.pathname.slice(1) // Remove leading /

  const dbPath = path.join(messageDbPath, 'database')

  // Set environment variables for psql connection
  const env = {
    ...process.env,
    PGHOST: url.hostname,
    PGPORT: url.port || '5432',
    PGUSER: url.username,
    PGPASSWORD: url.password,
    PGDATABASE: database,
    PGSSLMODE: 'require'
  }

  console.log('Installing message_store schema...')

  // Run SQL files in order (skip role creation for managed DB)
  const sqlFiles = [
    'extensions/pgcrypto.sql',
    'schema/message-store.sql',
    'types/message.sql',
    'tables/messages.sql'
  ]

  sqlFiles.forEach(file => {
    const filePath = path.join(dbPath, file)
    console.log(`  Installing ${file}...`)
    execSync(`psql -q -v ON_ERROR_STOP=1 -f "${filePath}"`, { env, stdio: 'inherit' })
  })

  // Install functions
  console.log('  Installing functions...')
  const functionsDir = path.join(dbPath, 'functions')
  const functions = fs.readdirSync(functionsDir).filter(f => f.endsWith('.sql'))
  functions.forEach(file => {
    execSync(`psql -q -v ON_ERROR_STOP=1 -f "${path.join(functionsDir, file)}"`, { env, stdio: 'pipe' })
  })

  // Install indexes
  console.log('  Installing indexes...')
  const indexesDir = path.join(dbPath, 'indexes')
  const indexes = fs.readdirSync(indexesDir).filter(f => f.endsWith('.sql'))
  indexes.forEach(file => {
    execSync(`psql -q -v ON_ERROR_STOP=1 -f "${path.join(indexesDir, file)}"`, { env, stdio: 'pipe' })
  })

  // Install views
  console.log('  Installing views...')
  const viewsDir = path.join(dbPath, 'views')
  const views = fs.readdirSync(viewsDir).filter(f => f.endsWith('.sql'))
  views.forEach(file => {
    execSync(`psql -q -v ON_ERROR_STOP=1 -f "${path.join(viewsDir, file)}"`, { env, stdio: 'pipe' })
  })

  console.log('✓ Message DB schema installed successfully')
  console.log('The message_store schema, tables, and functions are now available')
} catch (error) {
  console.error('ERROR: Failed to install Message DB schema')
  console.error(error.message)
  process.exit(1)
}
