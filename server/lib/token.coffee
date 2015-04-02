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

checkAccess = (app, cb) ->
    if app.access
        cb app.access
    else if app._id
        db.view 'access/byApplication', key:app._id, (err, body) ->
            if body.length > 0
                cb body[0].value
            else
                cb false
    else
        cb false

# Add access for application
module.exports.addApplicationAccess = (application, callback) ->
    checkAccess application, (access) ->
        if access
            application.access = access
            db.get access, (err, doc) ->
                delete permissions[doc.login]
                delete tokens[doc.login]
                doc.login = application.slug
                doc.token = application.password if application.password?
                doc.permissions = application.permissions
                db.save doc._id, doc, (err, body) ->
                    log.error err if err?
                    delete application.password
                    updatePermissions doc, () ->
                        callback null, application if callback?
        else
            access =
                docType: "Access"
                login: application.slug
                token: application.password
                permissions: application.permissions
            db.save access, (err, doc) ->
                log.error err if err?
                application.access = doc._id
                delete application.password
                updatePermissions access, () ->
                    callback null, application if callback?

# Add access for device
module.exports.addDeviceAccess = (device, callback) ->
    if device.type is "desktop"
        defaultPermissions =
            file: "Should access to file to synchronize it"
            folder: "Should access to folder to synchronize it"
            binary: "Should access to file contents"
    else
        defaultPermissions =
            file: "Should access to file to synchronize it"
            folder: "Should access to folder to synchronize it"
            binary: "Should access to file contents"
            notification: "Should access to notification to synchronize it"
            contact: "Should access to contact to synchronize it"
    checkAccess device, (acces)->
    if access
        device.access = access
        db.get access, (err, doc) ->
            delete permissions[doc.login]
            delete tokens[doc.login]
            doc.login = device.login
            doc.token = device.password
            doc.permissions = device.permissions or defaultPermissions
            permissions:
                file: "Should access to file to synchronize it"
                folder: "Should access to folder to synchronize it"
                notification: "Should access to notification to synchronize it"
                contact: "Should access to contact to synchronize it"
            db.save doc, (err, doc) ->
            log.error err if err?
            delete device.password
            updatePermissions access, () ->
                callback null, device
    else
        access =
            docType: "Access"
            login: device.login
            token: device.password
        access.permissions = device.permissions or defaultPermissions
        db.save access, (err, doc) ->
            log.error err if err?
            device.access = doc._id
            delete device.password
            updatePermissions access, () ->
                callback null, device


module.exports.removeAccess = (app, callback) ->
    if productionOrTest and app.access?
        db.get app.access, (err, doc) ->
            delete permissions[doc.login]
            delete tokens[doc.login]
            db.remove app.access, callback





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
    tokens[access] = access.token
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
        initHomeProxy () ->
            # Add token and permissions for other started applications
            db.view 'access/all', (err, accesses) ->
                return callback new Error("Error in view") if err?
                # Search application
                accesses.forEach (access) ->
                    initAccess access, () ->
                callback tokens, permissions
    else
        callback tokens, permissions
