db = require('../helpers/db_connect_helper').db_connect()
fs = require 'fs'
log = require('printit')
    prefix: 'token'
permissions = {}
tokens = {}

productionOrTest = process.env.NODE_ENV in ['production', 'test']

## function checkToken (auth, tokens, callback)
## @auth {string} Field 'authorization' of request
## @tokens {tab} Tab which contains applications and their tokens
## @callback {function} Continuation to pass control back to when complete.
## Check if application is well authenticated
checkToken = (auth) ->
    if auth isnt "undefined" and auth?
        # Recover username and password in field authorization
        auth = auth.substr(5, auth.length - 1)
        auth = new Buffer(auth, 'base64').toString('ascii')
        username = auth.split(':')[0]
        password = auth.split(':')[1]
        # Check if application is well authenticated
        if password isnt undefined and tokens[username] is password
            return [null, true, username]
        else
            return [null, false, username]
    else
        return [null, false, null]


## function checkDocType (docType, app, callback)
## @docType {String} document's docType that application want manage
## @name {String} application's name
## @callback {function} Continuation to pass control back to when complete.
## Check if application can manage docType
module.exports.checkDocType = (auth, docType, callback) ->
    # Check if application is authenticated

    if productionOrTest
        [err, isAuthenticated, name] = checkToken auth
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
        [err, isAuthenticated, name] = checkToken auth
        name ?= 'unknown'
        callback null, name, true

## function checkDocType (docType, app, callback)
## @docType {String} document's docType that application want manage
## @name {String} application's name
## @callback {function} Continuation to pass control back to when complete.
## Check if application can manage docType
module.exports.checkDocTypeSync = (auth, docType) ->
    # Check if application is authenticated

    if productionOrTest
        [err, isAuthenticated, name] = checkToken auth
        if isAuthenticated
            if docType?
                docType = docType.toLowerCase()
                # Check if application can manage docType
                if permissions[name][docType]?
                    return [null, name, true]
                else if permissions[name]["all"]?
                    return [null, name, true]
                else
                    return [null, name, false]
            else
                return [null, name, true]
        else
            return [null, false, false]
    else
        [err, isAuthenticated, name] = checkToken auth
        name ?= 'unknown'
        return [null, name, true]

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
updatePermissions = (access, callback) ->
    login = access.login
    if productionOrTest
        if access.token?
            tokens[login] = access.token
        permissions[login] = {}
        if access.permissions?
            for docType, description of access.permissions
                permissions[login][docType.toLowerCase()] = description
        callback() if callback?
    else
        callback() if callback?


## function addAccess (doc, callback)
## @doc {Object} application/device:
##   * doc.password is application token
##   * doc.slug/doc.login is application name
##   * doc.permissions is application permissions
##   * doc.id/doc._id is application id
## @callback {function} Continuation to pass control back to when complete.
## Add access for application or device
addAccess = module.exports.addAccess = (doc, callback) ->
    # Create access
    access =
        docType: "Access"
        login: doc.slug or doc.login
        token: doc.password
        app: doc.id or doc._id
        permissions: doc.permissions
    db.save access, (err, doc) ->
        log.error err if err?
        # Update permissions in RAM
        updatePermissions access, ->
            callback null, access if callback?

## function updateAccess (doc, callback)
## @id {String} access id for application
## @doc {Object} application/device:
##   * doc.password is new application token
##   * doc.slug/doc.login is new application name
##   * doc.permissions is new application permissions
## @callback {function} Continuation to pass control back to when complete.
## Update access for application or device
module.exports.updateAccess = (id, doc, callback) ->
    db.view 'access/byApp', key:id, (err, accesses) ->
        if accesses.length > 0
            access = accesses[0].value
            # Delete old access
            delete permissions[access.login]
            delete tokens[access.login]
            # Create new access
            access.login = doc.slug or access.login
            access.token = doc.password or access.token
            access.permissions = doc.permissions or access.permissions
            db.save access._id, access, (err, body) ->
                log.error err if err?
                # Update permissions in RAM
                updatePermissions access, ->
                    callback null, access if callback?
        else
            addAccess doc, callback

## function removeAccess (doc, callback)
## @doc {Object} access to remove
## @callback {function} Continuation to pass control back to when complete.
## Remove access for application or device
module.exports.removeAccess = (doc, callback) ->
    db.view 'access/byApp', key:doc._id, (err, accesses) ->
        return callback err if err? and callback?
        if accesses.length > 0
            access = accesses[0].value
            delete permissions[access.login]
            delete tokens[access.login]
            db.remove access._id, access._rev, (err) ->
                callback err if callback?
        else
            callback() if callback?

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
        "access": "authorized"
        "notification": "authorized"
        "photo": "authorized"
        "file": "authorized"
        "background": "authorized"
        "folder": "authorized"
        "contact": "authorized"
        "album": "authorized"
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
        "send mail from user": "authorized"
    # Add proxy token and permissions
    tokens['proxy'] = token
    permissions.proxy =
        "access": "authorized"
        "application": "authorized"
        "user": "authorized"
        "cozyinstance": "authorized"
        "device": "authorized"
        "usetracker": "authorized"
        "send mail to user": "authorized"
    callback null


## function initAccess (callback)
## @access {Object} Access
## @callback {function} Continuation to pass control back to when complete
## Initialize tokens and permissions for all accesses (applications or devices)
initAccess = (access, callback) ->
    name = access.login
    tokens[name] = access.token
    if access.permissions? and access.permissions isnt null
        permissions[name] = {}
        for docType, description of access.permissions
            docType = docType.toLowerCase()
            permissions[name][docType] = description
    callback null

## function init (callback)
## @callback {function} Continuation to pass control back to when complete.
## Initialize tokens which contains applications and their tokens
module.exports.init = (callback) ->
    # Read shared token
    if productionOrTest
        initHomeProxy ->
            # Add token and permissions for other started applications
            db.view 'access/all', (err, accesses) ->
                return callback new Error("Error in view") if err?
                # Search application
                accesses.forEach (access) ->
                    initAccess access, ->
                callback tokens, permissions
    else
        callback tokens, permissions

