db = require('../helpers/db_connect_helper').db_connect()
fs = require 'fs'


## function checkToken (auth, tokens, callback)
## @auth {string} Field 'authorization' of request
## @tokens {tab} Tab which contains applications and their tokens
## @callback {function} Continuation to pass control back to when complete.
## Check if application is well authenticated
module.exports.checkToken = (auth, tokens, callback) ->
    if auth isnt "undefined" and auth?
        # Recover username and password in field authorization
        auth = auth.substr(5, auth.length - 1)
        auth = new Buffer(auth, 'base64').toString('ascii')
        username = auth.split(':')[0]
        password = auth.split(':')[1]
        # Check if application is well authenticated
        if password isnt undefined and tokens[username] is password
            console.log("application " + username + " is authenticated")
            callback null
        else
            console.log("Wrong authentication")
            console.log("Token expected : " + tokens[username])
            console.log("Token received : " + password)
            callback null
    else
        console.log "Warning : application is not authenticated : no field " +
            "authorization"
        callback null


## function init (app, callback)
## @app {Object} application DS, allows to acces variables environment of DS
## @callback {function} Continuation to pass control back to when complete.
## Initialize tokens which contains applications and their tokens
module.exports.init = (app, callback) ->
    app.tokens = []
    if process.env.NODE_ENV is "production"
        token = process.env.token
        token = token.split('\n')[0]
        app.tokens['home'] = token
        app.tokens['proxy'] = token
        db.view 'application/all', (err, res) ->
            if (err)
                callback new Error("Error in view application/all")
            else
                # Search application with token
                res.forEach (row) ->
                    if row.state is "installed"
                        app.tokens[row.name] = row.password
                callback app.tokens
