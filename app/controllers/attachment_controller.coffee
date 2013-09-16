load 'application'

fs = require "fs"
db = require('./helpers/db_connect_helper').db_connect()
checkPermissions = require('./lib/token').checkDocType


## Helpers

# TODO: make it recursive
deleteFiles = (req, callback) ->
    i = 0
    lasterr = null
    for key, file of req.files
        i++
        fs.unlink file.path, (err) ->
            i--
            lasterr ?= err

            if i is 0
                console.log lasterr if lasterr
                callback lasterr
    if i is 0
        callback()


## Before and after methods

# Lock document to avoid multiple modifications at the same time.
before 'lock request', ->
    @lock = "#{params.id}"

    app.locker.runIfUnlock @lock, =>
        app.locker.addLock(@lock)
        next()
, only: ['addAttachment', 'removeAttachment']

# Unlock document when action is finished
after 'unlock request', ->
    app.locker.removeLock @lock
, only: ['addAttachment', 'removeAttachment']

# Recover document from database with id equal to params.id
before 'get doc', ->
    db.get params.id, (err, doc) =>
        if err and err.error == "not_found"
            app.locker.removeLock @lock
            deleteFiles req, -> send 404
        else if err
            console.log "[Attachment] err: " + JSON.stringify err
            app.locker.removeLock @lock
            deleteFiles req, -> send 500
        else if doc?
            @doc = doc
            next()
        else
            app.locker.removeLock @lock
            deleteFiles req, -> send 404

# Check if application is authorized to manage docType
# docType corresponds to docType of recovered document from database
# Required to be processed after "get doc"
before 'permissions', ->
    auth = req.header('authorization')
    checkPermissions auth, @doc.docType, (err, appName, isAuthorized) =>
        compound.app.feed.publish 'usage.application', appName
        next()
, only: ['addAttachment','getAttachment','removeAttachment']


## Actions

# POST /data/:id/attachments/
action 'addAttachment', ->
    if req.files["file"]?
        file = req.files["file"]
        if body.name? then name = body.name else name = file.name

        fileData =
            name: name
            "content-type": file.type

        stream = db.saveAttachment @doc, fileData, (err, res) ->
            if err
                console.log "[Attachment] err: " + JSON.stringify err
                deleteFiles req, -> send 500
            else
                deleteFiles req, -> send 201

        fs.createReadStream(file.path).pipe(stream)

    else
        console.log "no doc for attachment"

        send error: true, msg: "No file send", 400


# GET /data/:id/attachments/:name
action 'getAttachment', ->
    name = params.name

    stream = db.getAttachment @doc.id, name, (err) ->
        if err and err.error = "not_found"
            send 404
        else if err
            send 500
        else
            send 200

    if req.headers['range']?
        stream.setHeader('range', req.headers['range'])

    stream.pipe(res)

    res.on 'close', ->
        stream.abort()


# DELETE /data/:id/attachments/:name
action 'removeAttachment', ->
    name = params.name

    db.removeAttachment @doc, name, (err, res) ->
        if err and err.error = "not_found"
            send 404
        else if err
            console.log "[Attachment] err: " + JSON.stringify err
            send 500
        else
            send 204
