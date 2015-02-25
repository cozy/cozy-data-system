module.exports = (app, server, callback) ->
    feed = require './lib/feed'
    feed.initialize server

    db = require './lib/db'
    db ->
        init = require './lib/init'
        init.removeLostBinaries (err) ->
            callback app, server if callback?
            console.log err if err?
