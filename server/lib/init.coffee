log = require('printit')
    date: true
    prefix: 'lib/init'

db = require('../helpers/db_connect_helper').db_connect()
async = require 'async'
permissionsManager = require './token'
thumb = require('./thumb')
audio = require('./audio')
initTokens = require('./token').init


defaultPermissions =
    'File':
        'description' : 'Usefull to synchronize your files',
    'Folder':
        'description' : 'Usefull to synchronize your folder',
    'Notification':
        'description' : 'Usefull to synchronize your notification'
    'Binary':
        'description' : 'Usefull to synchronize your files'


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
        async.forEachSeries binaries, (binary, cb) ->
            log.info "Remove binary #{binary}"
            # Retrieve binary and remove it
            db.get binary, (err, doc) ->
                if not err and doc
                    db.remove doc._id, doc._rev, (err, doc) ->
                        log.error err if err
                        cb()
                else
                    log.error err if err
                    cb()
        , callback

# Patch 01/06/15
exports.addAccesses = (callback) ->
    addAccess = (docType, cb) ->
        db.view "#{docType}/all", (err, apps) ->
            return cb(err) if err? or apps.length is 0
            async.forEachSeries apps, (app, cb) ->
                # Check if access exists
                app = app.value
                db.view 'access/byApp', key:app._id, (err, accesses) ->
                    return cb(err) if err? or accesses.length > 0
                    if accesses?.length is 0
                        # Create it if necessary
                        if docType is "device"
                            app.permissions = defaultPermissions
                        permissionsManager.addAccess app, (err, access) ->
                            delete app.password
                            delete app.token
                            delete app.permissions
                            # Remove access information
                            # from application/device document
                            db.save app, (err, doc) ->
                                log.error err if err?
                                cb()
                    else
                        cb()
            , cb

    # Add access for all applications and devices
    addAccess 'application', (err) ->
        log.error err if err?
        addAccess 'device', (err) ->
            log.error err if err?
            # Initialize application access.
            initTokens (tokens, permissions) ->
                callback?()

# Add thumbs for images without thumb
exports.addThumbs = (callback) ->
    # Retrieve images without thumb
    db.view 'file/withoutThumb', (err, files) ->
        if err
            callback err
        else if files.length is 0
            callback()
        else
            async.forEach files, (file, cb) ->
                thumb.create file.id, false
                cb()
            , callback

# Add audio_metadata for audio without metadata
exports.addAudioMeta = (callback) ->
    # Retrieve images without thumb
    db.view 'file/withoutAudioMeta', (err, files) ->
        if err
            callback err
        else if files.length is 0
            callback()
        else
            async.forEach files, (file, cb) ->
                audio.create file.id, false
                cb()
            , callback

exports.removeDocWithoutDocType = (callback) ->
    db.view 'withoutDocType/all', (err, docs) ->
        if err
            callback err

        else if docs.length is 0
            callback()

        else
            async.forEachSeries docs, (doc, cb) ->
                # Create thumb
                db.remove doc.value._id, doc.value._rev, (err, doc) ->
                    log.error err if err
                    cb()
            , callback
