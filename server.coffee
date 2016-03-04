application = module.exports = (callback) ->

    americano = require 'americano'
    initialize = require './server/initialize'
    errorMiddleware = require './server/middlewares/errors'

    # Initialize database
    # * Create cozy database if not exists
    # * Add admin database if not exists
    # * Initialize request view (_design documents)
    # * Initialize application accesses
    db = require './server/lib/db'
    db ->
        options =
            name: 'data-system'
            port: process.env.PORT or 9101
            host: process.env.HOST or "127.0.0.1"
            root: __dirname

        # Start data-system server
        americano.start options, (err, app, server) ->
            app.use errorMiddleware

            setInterval ->
                console.log process.memoryUsage()
            , 2000
            # Clean lost binaries
            initialize app, server, callback

if not module.parent
    application()
