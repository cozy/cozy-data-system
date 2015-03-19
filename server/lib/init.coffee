log = require('printit')
    date: true
    prefix: 'lib/init'

db = require('../helpers/db_connect_helper').db_connect()
async = require 'async'
thumb = require('./thumb')

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

# Add thumbs for images without thumb
exports.addThumbs = (callback) ->
    # Retrieve images without thumb
    db.view 'file/withoutThumb', (err, files) ->
        if err
            callback err

        else if files.length is 0
            callback()

        else
            async.forEachSeries files, (file, cb) =>
                # Create thumb
                db.get file.id, (err, file) =>
                    if err
                        log.info "Cant get File #{file.id} for thumb"
                        log.info err
                        return cb()
                    thumb.create file, false
                    cb()
            , callback
