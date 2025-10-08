/***
 * Excerpted from "Practical Microservices",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material,
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose.
 * Visit https://pragprog.com/titles/egmicro for more book information.
***/
const test = require('blue-tape')
const uuid = require('uuid').v4

const { config, reset } = require('../test-helper')

test('It aggregates a VideoViewed event', t => {
  const userId = uuid()
  const videoId = uuid()
  const videoViewedEvent = {
    id: uuid(),
    type: 'VideoViewed',
    metdata: {
      traceId: uuid(),
      userId: uuid()
    },
    data: {
      userId,
      videoId
    },
    globalPosition: 1
  }

  return (
    reset()
      .then(() => config.homePageAggregator.init())
      .then(() =>
        config.homePageAggregator.handlers.VideoViewed(videoViewedEvent)
      )
      // Call it a second time to verify idempotence
      .then(() =>
        config.homePageAggregator.handlers.VideoViewed(videoViewedEvent)
      )
      .then(() =>
        config.db.then(client =>
          client('pages')
            .where({ page_name: 'home' })
            .then(homePageData => {
              t.ok(homePageData, 'Got the home page data')

              t.equal(
                homePageData[0].page_data.videosWatched,
                1,
                'Even though we see the event twice, there is still only 1'
              )
            })
        )
      )
  )
})
