load 'application'

cradle = require "cradle"
fs = require "fs"

connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database("cozy")

before 'get doc', ->
    db.get params.id, (err, doc) =>
        if err and err.error == "not_found"
            send 404
        else if err
            console.log "[Attachment] err: " + JSON.stringify err
            send 500
        else if doc?
            @doc = doc
            next()
        else
            send 404


# POST /data/:id/attachments/
action 'addAttachment', ->
    if req.files["file"]?
        file = req.files["file"]
        fileData =
            name: file.name
            "content-type": file.type
        stream = db.saveAttachment @doc, fileData, (err, res) ->
            if err
                console.log "[Attachment] err: " + JSON.stringify err
                send 500
                delete cached
            else
                send 201
        fs.createReadStream(file.path).pipe(stream)

    else
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
    .pipe(response)


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

