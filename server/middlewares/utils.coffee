locker = require '../lib/locker'
db = require('../helpers/db_connect_helper').db_connect()
logger = require('printit')(prefix: 'middleware/utils')

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
        if err
            logger.error err
            deleteFiles req.files # for binaries management
            next err
        else if doc?
            req.doc = doc
            next()
        else
            deleteFiles req.files # for binaries management
            next errors.http 404, 'Not found'

# For arbitrary stuff like "send mail to user"
module.exports.checkPermissionsFactory = (permission) -> (req, res, next) ->
    checkPermissions req, permission, next

# Get the permission from a retrieved document.
# Required to be processed after "get doc"
module.exports.checkPermissionsByDoc = (req, res, next) ->
    checkPermissions req, req.doc.docType, next

# Get the permission from the request's body
module.exports.checkPermissionsByBody = (req, res, next) ->
    checkPermissions req, req.body.docType, next

# Get the permission from the request's params
module.exports.checkPermissionsByType = (req, res, next) ->
    checkPermissions req, req.params.type, next
