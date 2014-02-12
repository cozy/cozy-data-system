fs = require 'fs'
locker = require '../lib/locker'
db = require('../helpers/db_connect_helper').db_connect()

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

###

    HELPERS

###

# Delete files on the file system
deleteFiles = module.exports.deleteFiles = (files) ->
    if files? and Object.keys(files).length > 0
        fs.unlinkSync file.path for key, file of files
