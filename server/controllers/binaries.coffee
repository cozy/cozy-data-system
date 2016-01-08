multiparty = require 'multiparty'
log =  require('printit')
    date: true
    prefix: 'binaries'

db = require('../helpers/db_connect_helper').db_connect()
binaryManagement = require '../lib/binary'
dbHelper = require '../lib/db_remove_helper'
downloader = require '../lib/downloader'
async = require 'async'


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

            binaryManagement.addBinary req.doc, fileData, part, (err)->
                if err
                    log.error "#{JSON.stringify err}"
                    form.emit 'error', err
                else
                    res.send 201, success: true


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
        request = downloader.download id, name, (err, stream) ->
            if err
                next err
            else
                # Set response header from attachment infos
                res.setHeader 'Content-Length', stream.headers['content-length']
                res.setHeader 'Content-Type', stream.headers['content-type']

                req.once 'close', -> request.abort()

                #@TODO forward other cache-control header
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
            # Check if binary is used by another document
            db.view 'binary/byDoc', {key: id}, (err, result) ->
                if result.length isnt 0
                    res.send 204, success: true
                    return next()

                # Then delete binary document.
                db.get id, (err, binary) ->
                    unless binary?
                        err = new Error('Binary not found')
                        err.status = 404
                        return next err

                    dbHelper.remove binary, (err) ->
                        if err
                            console.log "[Attachment] err: " + \
                                                        JSON.stringify err
                            next err
                        else
                            res.send 204, success: true
                            next()

    # No binary given, error is returned.
    else
        err = new Error "no binary ID is provided"
        err.status = 400
        next err

module.exports.convert = (req, res, next) ->
    binaries = {}
    id = req.doc.id

    removeOldAttach = (attach, binaryId, callback) ->
        db.get req.doc.id, (err, doc) ->
            if err
                callback err
            else
                db.removeAttachment doc, attach, (err) ->
                    if err
                        callback err
                    else
                        db.get binaryId, (err, doc) ->
                            if err
                                callback err
                            else
                                callback null, doc

    createBinary = (attach, callback) ->
        # Create binary
        binary =
            docType: "Binary"
        db.save binary, (err, binDoc) ->
            # Get attachment
            readStream = db.getAttachment req.doc.id, attach, (err) ->
                console.log err if err

            data =
                name: attach
                body: ''
            # Attach document to binary
            writeStream = db.saveAttachment binDoc, data, (err, res) ->
                return callback err if err
                # Remove attachment from documents
                removeOldAttach attach, binDoc._id, (err, doc) ->
                    if err
                        callback err
                    else
                        # Store binaries information
                        binaries[attach] =
                            id: doc._id
                            rev: doc._rev
                        callback()
            readStream.pipe(writeStream)

    if req.doc._attachments?
        keys = Object.keys(req.doc._attachments)
        async.eachSeries keys, createBinary, (err) ->
            if err
                next err
            else
                # Store binaries
                db.get req.doc.id, (err, doc) ->
                    doc.binary = binaries
                    db.save doc, (err, doc) ->
                        if err
                            next err
                        else
                            res.send 200, success: true
                            next()
    else
        res.send 200, success: true
        next()
