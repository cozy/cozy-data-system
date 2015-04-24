log = require('printit')
    prefix: 'init'

module.exports = (app, server, callback) ->
    feed = require './lib/feed'
    feed.initialize server

    init = require './lib/init'
    init.removeLostBinaries (err) ->
        log.error err if err?
        # Patch: 24/03/15
        init.addAccesses (err) ->
            init.addThumbs (err) ->
                log.error err if err?
            callback app, server if callback?
