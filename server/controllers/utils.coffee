fs = require 'fs'
locker = require '../lib/locker'
feed = require '../helpers/db_feed_helper'
db = require('../helpers/db_connect_helper').db_connect()
checkDocType = require('../lib/token').checkDocType

###

    MIDDLEWARES

###

# Lock document to avoid multiple modifications at the same time.
module.exports.lockRequest = (req, res, next) ->

    # depending on if we lock a document or a request
    req.lock = req.params.id or req.params.type

    locker.runIfUnlock req.lock, ->
        locker.addLock req.lock
        next()

# Unlock document when action is finished
module.exports.unlockRequest = (req, res) -> locker.removeLock req.lock

# Recover document from database with id equal to params.id
module.exports.getDoc = (req, res, next) ->
    db.get req.params.id, (err, doc) ->
        if err? and err.error is "not_found"
            locker.removeLock req.lock
            deleteFiles req.files # for binaries management
            res.send 404, error: err.error
        else if err?
            console.log "[Get doc] err: " + JSON.stringify err
            locker.removeLock req.lock
            deleteFiles req.files # for binaries management
            res.send 500, error: err
        else if doc?
            req.doc = doc
            next()
        else
            locker.removeLock req.lock
            deleteFiles req.files # for binaries management
            res.send 404, error: "not found"

# For arbitrary stuff like "send mail to user"
module.exports.checkPermissionsFactory = (permission) -> (req, res, next) ->
    checkPermissions permission, req.header('authorization'), res, next

# Get the permission from a retrieved document.
# Required to be processed after "get doc"
module.exports.checkPermissionsByDoc = (req, res, next) ->
    checkPermissions req.doc.docType, req.header('authorization'), res, next

# Get the permission from the request's body
module.exports.checkPermissionsByBody = (req, res, next) ->
    checkPermissions req.body.docType, req.header('authorization'), res, next

# Get the permission from the request's params
module.exports.checkPermissionsByType = (req, res, next) ->
    checkPermissions req.params.type, req.header('authorization'), res, next

###

    HELPERS

###

# Delete files on the file system
deleteFiles = module.exports.deleteFiles = (files) ->
    if files? and Object.keys(files).length > 0
        fs.unlinkSync file.path for key, file of files

# Check the application has the permissions to access the route
checkPermissions = module.exports.checkPermissions = \
(permission, auth, res, next) ->
    checkDocType auth, permission, (err, appName, isAuthorized) ->
        if not appName
            err = new Error "Application is not authenticated"
            res.send 401, error: err.message
        else if not isAuthorized
            err = new Error "Application is not authorized"
            res.send 403, error: err.message
        else
            feed.publish 'usage.application', appName
            next()