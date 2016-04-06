db = require('../helpers/db_connect_helper').db_connect()
thumb = require '../lib/thumb'
querystring = require 'querystring'
log = require('printit')
    prefix: 'binary'

# Add/Modifify binary to a document
#   * doc: document to attach binary
#   * attachData: metaData for binary (name and content-type)
#   * readStream: read stream to read file to store in binary
module.exports.addBinary = (doc, attachData, readStream, callback) ->
    name = attachData.name
    attachFile = (binary, cb) ->
        attachData.name = querystring.escape name
        stream = db.saveAttachment binary, attachData, (err, binDoc) ->
            if err
                log.error "#{JSON.stringify err}"
            else
                log.info "Binary #{name} stored in Couchdb"

                # Once binary is stored, it updates doc link to the
                # binary.
                bin =
                    id: binDoc.id
                    rev: binDoc.rev

                binList = doc.binary or {}
                binList[name] = bin
                db.merge doc._id, binary: binList, (err) ->
                    log.error err if err?
                    cb()
        readStream.pipe stream

    # Update binary list set on given doc then save file to CouchDB
    # as an attachment via a stream. We do not use 'file' event to
    # avoid saving file on the disk.
    # Check if binary is already present in the document binary list.
    # In that case the attachment is replaced with the uploaded file.
    if doc.binary?[name]?
        db.get doc.binary[name].id, (err, binary) ->
            attachFile binary, ->
                callback()
                if doc.docType.toLowerCase() is 'file' and
                        doc.class is 'image' and
                        name is 'file'
                    thumb.create doc.id, true
    else
        # Else create a new binary to store uploaded file..
        binary =
            docType: "Binary"
        db.save binary, (err, binary) ->
            attachFile binary, callback
