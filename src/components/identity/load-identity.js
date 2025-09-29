/***
 * Excerpted from "Practical Microservices",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material,
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose.
 * Visit https://pragprog.com/titles/egmicro for more book information.
***/
const identityProjection = {
  $init () {
    return {
      id: null,
      email: null,
      isRegistered: false,
      registrationEmailSent: false
    }
  },
  Registered (identity, registered) {
    identity.id = registered.data.userId
    identity.email = registered.data.email
    identity.isRegistered = true

    return identity
  },
  RegistrationEmailSent (identity) {
    identity.registrationEmailSent = true

    return identity
  }
}

/**
 * @description Fetches the identity fround in `context.identityStream`
 * @param {object} context
 * @param {object} context.messageStore A reference to the Message Store
 * @param {object} context.identityId The id of the identiy we're loading
 * @returns {Promise<object>} A promise that resolves to the new action context
 */
function loadIdentity (context) {
  const { identityId, messageStore } = context
  const identityStreamName = `identity-${identityId}`

  return messageStore
    .fetch(identityStreamName, identityProjection)
    .then(identity => {
      context.identity = identity

      return context
    })
}

module.exports = loadIdentity
