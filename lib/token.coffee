db = require('../helpers/db_connect_helper').db_connect()
fs = require 'fs'

permissions = {}
tokens = {}


## function checkToken (auth, tokens, callback)
## @auth {string} Field 'authorization' of request
## @tokens {tab} Tab which contains applications and their tokens
## @callback {function} Continuation to pass control back to when complete.
## Check if application is well authenticated
checkToken = (auth, callback) ->
    if auth isnt "undefined" and auth?
        # Recover username and password in field authorization
        auth = auth.substr(5, auth.length - 1)
        auth = new Buffer(auth, 'base64').toString('ascii')
        username = auth.split(':')[0]
        password = auth.split(':')[1]
        # Check if application is well authenticated
        if password isnt undefined and tokens[username] is password
            console.log("application " + username + " is authenticated")
            callback null, true, username
        else
            console.log("Wrong authentication")
            console.log("Token expected : " + tokens[username])
            console.log("Token received : " + password)
            callback null, false, username
    else
        console.log "Warning : application is not authenticated : no field " +
            "authorization"
        callback null, false, null


## function checkDocType (docType, app, callback)
## @docType {String} document's docType that application want manage
## @name {String} application's name  
## @callback {function} Continuation to pass control back to when complete.
## Check if application can manage docType
module.exports.checkDocType = (auth, docType, callback) ->
    checkToken auth, (err, isAuthenticated, name) =>
        if isAuthenticated
            if docType?
                docType = docType.toLowerCase()
                if permissions[name][docType]?
                    console.log "#{name} is authorized to manage #{docType} "
                    callback null, true, true
                else
                    console.log "#{name} is NOT authorized to manage #{docType}"
                    callback null, true, false
            else
                console.log "document hasn't docType"
                callback null, true, true
        else 
            callback null, false

module.exports.checkProxy = (auth, callback) ->
    if auth isnt "undefined" and auth?
        # Recover username and password in field authorization
        auth = auth.substr(5, auth.length - 1)
        auth = new Buffer(auth, 'base64').toString('ascii')
        username = auth.split(':')[0]
        password = auth.split(':')[1]
        # Check if application is well authenticated
        if password isnt undefined and tokens[username] is password
            console.log("application " + username + " is authenticated but isn't authoried")
            if username is "proxy"
                callback null, true
            else
                callback null, false
        else
            console.log("Wrong authentication")
            console.log("Token expected : " + tokens[username])
            console.log("Token received : " + password)
            callback null, false
    else
        console.log "Warning : application is not authenticated : no field " +
            "authorization"
        callback null, false

module.exports.updatePermissions = (body, callback) ->
    if body.state is "installing"
        tokens[body.name] = body.password
        permissions[body.name] = {} 
        if body.permissions?
            for docType, description of body.permissions
                permissions[body.name][docType.toLowerCase()] = description
    else if body.state is "installed"
        permissions[body.name] = {} 
        if body.permissions?
            for docType, description of body.permissions
                permissions[body.name][docType.toLowerCase()] = description



## function init (app, callback)
## @app {Object} application DS, allows to acces variables environment of DS
## @callback {function} Continuation to pass control back to when complete.
## Initialize tokens which contains applications and their tokens
module.exports.init = (app, callback) ->
    token = fs.readFileSync('/etc/cozy/tokens/data-system.token', 'utf8')
    token = token.split('\n')[0]
    tokens['home'] = token
    permissions.home = 
        "application":
            "description": "description, application_home" 
        "notification":
            "description": "description, notification_home"
        "user":
            "description": "description, user_home"
        "alarm":
            "description": "description, alarm_home"
    tokens['proxy'] = token
    permissions.proxy =
        "user":
            "description": "description, user_proxy"
    db.view 'application/all', (err, res) ->
        if (err)
            callback new Error("Error in view")
        else 
            # Search application with token
            res.forEach (appli) ->
                if appli.state is "installed"
                    tokens[appli.name] = appli.password 
                    if appli.permissions? and appli.permissions isnt null
                        permissions[appli.name] = {}
                        for docType, description of appli.permissions
                            permissions[appli.name][docType.toLowerCase()] = description
            callback tokens, permissions