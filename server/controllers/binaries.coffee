fs = require "fs"
db = require('../helpers/db_connect_helper').db_connect()
deleteFiles = require('../helpers/utils').deleteFiles
dbHelper = require '../lib/db_remove_helper'
Client = require('request-json').JsonClient

controllerClient = new Client('http://localhost:9002')

## Actions

# POST /data/:id/binaries
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
        controllerClient.setToken process.env.TOKEN
        controllerClient.get 'diskinfo', (err, res, body) =>
            if not err? and 2*file.size > body.freeDiskSpace*1073741824
                err = new Error "Not enough storage space"
                err.status = 400
                next err
            else
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
module.exports.get = (req, res, next) ->
    name = req.params.name
    if req.doc.binary and req.doc.binary[name]

        stream = db.getAttachment req.doc.binary[name].id, name, (err) ->
            if err and err.error = "not_found"
                err = new Error "not found"
                err.status = 404
                next err
            else if err
                next new Error err.error
            else
                res.send 200

        if req.headers['range']?
            stream.setHeader 'range', req.headers['range']

        stream.pipe res

        res.on 'close', -> stream.abort()
    else
        err = new Error "not found"
        err.status = 404
        next err

# DELETE /data/:id/binaries/:name
module.exports.remove = (req, res, next) ->
    name = req.params.name
    if req.doc.binary and req.doc.binary[name]
        id = req.doc.binary[name].id
        delete req.doc.binary[name]
        if req.doc.binary.length is 0
            delete req.doc.binary
        db.save req.doc, (err) ->
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
                else                    
                    err = new Error "not found"
                    err.status = 404
                    next err
    else
        err = new Error "not found"
        err.status = 404
        next err

