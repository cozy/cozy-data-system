express = require 'express'
RedisStore = require('connect-redis')(express)
cradle = require 'cradle'

try
    require "../../cozy-home/settings"
catch error
    global.secret_cookie_key = "secret"
    global.secret_session_key = "secret"


createDb = ->
    connection = new cradle.Connection
        cache: true,
        raw: false
    global.db = connection.database("cozy")
    db.exists (err, exists) ->
        if err
            console.log "error", err
        else if exists
            console.log "Database Cozy found."
        else
            console.log "database does not exists."
            db.create()

createBaseView
createDb()

app.configure ->
    cwd = process.cwd()
    
    app.enable 'coffee'
    app.use express.bodyParser()
    app.use express.cookieParser global.secret_cookie_key
    app.use express.session secret: global.secret_session_key, store: new RedisStore(db:'cozy')
    app.use express.methodOverride()
    app.use app.router

