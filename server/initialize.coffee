module.exports = (app, server, callback) ->
    feed = require './helpers/db_feed_helper'
    feed.initialize server

    db = require './lib/db'
    db -> callback app, server if callback?
