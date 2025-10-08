/***
 * Excerpted from "Practical Microservices",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material,
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose.
 * Visit https://pragprog.com/titles/egmicro for more book information.
***/
const Bluebird = require('bluebird')
const pg = require('pg')

function createDatabase ({ connectionString }) {
  // Parse connection string to handle SSL properly
  const url = new URL(connectionString)

  // Remove sslmode and ssl parameters if present (we'll handle SSL via config)
  url.searchParams.delete('sslmode')
  url.searchParams.delete('ssl')

  // Detect if we need SSL based on connection string
  // Use SSL for remote connections, skip for localhost
  const isLocalhost = connectionString.includes('localhost') ||
                      connectionString.includes('127.0.0.1') ||
                      connectionString.includes('@localhost:') ||
                      connectionString.includes('@127.0.0.1:')

  const useSSL = !isLocalhost

  const clientConfig = {
    connectionString: url.toString(),
    Promise: Bluebird
  }

  if (useSSL) {
    clientConfig.ssl = { rejectUnauthorized: false }
  }

  const client = new pg.Client(clientConfig)

  let connectedClient = null

  function connect () {
    if (!connectedClient) {
      connectedClient = client.connect()
        .then(() => client.query('SET search_path = message_store, public'))
        .then(() => client)
    }

    return connectedClient
  }

  function query (sql, values = []) {
    return connect()
      .then(client => client.query(sql, values))
  }

  return {
    query,
    stop: () => client.end()
  }
}

module.exports = createDatabase
