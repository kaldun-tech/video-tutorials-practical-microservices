/***
 * Excerpted from "Practical Microservices",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material,
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose.
 * Visit https://pragprog.com/titles/egmicro for more book information.
***/
const writeFunctionSql =
  'SELECT message_store.write_message($1, $2, $3, $4, $5, $6)'
const VersionConflictError = require('./version-conflict-error')
const versionConflictErrorRegex = /^Wrong.*Stream Version: (\d+)\)/

function createWrite ({ db }) {
  return (streamName, message, expectedVersion) => {
    if (!message.type) {
      throw new Error('Messages must have a type')
    }

    const values = [
      message.id,
      streamName,
      message.type,
      message.data,
      message.metadata,
      expectedVersion
    ]

    return db.query(writeFunctionSql, values)
      .catch(err => {
        const errorMatch = err.message.match(versionConflictErrorRegex)
        const notVersionConflict = errorMatch === null

        if (notVersionConflict) {
          throw err
        }

        const actualVersion = parseInt(errorMatch[1], 10)

        const versionConflictError = new VersionConflictError(
          streamName,
          actualVersion,
          expectedVersion
        )
        versionConflictError.stack = err.stack

        throw versionConflictError
      })
  }
}

module.exports = createWrite
