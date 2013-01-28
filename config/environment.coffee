module.exports = (compound) ->
    express = require 'express'
    app = compound.app

        
    app.configure ->
        app.enable 'coffee'

        app.use express.bodyParser(keepExtensions: true)
        app.use express.methodOverride()
        app.use app.router
