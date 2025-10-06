// Knex configuration file for running migrations
// This uses the DATABASE_URL environment variable to connect

require('dotenv').config()
const fs = require('fs')
const path = require('path')
const os = require('os')

// SSL configuration for DigitalOcean managed databases
// DigitalOcean uses self-signed certificates that Node.js doesn't trust by default
// For secure encrypted connections, we use rejectUnauthorized: false
// The connection is still encrypted with TLS, just not certificate-verified
const sslConfig = { rejectUnauthorized: false }

// Note: If you need strict certificate validation, you can set:
// - NODE_EXTRA_CA_CERTS environment variable to point to ca-certificate.crt
// - Or use rejectUnauthorized: true with ca: fs.readFileSync('path/to/ca-cert.crt')
// However, DigitalOcean's CA certificates may still fail Node's validation

// Modify connection string to remove sslmode parameter (we'll handle SSL via config)
let connectionString = process.env.DATABASE_URL
if (connectionString) {
  // Parse the URL to handle query parameters properly
  const url = new URL(connectionString)

  // Remove sslmode parameter
  url.searchParams.delete('sslmode')

  // Reconstruct the connection string
  connectionString = url.toString()
}

// When using connection string, SSL must be embedded in the connection object
const connectionConfig = {
  connectionString: connectionString,
  ssl: sslConfig
}

module.exports = {
  development: {
    client: 'postgresql',
    connection: connectionConfig,
    pool: {
      min: 2,
      max: 10
    },
    migrations: {
      tableName: 'knex_migrations',
      directory: './migrations'
    }
  },

  staging: {
    client: 'postgresql',
    connection: connectionConfig,
    pool: {
      min: 2,
      max: 10
    },
    migrations: {
      tableName: 'knex_migrations',
      directory: './migrations'
    }
  },

  production: {
    client: 'postgresql',
    connection: connectionConfig,
    pool: {
      min: 2,
      max: 10
    },
    migrations: {
      tableName: 'knex_migrations',
      directory: './migrations'
    }
  }
}
