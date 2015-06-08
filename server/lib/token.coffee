db = require('../helpers/db_connect_helper').db_connect()
fs = require 'fs'
permissions = {}
tokens = {}

productionOrTest = process.env.NODE_ENV is "production" or
    process.env.NODE_ENV is "test"


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
            callback null, true, username
        else
            callback null, false, username
    else
        callback null, false, null


## function checkDocType (docType, app, callback)
## @docType {String} document's docType that application want manage
## @name {String} application's name
## @callback {function} Continuation to pass control back to when complete.
## Check if application can manage docType
module.exports.checkDocType = (auth, docType, callback) ->
    # Check if application is authenticated

    if productionOrTest
        checkToken auth, (err, isAuthenticated, name) =>
            if isAuthenticated
                if docType?
                    docType = docType.toLowerCase()
                    # Check if application can manage docType
                    if permissions[name][docType]?
                        callback null, name, true
                    else if permissions[name]["all"]?
                        callback null, name, true
                    else
                        callback null, name, false
                else
                    callback null, name, true
            else
                callback null, false, false
    else
        checkToken auth, (err, isAuthenticated, name) ->
            name ?= 'unknown'
            callback null, name, true


## function checkProxy (auth, callback)
## @auth {String} Field 'authorization' i request header
##     Contains application name and password
## @callback {function} Continuation to pass control back to when complete.
## Check if application is proxy
## Useful for register and login requests
module.exports.checkProxyHome = (auth, callback) ->
    if productionOrTest
        if auth isnt "undefined" and auth?
            # Recover username and password in field authorization
            auth = auth.substr(5, auth.length - 1)
            auth = new Buffer(auth, 'base64').toString('ascii')
            username = auth.split(':')[0]
            password = auth.split(':')[1]
            # Check if application is cozy-proxy
            if password isnt undefined and tokens[username] is password
                if username is "proxy" or username is "home"
                    callback null, true
                else
                    callback null, false
            else
                callback null, false
        else
            callback null, false
    else
        callback null, true


## function updatePermissons (body, callback)
## @body {Object} application:
##   * body.password is application token
##   * body.name is application name
##   * body.permissions is application permissions
## @callback {function} Continuation to pass control back to when complete.
## Update application permissions and token
module.exports.updatePermissions = (body, callback) ->
    name = body.slug
    if productionOrTest
        if body.password?
            tokens[name] = body.password
        permissions[name] = {}
        if body.permissions?
            for docType, description of body.permissions
                permissions[name][docType.toLowerCase()] = description


## function initHomeProxy (callback)
## @callback {function} Continuation to pass control back to when complete
## Initialize tokens and permissions for Home and Proxy
initHomeProxy = (callback) ->
    token = process.env.TOKEN
    token = token.split('\n')[0]
    # Add home token and permissions
    tokens['home'] = token
    permissions.home =
        "application": "authorized"
        "notification": "authorized"
        "photo": "authorized"
        "file": "authorized"
        "background": "authorized"
        "folder": "authorized"
        "contact": "authorized"
        "album": "authorized"
        "event": "authorized"
        "message": "authorized"
        "binary": "authorized"
        "user": "authorized"
        "device": "authorized"
        "alarm": "authorized"
        "event": "authorized"
        "userpreference": "authorized"
        "cozyinstance": "authorized"
        "encryptedkeys": "authorized"
        "stackapplication": "authorized"
        "send mail to user": "authorized"
    # Add proxy token and permissions
    tokens['proxy'] = token
    permissions.proxy =
        "application": "authorized"
        "user": "authorized"
        "cozyinstance": "authorized"
        "device": "authorized"
        "usetracker": "authorized"
        "send mail to user": "authorized"
    callback null


## function initApplication (callback)
## @appli {Object} Application
## @callback {function} Continuation to pass control back to when complete
## Initialize tokens and permissions for application
initApplication = (appli, callback) ->
    name = appli.slug
    if appli.state is "installed"
        tokens[name] = appli.password
        if appli.permissions? and appli.permissions isnt null
            permissions[name] = {}
            for docType, description of appli.permissions
                docType = docType.toLowerCase()
                permissions[name][docType] = description
    callback null


## function init (callback)
## @callback {function} Continuation to pass control back to when complete.
## Initialize tokens which contains applications and their tokens
module.exports.init = (callback) ->
    # Read shared token
    if productionOrTest
        initHomeProxy () ->
            # Add token and permissions for other started applications
            db.view 'application/all', (err, res) ->
                if err then callback new Error("Error in view")
                else
                    # Search application
                    res.forEach (appli) ->
                        initApplication appli, () ->
                    callback tokens, permissions
    else
        callback tokens, permissions
