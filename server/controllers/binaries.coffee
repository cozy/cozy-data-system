fs = require "fs"
multiparty = require 'multiparty'
log =  require('printit')
    date: true
    prefix: 'binaries'

db = require('../helpers/db_connect_helper').db_connect()
deleteFiles = require('../helpers/utils').deleteFiles
dbHelper = require '../lib/db_remove_helper'
downloader = require '../lib/downloader'


## Actions

# API to manage attachments separately from the CouchDB API. Cozy term for such
# kind of attachements is binary.


# POST /data/:id/binaries
# Allow to create a binary and to link it to given document.
module.exports.add = (req, res, next) ->

    # Parse given form to extract image blobs.
    form = new multiparty.Form
        autoFields: false
        autoFiles: false
    form.parse req

    # Dirty hack to end request if no file were sent when form is fully parsed.
    nofile = true

    fields = {}

    # We read part one by one to avoid writing the full file to the disk
    # and send it directly as a stream.
    form.on 'part', (part) ->

        # It's a field, we store it in case of the file name is set in the
        # form
        unless part.filename?
            fields[part.name] = ''
            part.on 'data', (buffer) ->
                fields[part.name] = buffer.toString()
            part.resume()

        # It's a file, we pipe it directly to Couch to avoid too much memory
        # consumption.
        # The 'file' event from the multiparty form stores automatically
        # the file to the disk and we don't want that.
        else
            nofile = false
            if fields.name?
                name = fields.name
            else
                name = part.filename

            # Build file data
            fileData =
                name: name
                "content-type": part.headers['content-type']

            # Store the binary as an attachment of binary document.
            attachBinary = (binary) ->
                log.info "binary #{name} ready for storage"
                stream = db.saveAttachment binary, fileData, (err, binDoc) ->
                    if err
                        log.error "#{JSON.stringify err}"
                        form.emit 'error', new Error err.error
                    else
                        log.info "Binary #{name} stored in Couchdb"

                        # Once binary is stored, it updates doc link to the
                        # binary.
                        bin =
                            id: binDoc.id
                            rev: binDoc.rev

                        if req.doc.binary
                            binList = req.doc.binary
                        else
                            binList = {}
                        binList[name] = bin
                        db.merge req.doc._id, binary: binList, (err) ->
                            res.send 201, success: true
                part.pipe stream

            # Update binary list set on given doc then save file to CouchDB
            # as an attachment via a stream. We do not use 'file' event to
            # avoid saving file on the disk.
            # Check if binary is already present in the document binary list.
            # In that case the attachment is replaced with the uploaded file.
            if req.doc.binary?[name]?
                db.get req.doc.binary[name].id, (err, binary) ->
                    attachBinary binary

            # Else create a new binary to store uploaded file..
            else
                binary =
                    docType: "Binary"
                db.save binary, (err, binDoc) ->
                    attachBinary binDoc

    form.on 'progress', (bytesReceived, bytesExpected) ->

    form.on 'error', (err) ->
        next err

    form.on 'close', ->
        res.send 400, error: 'No file sent' if nofile
        # If no file was found, returns a client error.
        next()


# GET /data/:id/binaries/:name/
# Download a the file attached to the binary object.
module.exports.get = (req, res, next) ->
    name = req.params.name
    binary = req.doc.binary

    if binary and binary[name]

        # Build stream for fetching file from the database. Use a custom lib
        # instead of cradle to avoid too high memory consumption.
        id = binary[name].id

        # Run the download with Node low level api.
        stream = downloader.download id, name, (err, stream) ->
            if err and err.error == "not_found"
                err = new Error "not found"
                err.status = 404
                next err
            else if err
                next new Error err.error
            else

            # Set response header from attachment infos
            res.setHeader 'Content-Length', stream.headers['content-length']
            res.setHeader 'Content-Type', stream.headers['content-type']

            if req.headers['range']?
                stream.setHeader 'range', req.headers['range']

            # Use streaming to avoid high memory consumption.
            stream.pipe res

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
