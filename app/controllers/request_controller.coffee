load 'application'

cradle = require "cradle"

connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database("cozy")


# GET /request/:req_name
action 'access', ->
    db.view 'cozy-request/' + params.req_name, (err, res) ->
        if err
            send 404
        else
            res.forEach (value) ->
                delete value._rev # CouchDB specific, user don't need it
            send res

# PUT /request/:id

# DELETE /request/:id
