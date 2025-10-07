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

const installScriptPath = path.join(messageDbPath, 'install.sh')

if (!fs.existsSync(installScriptPath)) {
  console.error('ERROR: install.sh script not found in @eventide/message-db package')
  process.exit(1)
}

try {
  // Make script executable
  fs.chmodSync(installScriptPath, '755')

  // Run the installation script
  console.log('Running Message DB installation script...')
  execSync(`DATABASE_URL="${connectionString}" bash "${installScriptPath}"`, {
    stdio: 'inherit',
    cwd: messageDbPath
  })

  console.log('✓ Message DB schema installed successfully')
  console.log('The message_store schema, tables, and functions are now available')
} catch (error) {
  console.error('ERROR: Failed to install Message DB schema')
  console.error(error.message)
  process.exit(1)
}
