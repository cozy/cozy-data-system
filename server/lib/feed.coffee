fs = require 'fs'
S = require 'string'
async = require 'async'
Client = require('request-json').JsonClient
client = null
updatePermissions = require('./token').updatePermissions
thumb = require('./thumb')

log = require('printit')
    prefix: 'feed'

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
            dbName = process.env.DB_NAME or 'cozy'
            requestPath = "/#{dbName}/#{change.id}?revs_info=true&open_revs=all"
            client.get requestPath, (err, res, doc) =>
                if doc?[0]?.ok?.docType?
                    doc = doc[0].ok
                    # Publish deletion
                    @_publish "#{doc.docType.toLowerCase()}.delete", change.id
                # If document has a binary, remove the binary
                if doc.binary?
                    removeBinary = (name, callback) =>
                        file = doc.binary[name]
                        binary = file.id
                        # Check if another file use this binary
                        @db.view 'binary/byDoc', {key: binary}, (err, res) =>
                            if err
                                callback err

                            else if res?.length is 0
                                # Retrieve binary and remove it
                                @db.get binary, (err, doc) =>
                                    return callback err if err
                                    if doc
                                        @db.remove doc._id, doc._rev, (err, doc) =>
                                            if not err?
                                                @_publish "binary.delete", doc.id
                                            callback err
                                    else
                                        callback()

                            else
                                # Binary is linked to another document.
                                callback()

                    # Check all binary
                    async.each Object.keys(doc.binary), removeBinary, (err) ->
                        log.error err if err

        else
            isCreation = change.changes[0].rev.split('-')[0] is '1'
            operation = if isCreation then 'create' else 'update'

            @db.get change.id, (err, doc) =>
                @logger.error err if err
                doctype = doc?.docType?.toLowerCase()

                @_publish "#{doctype}.#{operation}", doc._id if doctype
                if operation is 'update' and doctype is 'application'
                    updatePermissions doc

                if doctype is 'file'
                    @db.get change.id, (err, file) ->
                        if file.class is 'image' and
                            file.binary?.file? and not file.binary.thumb
                                # Creates thumb for image.
                                thumb.create file.id, false
module.exports = new Feed()