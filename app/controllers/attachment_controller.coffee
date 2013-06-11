load 'application'

fs = require "fs"
db = require('./helpers/db_connect_helper').db_connect()
checkToken = require('./lib/token').checkToken


before 'requireToken', ->
    checkToken req.header('authorization'), app.tokens, (err) =>
        next()


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

    if i is 0 #no files in req
        callback()



before 'lock request', ->
    @lock = "#{params.id}"

    app.locker.runIfUnlock @lock, =>
        app.locker.addLock(@lock)
        next()
, only: ['addAttachment', 'removeAttachment']

after 'unlock request', ->
    app.locker.removeLock @lock
, only: ['addAttachment', 'removeAttachment']

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

    db.getAttachment @doc.id, name, (err) ->
        if err and err.error = "not_found"
            send 404
        else if err
            send 500
        else
            send 200
    .pipe(res)


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
