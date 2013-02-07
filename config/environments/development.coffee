express = require 'express'
module.exports = (compound) ->
    app = compound.app
    app.configure 'development', ->
        app.enable 'log actions'
        app.enable 'env info'
        app.disable 'watch'
        app.use express.errorHandler
            dumpExceptions: true, showStack: true
