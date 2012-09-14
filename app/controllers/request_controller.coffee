load 'application'

cradle = require "cradle"

connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database("cozy")


# GET /request/:req_name
action 'access', ->
    db.view "cozy-request/#{params.req_name}", (err, res) ->
        if err
            send 404
        else
            res.forEach (value) ->
                delete value._rev # CouchDB specific, user don't need it
            send res

# PUT /request/:req_name
action 'definition', ->
    db.get "_design/cozy-request", (err, res) ->
        if err && err.error is 'not_found'
            design_doc = {}
            design_doc[params.req_name] = body
            db.save "_design/cozy-request", design_doc, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send 500
                else
                    send 200
        else
            views = res.views
            views[params.req_name] = body
            db.merge "_design/cozy-request", {views:views}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send 500
                else
                    send 200

# DELETE /request/:req_name
