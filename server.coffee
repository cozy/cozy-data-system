application = module.exports = (callback) ->

    americano = require 'americano'
    initialize = require './server/initialize'

    options =
        name: 'data-system'
        port: process.env.PORT || 9101
        host: process.env.HOST || "127.0.0.1"
        root: __dirname

    americano.start options, (app, server) ->
        initialize app, server, callback

if not module.parent
    application()