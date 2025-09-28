/***
 * Excerpted from "Practical Microservices",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material,
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose.
 * Visit http://www.pragmaticprogrammer.com/titles/egmicro for more book information.
***/
/* The system makes heavy use of dependency injection.  This file wires up all the
 * dependencies, making use of the environment.
 */
const createKnexClient = require('./knex-client') 
const createHomeApp = require('./app/home')

const createRecordViewingsApp = require('./app/record-viewings') 

const createPostgresClient = require('./postgres-client') 
const createMessageStore = require('./message-store')

const createHomePageAggregator = require('./aggregators/home-page')

function createConfig({ env }) {
  const knexClient = createKnexClient({
    connectionString: env.databaseUrl
  })
  const postgresClient = createPostgresClient({ 
    connectionString: env.messageStoreConnectionString
  })
  const messageStore = createMessageStore({ db: postgresClient })

  const homeApp = createHomeApp({ db: knexClient })
  const recordViewingsApp = createRecordViewingsApp({ messageStore })

  const homePageAggregator = createHomePageAggregator({
    db: knexClient,
    messageStore
  })

  const aggregators = [
    homePageAggregator
  ]

  const components = []

  return {
    env,
    knexClient,
    postgresClient,
    messageStore,
    homeApp,
    recordViewingsApp,
    homePageAggregator,
    aggregators,
    components,
  }
}

module.exports = createConfig
