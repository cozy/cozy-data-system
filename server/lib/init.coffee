
log = require('printit')
    date: true
    prefix: 'lib/init'

db = require('../helpers/db_connect_helper').db_connect()
async = require 'async'


# Remove binaries not linked with a document
exports.removeLostBinaries = (callback) ->
    # Recover all binaries
    db.view 'binary/all', (err, binaries) =>
        if not err and binaries.length > 0
            async.forEachSeries binaries, (binary, cb) ->
                # Check if binary is linked to a document
                db.view 'binary/byDoc', key: binary.id, (err, doc) =>
                    if not err and doc.length is 0
                        log.info "Remove binary #{binary.id}"
                        # Retrieve binary and remove it
                        db.get binary.id, (err, doc) =>
                            if not err and doc
                                db.remove doc._id, doc._rev, (err, doc) =>
                                    log.error err if err
                    cb()
            , callback
        else
            log.error err if err?
            callback err