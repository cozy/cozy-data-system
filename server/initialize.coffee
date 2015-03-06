log = require('printit')
    prefix: 'init'

module.exports = (app, server, callback) ->
    feed = require './lib/feed'
    feed.initialize server

    db = require './lib/db'
    db ->
        init = require './lib/init'
        init.removeLostBinaries (err) ->
            log.error err if err?
            callback app, server if callback?
