fs = require "fs"
db = require('../helpers/db_connect_helper').db_connect()
deleteFiles = require('./utils').deleteFiles

## Actions

# POST /data/:id/attachments/
module.exports.add = (req, res, next) ->
    if req.files["file"]?
        file = req.files["file"]
        if req.body.name? then name = req.body.name else name = file.name

        fileData =
            name: name
            "content-type": file.type

        stream = db.saveAttachment req.doc, fileData, (err) ->
            if err
                console.log "[Attachment] err: " + JSON.stringify err
                deleteFiles req.files
                next()
                res.send 500, error: err.error
            else
                deleteFiles req.files
                next()
                res.send 201, success: true

        fs.createReadStream(file.path).pipe stream

    else
        console.log "no doc for attachment"
        next()
        res.send 400, error: "No file sent"

# GET /data/:id/attachments/:name
module.exports.get = (req, res) ->
    name = req.params.name

    stream = db.getAttachment req.doc.id, name, (err) ->
        if err? and err.error = "not_found"
            res.send 404, error: "not found"
        else if err
            res.send 500, error: err.error
        else
            res.send 200, success: true

    if req.headers['range']?
        stream.setHeader 'range', req.headers['range']

    stream.pipe res

    res.on 'close', -> stream.abort()


# DELETE /data/:id/attachments/:name
module.exports.remove = (req, res, next) ->
    name = req.params.name

    db.removeAttachment req.doc, name, (err) ->
        next()
        if err? and err.error = "not_found"
            res.send 404, error: "not found"
        else if err?
            console.log "[Attachment] err: " + JSON.stringify err
            res.send 500, error: err.error
        else
            res.send 204, success: true
