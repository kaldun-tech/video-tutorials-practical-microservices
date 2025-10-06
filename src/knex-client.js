/***
 * Excerpted from "Practical Microservices",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material,
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose.
 * Visit http://www.pragmaticprogrammer.com/titles/egmicro for more book information.
***/
const Bluebird = require('bluebird')
const knex = require('knex')

function createKnexClient ({ connectionString, migrationsTableName }) {
  // Parse connection string to handle SSL properly
  const url = new URL(connectionString)

  // Remove sslmode parameter if present (we'll handle SSL via config)
  url.searchParams.delete('sslmode')

  // Create knex client with SSL configuration
  const client = knex({
    client: 'postgresql',
    connection: {
      connectionString: url.toString(),
      ssl: { rejectUnauthorized: false }
    }
  })

  const migrationOptions = {
    tableName: migrationsTableName || 'knex_migrations'
  }

  // Wrap in Bluebird.resolve to guarantee a Bluebird Promise down the chain
  return Bluebird.resolve(client.migrate.latest(migrationOptions))
    .then(() => client)
}

module.exports = createKnexClient
