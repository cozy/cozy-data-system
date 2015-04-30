locker = require '../lib/locker'
db = require('../helpers/db_connect_helper').db_connect()
logger = require('printit')(prefix: 'middleware/utils')
async = require 'async'

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

# Get the permission for a post request in replication protocole
module.exports.checkPermissionsPostReplication = (req, res, next) ->
    if req.url is '/replication/_revs_diff'
        # Use to retrieve difference in documents revisions
        next()
    else if req.url is '/replication/_ensure_full_commit'
        # Use to ensure that every transferred bit is laid down
        # on disk or other persistent storage place
        next()

    else if req.url.indexOf('/replication/_changes') is 0
        # 
        next()
    else if req.url is '/replication/_bulk_docs'
        # Use to add/update/delete a document in replication
        async.forEach req.body.docs, (doc, cb) ->
            if doc._deleted
                # Document deletion:
                #   Get doc and check docType of current document
                db.get doc._id, (err, doc) ->
                    checkPermissions req, doc.docType, cb
            else
                checkPermissions req, doc.docType, cb
        , next
    else
        err = new Error "Forbidden operation"
        err.status = 403
        next err

# Get the permission for a get request in replication protocole
module.exports.checkPermissionsGetReplication = (req, res, next) ->
    # Format res.body :
    #   it should be as
    #       <id> --------
    #       Content-Type: application/json
    #           <doc>
    #       <id>
    body = res.body
    start = body.indexOf '{'
    end = body.lastIndexOf '}'
    body = body.substring(start, end + 1)
    body = JSON.parse body
    # Check if document in body has a docType
    if body and body.docType
        checkPermissions req, body.docType, (err) ->
            if err
                res.body = {}
                next err
            else
                res.set req.info[0]
                res.statusCode = req.info[1]
                res.send res.body
    else
        res.send res.body

# Get the permission for a put request in replication protocole
module.exports.checkPermissionsPutReplication = (req, res, next) ->
    if req.url.indexOf '/replication/_local' is 0 # ????
        # Use to save history replication
        # Local document aren't replicated
        next()
    else
        err = new Error "Forbidden operation"
        err.status = 403
        next err
