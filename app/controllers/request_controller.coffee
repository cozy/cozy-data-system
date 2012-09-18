load 'application'

cradle = require "cradle"

connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database("cozy")


# GET /request/type/:req_name
action 'results', ->
    db.view "#{params.type}/#{params.req_name}", body, (err, res) ->
        if err
            send 404
        else
            res.forEach (value) ->
                delete value._rev # CouchDB specific, user don't need it
            send res

# PUT /request/:type/:req_name
action 'definition', ->
    # no need to precise language because it's javascript
    db.get "_design/#{params.type}", (err, res) ->
        if err && err.error is 'not_found'
            design_doc = {}
            design_doc[params.req_name] = body
            db.save "_design/#{params.type}", design_doc, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send 500
                else
                    send 200
        else if err
            send 500
        else
            views = res.views
            views[params.req_name] = body
            db.merge "_design/#{params.type}", {views:views}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send 500
                else
                    send 200

# DELETE /request/:type/:req_name
action 'remove', ->
    db.get "_design/#{params.type}", (err, res) ->
        if err && err.error is 'not_found'
            send 404
        else if err
            send 500
        else
            views = res.views
            delete views[params.req_name]
            db.merge "_design/#{params.type}", {views:views}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send 500
                else
                    send 204
