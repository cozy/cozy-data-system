REDIS_PORT = 6379
REDIS_HOST = "127.0.0.1"

REDIS_CONNECT_COUNTER = 1

module.exports = class Feed

    db:undefined
    feed:undefined
    redisClient:undefined

    constructor: (@app) ->
        @startPublishingToRedis()

        @logger = @app.compound.logger
        @app.compound.server.on 'close', =>
            @stopListening()
            @redisClient.end() if @redisClient?

    # define input craddle connection
    # db the craddle connection
    startListening: (db) ->
        @stopListening()
        @feed = db.changes since:'now'
        @feed.on 'change', @_onChange
        @feed.on 'error', (err) =>
            console.log "error occured with feed : #{err.stack}"
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

    # set output redis server
    # redisClient a redis client
    startPublishingToRedis: () ->
        redis = require('redis')
        @redisClient = redis.createClient REDIS_PORT, REDIS_HOST

        @redisClient.on "error", (err) =>

            @redisConnected = false

            if (/ECONNREFUSED/).test err.message
                cnt = REDIS_CONNECT_COUNTER++
                console.log "Failled to connect to redis on attempt #{cnt}"
                console.log "There will be no realtime"
            else
                console.log "Redis error : #{err.stack}"
        @redisClient.on "connect", =>

            @redisConnected = true
            REDIS_CONNECT_COUNTER = 1

            console.log "Begins publishing changes to redis"

    publish: (event, id) => @_publish(event, id)


    # [INTERNAL] publish to available outputs
    _publish: (event,id) ->
        @redisClient.publish event, id  if @redisConnected?

    # [INTERNAL]  transform db change to (doctype.op, id) message and publish
    _onChange: (change) =>
        if change.deleted == true
            @_publish "delete", change.id

        else
            operation = if change.changes[0].rev.split('-')[0] is '1'
            then 'create'
            else 'update'

            @db.get change.id, (err, doc) =>
                console.log err if err?
                doctype = doc?.docType?.toLowerCase()
                doctype ?= 'null'
                @_publish "#{doctype}.#{operation}", doc._id
