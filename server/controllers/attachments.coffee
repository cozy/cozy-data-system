fs = require "fs"
multiparty = require 'multiparty'
log =  require('printit')
    date: true
    prefix: 'attachment'
Readable = require('stream').Readable

db = require('../helpers/db_connect_helper').db_connect()
deleteFiles = require('../helpers/utils').deleteFiles



## Actions

# POST /data/:id/attachments/
# Add an attachment via uploading a file through a multipart form.
module.exports.add = (req, res, next) ->

    # Parse given form to extract image blobs.
    form = new multiparty.Form()
    form.parse req

    # We read part one by one to avoid writing the full file to the disk
    # and send it directly as a stream.
    form.on 'part', (part) ->

        # It's a field
        unless part.filename?
            part.resume()

        # It's a file, we pipe it directly to Couch to avoid too much memory
        # consumption.
        # The 'file' event stores the file to the disk and we don't want that.
        else
            fileData =
                name: part.filename
                "content-type": part.headers['content-type']

            log.info "attachment #{fileData.name} ready for storage"

            stream = db.saveAttachment req.doc, fileData, (err) ->
                if err
                    console.log "[Attachment] err: " + JSON.stringify err
                    next new Error err.error
                else
                    # We end the request because we expect to have only one
                    # file.
                    res.send 201, success: true
                    next()

            part.pipe stream


    form.on 'progress', (bytesReceived, bytesExpected) ->
        # TODO handle progress

    form.on 'error', (err) ->
        next err

    form.on 'close', ->
        log.info 'attachement form fully parsed'


# GET /data/:id/attachments/:name
# Download given attachment (represented by name) linked to given document
# (represented by id).
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
# Remove given attachment (represented by name) from given document
# (represented by id).
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
