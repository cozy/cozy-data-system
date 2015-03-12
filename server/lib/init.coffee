log = require('printit')
    date: true
    prefix: 'lib/init'

db = require('../helpers/db_connect_helper').db_connect()
async = require 'async'

# Get all lost binaries
#    A binary is considered as lost when isn't linked to a document.
getLostBinaries = exports.getLostBinaries = (callback) ->
    lostBinaries = []
    # Recover all binaries
    db.view 'binary/all', (err, binaries) ->
        if not err and binaries.length > 0
            # Recover all binaries linked to a/several document(s)
            db.view 'binary/byDoc', (err, docs) ->
                if not err and docs?
                    keys = []
                    for doc in docs
                        keys[doc.key] = true
                    for binary in binaries
                        # Check if binary is linked to a document
                        unless keys[binary.id]?
                            lostBinaries.push binary.id
                    callback null, lostBinaries
                else
                    callback null, []
        else
            callback err, []

# Remove binaries not linked with a document
exports.removeLostBinaries = (callback) ->
    # Recover all lost binaries
    getLostBinaries (err, binaries) ->
        return callback err if err?
        async.forEachSeries binaries, (binary, cb) =>
            log.info "Remove binary #{binary}"
            # Retrieve binary and remove it
            db.get binary, (err, doc) =>
                if not err and doc
                    db.remove doc._id, doc._rev, (err, doc) =>
                        log.error err if err
                        cb()
                else
                    log.error err if err
                    cb()
        , callback

# 13/03/2015: patch to add permissions to devices
exports.addPermissionsToDevice = (callback) ->
    db.view 'device/all', (err, devices) ->
        if not err and devices.length > 0
            async.forEach devices, (device, cb) ->
                unless device.permissions?
                    device.permissions =
                        file: "Should access to file to synchronize it"
                        folder: "Should access to folder to synchronize it"
                        notification: "Should access to notification to synchronize it"
                    db.save device, (err, doc) ->
                        cb(err)
            , callback
        else
            callback err