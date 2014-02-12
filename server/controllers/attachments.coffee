fs = require "fs"
db = require('../helpers/db_connect_helper').db_connect()
deleteFiles = require('../helpers/utils').deleteFiles

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
                next new Error err.error
            else
                deleteFiles req.files
                res.send 201, success: true
                next()

        fs.createReadStream(file.path).pipe stream

    else
        err = new Error "No file sent"
        err.status = 400
        next err

# GET /data/:id/attachments/:name
module.exports.get = (req, res, next) ->
    name = req.params.name

    stream = db.getAttachment req.doc.id, name, (err) ->
        if err? and err.error = "not_found"
            err = new Error "not found"
            err.status = 404
            next err
        else if err
            next new Error err.error
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
            err = new Error "not found"
            err.status = 404
            next err
        else if err?
            console.log "[Attachment] err: " + JSON.stringify err
            next new Error err
        else
            res.send 204, success: true
