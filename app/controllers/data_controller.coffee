load 'application'

cradle = require "cradle"

connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database("cozy")


action 'exist', ->
    db.get params.id, (err, doc) ->
        send exist: doc?

