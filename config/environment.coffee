express = require 'express'

app.configure ->
    cwd = process.cwd()
    
    app.enable 'coffee'
    app.use express.bodyParser()
    app.use express.methodOverride()
    app.use app.router

