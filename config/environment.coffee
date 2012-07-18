express = require 'express'
RedisStore = require('connect-redis')(express)

try
    require "../../cozy-home/settings"
catch error
    global.secret_cookie_key = "secret"
    global.secret_session_key = "secret"


passport = require 'passport'

app.configure ->
    cwd = process.cwd()
    
    app.enable 'coffee'
    app.use express.bodyParser()
    app.use express.cookieParser global.secret_cookie_key
    app.use express.session secret: global.secret_session_key, store: new RedisStore(db:'cozy')
    app.use express.methodOverride()
    app.use app.router

