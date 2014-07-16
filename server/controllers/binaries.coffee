fs = require "fs"
multiparty = require 'multiparty'
log =  require('printit')
    date: true
    prefix: 'binaries'

db = require('../helpers/db_connect_helper').db_connect()
deleteFiles = require('../helpers/utils').deleteFiles
dbHelper = require '../lib/db_remove_helper'


## Actions

# API to manage attachments separately from the CouchDB API. Cozy term for such
# kind of attachements is binary.


# POST /data/:id/binaries
# Allow to create a binary and to link it to given document.
module.exports.add = (req, res, next) ->

    # Parse given form to extract image blobs.
    form = new multiparty.Form()
    form.parse req

    # Dirty hack to end request if no file were sent when form is fully parsed.
    nofile = true

    fields = {}

    # We read part one by one to avoid writing the full file to the disk
    # and send it directly as a stream.
    form.on 'part', (part) ->

        # It's a field we do nothing
        unless part.filename?
            fields[part.name] = ''
            part.on 'data', (buffer) ->
                fields[part.name] = buffer.toString()

        # It's a file, we pipe it directly to Couch to avoid too much memory
        # consumption.
        # The 'file' event from the multiparty form stores automatically
        # the file to the disk and we don't want that.
        else
            nofile = false
            if fields.name?
                name = fields.name
            else
                name = part.filname

            # Build file data
            fileData =
                name: 'file'
                "content-type": part.headers['content-type']

            # Update binary list set on given doc then save file to CouchDB
            # as an attachment via a stream. We do not use 'file' event to
            # avoid saving file on the disk.
            attach = (binDoc) ->
                bin =
                    id: binDoc.id
                    rev: binDoc.rev

                if req.doc.binary
                    binList = req.doc.binary
                else
                    binList = {}
                    binList[name] = bin

                    db.merge req.doc._id, binary: binList, (err) ->
                        log.info "binary #{name} ready for storage"
                        stream = db.saveAttachment binDoc, fileData, (err, binDoc) ->
                            if err
                                log.error "#{JSON.stringify err}"
                                form.emit 'error', new Error err.error
                            else
                                log.info "Binary #{name} stored in Couchdb"
                                res.send 201, success: true
                        part.pipe stream

            # Check if binary is already present in the document binary list.
            # In that case the attachment is replaced with the uploaded file.
            if req.doc.binary?[name]?
                db.get req.doc.binary[name].id, (err, binary) ->
                    attach binary

            # Else create a new binary to store uploaded file..
            else
                binary =
                    docType: "Binary"
                db.save binary, (err, binary) ->
                    attach binary


    form.on 'progress', (bytesReceived, bytesExpected) ->

    form.on 'error', (err) ->
        next err

    form.on 'close', ->
        # If no file was found, returns a client error.
        res.send 400, error: 'No file sent' if nofile
        next()

# GET /data/:id/binaries/:name/
# Download a the file attached to the binary object.
module.exports.get = (req, res, next) ->

    name = req.params.name
    if req.doc.binary and req.doc.binary[name]

        # Build stream for
        stream = db.getAttachment req.doc.binary[name].id, 'file', (err) ->
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
