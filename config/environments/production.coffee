express = require 'express'
module.exports = (compound) ->
    app = compound.app
    app.configure 'production', ->
        app.set 'quiet', true
        app.use express.errorHandler

