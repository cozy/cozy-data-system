module.exports = (app, server, callback) ->
    feed = require './lib/feed'
    feed.initialize server

    db = require './lib/db'
    db ->
        callback app, server if callback?
        init = require './lib/init'
        init.removeLostBinaries (err) ->
            console.log err if err?
