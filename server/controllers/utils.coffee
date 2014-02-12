locker = require '../lib/locker'
db = require('../helpers/db_connect_helper').db_connect()

# Helpers
helpers = require '../helpers/utils'
checkPermissions = helpers.checkPermissions
deleteFiles = helpers.deleteFiles

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