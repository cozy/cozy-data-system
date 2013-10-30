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
            deleteFiles req, -> send error: err.error, 404
        else if err
            console.log "[Attachment] err: " + JSON.stringify err
            app.locker.removeLock @lock
            deleteFiles req, -> send error: err.error, 500
        else if doc?
            @doc = doc
            next()
        else
            app.locker.removeLock @lock
            deleteFiles req, -> send error: "not found", 404

# Check if application is authorized to manage docType
# docType corresponds to docType of recovered document from database
# Required to be processed after "get doc"
before 'permissions', ->
    auth = req.header('authorization')
    checkPermissions auth, @doc.docType, (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            compound.app.feed.publish 'usage.application', appName
            next()

## Actions

# POST /data/:id/binaries/
action 'addAttachment', ->
    attach = (binary, name, file, doc) =>
        fileData =
            name: name
            "content-type": file.type
        stream = db.saveAttachment binary, fileData, (err, res) =>
            if err
                console.log "[Attachment] err: " + JSON.stringify err
                deleteFiles req, -> send error: err.error, 500
            else
                bin = 
                    id: res.id
                    rev: res.rev
                if doc.binary
                    newBin = doc.binary
                else
                    newBin = {}

                newBin[name] = bin

                db.merge doc._id, binary: newBin, (err, res) =>
                    deleteFiles req, -> send success: true, msg: 'created', 201
                    ###db.view 'doc/byBinary', key: res.id, (err, res) =>
                        console.log err if err
                        if res.length > 1
                            for doc in res
                                db.merge doc._id, binary, (err, res) =>
                                    console.log err if err###

        fs.createReadStream(file.path).pipe(stream)


    if req.files["file"]?
        file = req.files["file"]
        if body.name? then name = body.name else name = file.name
        if @doc.binary?[name]?
            db.get @doc.binary[name].id, (err, binary) =>
                attach binary, name, file, @doc
        else
            binary =
                docType: "Binary"
            db.save binary, (err, binary) =>
                attach binary, name, file, @doc              
    else
        console.log "no doc for attachment"
        send error: true, msg: "No file send", 400


# GET /data/:id/binaries/:name
action 'getAttachment', ->
    name = params.name
    if @doc.binary and @doc.binary[name]

        stream = db.getAttachment @doc.binary[name].id, name, (err) ->
            if err and err.error = "not_found"
                send error: err.error, 404
            else if err
                send error: err.error, 500
            else
                send 200

        if req.headers['range']?
            stream.setHeader('range', req.headers['range'])

        stream.pipe(res)

        res.on 'close', ->
            stream.abort()
    else
        send error: 'not_found', 404



# DELETE /data/:id/binaries/:name
action 'removeAttachment', ->
    name = params.name
    if @doc.binary and @doc.binary[name]
        id = @doc.binary[name].id
        delete @doc.binary[name] 
        if @doc.binary.length is 0
            delete @doc.binary
        db.save @doc, (err, res) ->
            db.get id, (err, binary) ->
                db.remove binary.id, binary.rev, (err, res) ->
                    if err and err.error = "not_found"
                        send error: err.error, 404
                    else if err
                        console.log "[Attachment] err: " + JSON.stringify err
                        send error: err.error, 500
                    else
                        send success: true, msg: 'deleted', 204
    else
        send error: 'not_found', 404
