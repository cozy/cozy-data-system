Client = require('request-json').JsonClient
client = new Client 'http://localhost:5984'

module.exports = class Feed

    db:       undefined
    feed:     undefined
    axonSock: undefined
    deleted_ids = {}

    constructor: (@app) ->
        @startPublishingToAxon()

        @logger = @app.compound.logger
        @app.compound.server.on 'close', =>
            @stopListening()
            @axonSock.close()  if @axonSock?

    # define input craddle connection
    # db the craddle connection
    startListening: (db) ->
        @stopListening()
        @feed = db.changes since:'now'
        @feed.on 'change', @_onChange
        @feed.on 'error', (err) =>
            console.log "Error occured with feed : #{err.stack}"
            @stopListening()

        @db = db

    # stop listenning to changes
    stopListening: ->
        if @feed?
            @feed.stop()
            @feed.removeAllListeners 'change'
            @feed = null
        if @db?
            @db = null

    startPublishingToAxon: (attempt = 0) ->
        axon = require 'axon'
        @axonSock = axon.socket 'pub-emitter'
        @axonSock.bind 9105
        console.log 'Pub server started'

        @axonSock.sock.on 'connect', () ->
            console.info "An application conected to the change feeds"

    publish: (event, id) => @_publish(event, id)


    # [INTERNAL] publish to available outputs
    _publish: (event, id) ->
        console.info "Publishing #{event} #{id}" unless process.env.NODE_ENV is "test"
        @axonSock.emit event, id if @axonSock?

    # [INTERNAL]  transform db change to (doctype.op, id) message and publish
    _onChange: (change) =>
        if change.deleted
            if not deleted_ids[change.id]
                doc = 
                    _id: change.id
                    _rev: change.changes[0].rev
                @db.post doc, (err, doc) =>
                    client.get "/cozy/#{change.id}?revs_info=true", (err, res, doc) =>
                        @db.get change.id, doc._revs_info[2].rev, (err, doc) =>
                            if doc.docType is 'File' and doc.binary?.file?
                                binary = doc.binary.file.id
                                binary_rev = doc.binary.file.rev
                                deleted_ids[binary] = 'deleted'
                                @db.get binary, (err, doc) =>
                                    return if err
                                    if doc 
                                        @db.remove binary, binary_rev, (err, doc) =>
                                            @_publish "binary.delete", doc._id
                            @db.get change.id, (err, document) =>
                                deleted_ids[change.id] = 'deleted'
                                @db.remove change.id, document.rev, (err, res) =>
                                    doctype = doc?.docType?.toLowerCase()
                                    doctype ?= 'null'
                                    @feed.emit "deletion.#{doc._id}"
                                    @_publish "#{doctype}.delete", doc._id
                                    return 
            else
                delete deleted_ids[change.id]
        else
            isCreation = change.changes[0].rev.split('-')[0] is '1'
            operation = if isCreation then 'create' else 'update'

            @db.get change.id, (err, doc) =>
                console.log err if err?
                doctype = doc?.docType?.toLowerCase()
                @_publish "#{doctype}.#{operation}", doc._id if doctype