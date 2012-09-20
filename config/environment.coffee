express = require 'express'

app.configure ->
    cwd = process.cwd()
    
    app.enable 'coffee'

    app.use express.bodyParser(keepExtensions: true)
    app.use express.methodOverride()
    app.use app.router

