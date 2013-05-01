express = require 'express'
module.exports = (compound) ->
    app = compound.app
    app.configure 'production', ->
        app.enable 'log actions'
        app.enable 'env info'
        app.set 'quiet', true
        app.enable 'watch'
        app.use express.errorHandler
            dumpExceptions: true, showStack: true

