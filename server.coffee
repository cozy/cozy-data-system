log = require('printit')
    prefix: 'Cozy Data System (dev mode)'
    date: true


startPouchDB = (callback) ->
    express = require('express')
    app     = express()
    PouchDB = require('pouchdb')
    app.use('/', require('express-pouchdb')(PouchDB))
    app.listen 5984, callback


application = module.exports = (opts, callback) ->
    opts ?= {}
    root = opts.root or __dirname
    process.env.INDEXES_PATH = root

    americano = require 'americano'
    initialize = require './server/initialize'
    errorMiddleware = require './server/middlewares/errors'

    startPouchDB (err) ->
        if err
            log.error "Something, went wrong, it cannot start PouchDB server."
            log.error err

        else
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
                    root: root

                # Start data-system server
                americano.start options, (err, app, server) ->
                    app.use errorMiddleware
                    # Clean lost binaries
                    initialize app, server, callback


if not module.parent
    application()
