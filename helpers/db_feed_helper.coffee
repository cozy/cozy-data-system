REDIS_PORT = 6379;
REDIS_HOST = "127.0.0.1";

module.exports = class Feed

    db:undefined
    feed:undefined
    redisClient:undefined

    constructor: (@app) ->
        @startPublishingToRedis()

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
            @app.compound.logger.write "error occured with feed : #{err.stack}"
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
        @redisClient = redis.createClient REDIS_PORT, REDIS_HOST,
            max_attempts: 1
        @redisClient.on "error", (err) =>
            @app.compound.logger.write "Failled to connect to redis : #{err.stack}"
            @app.compound.logger.write "Everything else should work as expected"
        @redisClient.on "connect", =>
            @app.compound.logger.write "Begins publishing changes to redis"

    publish: (event, id) => @_publish(event, id)


    # [INTERNAL] publish to available outputs
    _publish: (event,id) ->
        @redisClient.publish event, id  if @redisClient?

    # [INTERNAL]  transform db change to (doctype.op, id) message and publish
    _onChange: (change) =>
        if change.deleted == true
            @_publish "delete", change.id

        else
            operation = if change.changes[0].rev.split('-')[0] is '1'
            then 'create'
            else 'update'

            @db.get change.id, (err, doc) =>
                @app.compound.logger.write err if err?
                doctype = doc?.docType?.toLowerCase()
                doctype ?= 'null'
                @_publish "#{doctype}.#{operation}", doc._id
