fs = require 'fs'
S = require 'string'
Client = require('request-json').JsonClient
client = null
setCouchCredentials = ->
    if process.env.NODE_ENV is 'production'
        data = fs.readFileSync '/etc/cozy/couchdb.login'
        lines = S(data.toString('utf8')).lines()
        client.setBasicAuth lines[0], lines[1]

module.exports = class Feed

    db:       undefined
    feed:     undefined
    axonSock: undefined
    deleted_ids = {}

    constructor: ->
        @logger = require('printit')
            date: true
            prefix: 'helper/db_feed'

    initialize: (server) ->
        @startPublishingToAxon()

        server.on 'close', =>
            @stopListening()
            @axonSock.close()  if @axonSock?

    startPublishingToAxon: ->
        axon = require 'axon'
        @axonSock = axon.socket 'pub-emitter'
        axonPort =  parseInt process.env.AXON_PORT or 9105
        @axonSock.bind axonPort
        @logger.info 'Pub server started'

        @axonSock.sock.on 'connect', () =>
            @logger.info "An application connected to the change feeds"

        @axonSock.sock.on 'message', (event,id) =>
            @_publish event.toString(), id.toString()

    # define input craddle connection
    # db the craddle connection
    startListening: (db) ->
        @stopListening()

        couchUrl = "http://#{db.connection.host}:#{db.connection.port}/"
        client = new Client couchUrl
        setCouchCredentials()

        @feed = db.changes since: 'now'
        @feed.on 'change', @_onChange
        @feed.on 'error', (err) =>
            @logger.error "Error occured with feed : #{err.stack}"
            @stopListening()

        @db = db

    # stop listenning to changes
    stopListening: ->
        if @feed?
            @feed.stop()
            @feed.removeAllListeners 'change'
            @feed = null

        @db = null if @db?

    publish: (event, id) => @_publish(event, id)

    # [INTERNAL] publish to available outputs
    _publish: (event, id) ->
        @logger.info "Publishing #{event} #{id}"
        @axonSock.emit event, id if @axonSock?

    # [INTERNAL]  transform db change to (doctype.op, id) message and publish
    _onChange: (change) =>
        if change.deleted
            client.get "/#{process.env.DB_NAME}/#{change.id}?revs_info=true&open_revs=all", (err, res, doc) =>
                if doc?[0]?.ok?.docType?
                    doc = doc[0].ok
                    # Publish deletion
                    @_publish "#{doc.docType.toLowerCase()}.delete", change.id
                    # If document has a binary, remove the binary
                    ## TODOS : Check if binary is not link with an other document
                    if doc.binary?.file?.id?
                        binary = doc.binary.file.id
                        @db.get binary, (err, doc) =>
                            return if err
                            if doc
                                @db.remove binary, binary._rev, (err, doc) =>
                                    @_publish "binary.delete", binary
        else
            isCreation = change.changes[0].rev.split('-')[0] is '1'
            operation = if isCreation then 'create' else 'update'

            @db.get change.id, (err, doc) =>
                @logger.error err if err?
                doctype = doc?.docType?.toLowerCase()
                @_publish "#{doctype}.#{operation}", doc._id if doctype

module.exports = new Feed()
