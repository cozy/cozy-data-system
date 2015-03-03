log = require('printit')
    date: true
    prefix: 'lib/init'

db = require('../helpers/db_connect_helper').db_connect()
async = require 'async'
thumb = require('./thumb').create

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
                        keys.push doc.key
                    for binary in binaries
                        # Check if binary is linked to a document
                        unless binary.id in keys
                            lostBinaries.push binary.id
                    callback lostBinaries
                else
                    callback []
        else
            callback []

# Remove binaries not linked with a document
exports.removeLostBinaries = (callback) ->
    # Recover all lost binaries
    getLostBinaries (binaries) ->
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
        if not err and files.length > 0
            async.forEachSeries files, (file, cb) =>
                # Create thumb
                db.get file.id, (err, file) ->
                    thumb file, cb
            , callback
        else
            callback()