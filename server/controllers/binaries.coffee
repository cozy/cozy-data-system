fs = require "fs"
db = require('../helpers/db_connect_helper').db_connect()
deleteFiles = require('../helpers/utils').deleteFiles
dbHelper = require '../lib/db_remove_helper'

## Actions

# API to manage attachments separately from the CouchDB API. Cozy term for such
# kind of attachements is binary.


# POST /data/:id/binaries
# Allow to create a binary and to link it to given document.
module.exports.add = (req, res, next) ->

    attach = (binary, name, file, doc) ->
        fileData =
            name: name
            "content-type": file.type
        stream = db.saveAttachment binary, fileData, (err, binDoc) ->
            if err
                console.log "[Attachment] err: " + JSON.stringify err
                deleteFiles req.files
                next new Error err.error

            else
                bin =
                    id: binDoc.id
                    rev: binDoc.rev
                if doc.binary
                    newBin = doc.binary
                else
                    newBin = {}

                newBin[name] = bin
                db.merge doc._id, binary: newBin, (err) ->
                    deleteFiles req.files
                    res.send 201, success: true
                    next()

        fs.createReadStream(file.path).pipe stream

    if req.files["file"]?
        file = req.files["file"]
        if req.body.name? then name = req.body.name else name = file.name
        if req.doc.binary?[name]?
            db.get req.doc.binary[name].id, (err, binary) ->
                attach binary, name, file, req.doc
        else
            binary =
                docType: "Binary"
            db.save binary, (err, binary) ->
                attach binary, name, file, req.doc
    else
        err = new Error "No file sent"
        err.status = 400
        next err


# GET /data/:id/binaries/:name/
# Download a the file attached to the binary object.
module.exports.get = (req, res, next) ->

    name = req.params.name
    if req.doc.binary and req.doc.binary[name]

        # Build stream for
        stream = db.getAttachment req.doc.binary[name].id, name, (err) ->
            if err and err.error = "not_found"
                err = new Error "not found"
                err.status = 404
                next err
            else if err
                next new Error err.error

        if req.headers['range']?
            stream.setHeader 'range', req.headers['range']

        # Use streaming to avoid high memory consumption.
        stream.pipe res

        # Abort streaming if response is prematurely sent.
        res.on 'close', -> stream.abort()

    # No binary found, error is returned.
    else
        err = new Error "not found"
        err.status = 404
        next err


# DELETE /data/:id/binaries/:name
# Remove binary object and remove link set on given document.
module.exports.remove = (req, res, next) ->

    name = req.params.name
    if req.doc.binary and req.doc.binary[name]

        id = req.doc.binary[name].id

        # Remove reference to binary from doc
        delete req.doc.binary[name]
        delete req.doc.binary if req.doc.binary.length is 0

        # Save updated doc
        db.save req.doc, (err) ->

            # Then delete binary document.
            db.get id, (err, binary) ->
                if binary?
                    dbHelper.remove binary, (err) ->
                        if err? and err.error = "not_found"
                            err = new Error "not found"
                            err.status = 404
                            next err
                        else if err
                            console.log "[Attachment] err: " + JSON.stringify err
                            next new Error err.error
                        else
                            res.send 204, success: true
                            next()

                # No binary found, error is returned.
                else
                    err = new Error "not found"
                    err.status = 404
                    next err

    # No binary given, error is returned.
    else
        err = new Error "no binary ID is provided"
        err.status = 400
        next err
