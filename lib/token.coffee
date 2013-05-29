db = require('../helpers/db_connect_helper').db_connect()
fs = require 'fs'


module.exports.checkToken = (auth, tokens, callback) ->
    if auth isnt "undefined" and auth?
        auth = auth.substr(5, auth.length - 1)
        auth = new Buffer(auth, 'base64').toString('ascii')
        console.log(auth)
        username = auth.split(':')[0]
        password = auth.split(':')[1]
        if password isnt undefined and tokens[username] is password
            console.log("application " + username + " is authenticated")
            callback null
        else
            console.log("Wrong authentication")
            console.log("Token expected : " + tokens[username])
            console.log("Token received : " + password)
            callback null
    else
        console.log "Warning : application is not authenticated : no field authorization"
        callback null

# Initialize tokens which contains applications and their tokens
module.exports.init = (app, callback) ->
    app.tokens = []    
    token = fs.readFileSync('/etc/cozy/tokens/data-system.token', 'utf8')
    token = token.split('\n')[0]
    app.tokens['home'] = token
    app.tokens['proxy'] = token
    db.view 'application/all', (err, res) ->
        if (err)
            callback new Error("Error in view")
        else 
            # Search application with token
            res.forEach (row) ->
                if row.state is "installed"
                    app.tokens[row.name] = row.password 
            callback app.tokens