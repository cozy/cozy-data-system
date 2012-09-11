load 'application'

cradle = require "cradle"
fs = require "fs"

connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database("cozy")


# POST /data/:id/attachments/
action 'addAttachment', ->
    saveAttachment = (doc, file) ->
        stream = db.saveAttachment
                id: doc.id
                res: doc.rev
            ,
                name: file.name
                "content-type": file.type
            , (err, res) ->
                    if err
                        # oops unexpected error !
                        console.log "[Attachment] err: " + JSON.stringify err
                        send 500
                    else
                        send 201

        fs = fs.createReadStream(file.path).pipe(stream)

    if req.files["file"]?
        file = req.files["file"]
        db.get params.id, (err, doc) ->
            if err and err.error == "not_found"
                send 404
            else if err
                console.log "[Attachment] err: " + JSON.stringify err
                send 500
            else if doc?
                saveAttachment doc, file
            else
                send 404
    else
        send error: true, msg: "No file send", 400


# GET /data/:id/attachments/:name
action 'getAttachment', ->
    name = params.name
    
    getAttachment = (doc) ->
        db.getAttachment doc.id, name, (err) ->
            if err
                send 500
            else
                send 200
        .pipe(response)

    db.get params.id, (err, doc) ->
        if err and err.error == "not_found"
            send 404
        else if err
            console.log "[Attachment] err: " + JSON.stringify err
            send 500
        else if doc?
            getAttachment doc
        else
            send 404

# DELETE /data/:id/attachments/:name
action 'removeAttachment', ->
    name = params.name
    id = params.id

    removeAttachment = (doc) ->
        db.removeAttachment doc, name, (err, res) ->
            if err and err.error = "not_found"
                send 404
            else if err
                console.log "[Attachment] err: " + JSON.stringify err
                send 500
            else
                send 204

    db.get id, (err, doc) ->
        if err and err.error == "not_found"
            send 404
        else if err
            console.log "[Attachment] err: " + JSON.stringify err
            send 500
        else if doc?
            removeAttachment doc
        else
            send 404

