fs = require "fs"
db = require('../helpers/db_connect_helper').db_connect()
deleteFiles = require('../helpers/utils').deleteFiles
multiparty = require 'multiparty'



## Actions

# POST /data/:id/attachments/
module.exports.add = (req, res, next) ->
    files = {}

    # Parse given form to extract image blobs.
    form = new multiparty.Form
        uploadDir: __dirname + '../../uploads'
        keepExtensions: true
        maxFilesSize: 10 * 1024 * 1024 * 1024
    form.parse req

    # Get fields from form.
    form.on 'field', (name, value) ->
        req.body[name] = value
        cid = value if name is 'cid'

    # Get files from form.
    form.on 'file', (name, val) ->
        val.name = val.originalFilename
        val.type = val.headers['content-type'] or null
        files[name] = val

    form.on 'progress', (bytesReceived, bytesExpected) ->
        # TODO handle progress

    form.on 'error', (err) ->
        next err

    # When form is fully parsed, data are saved into CouchDB.
    form.on 'close', ->
        if files.file?
            file = files.file
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

    if req.headers['range']?
        stream.setHeader 'range', req.headers['range']

    res.on 'close', -> stream.abort()

    stream.pipe res



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
            next err # cradle sends a Error object here
        else
            res.send 204, success: true
