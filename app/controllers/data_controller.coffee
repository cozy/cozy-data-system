load 'application'

cradle = require "cradle"

connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database("cozy")


action 'exist', ->
    db.get params.id, (err, doc) ->
        send exist: doc?


action 'find', ->
    db.get params.id, (err, doc) ->
        if err
            send 404
        else
            delete doc._rev # CouchDB specific, user don't need it
            send doc
