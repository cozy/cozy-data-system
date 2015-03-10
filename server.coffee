application = module.exports = (callback) ->

    americano = require 'americano'
    initialize = require './server/initialize'
    errorMiddleware = require './server/middlewares/errors'


    db = require './server/lib/db'
    db ->
        options =
             name: 'data-system'
             port: process.env.PORT or 9101
             host: process.env.HOST or "127.0.0.1"
             root: __dirname

        americano.start options, (app, server) ->
            app.use errorMiddleware
            initialize app, server, callback

if not module.parent
    application()