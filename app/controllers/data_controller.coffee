load 'application'

cradle = require "cradle"

connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database("cozy")


action 'exist', ->
    db.head params.id, (err, res, status) ->
        if status is 200
            send {"exist": true}
        else if status is 404
            send {"exist": false}

action 'find', ->
    db.get params.id, (err, doc) ->
        if err
            send 404
        else
            delete doc._rev # CouchDB specific, user don't need it
            send doc

action 'create', ->
    if params.id
        db.get params.id, (err, doc) -> # this GET needed because of cache
            if doc
                send 409
            else
                db.save params.id, body, (err, res) ->
                    if err
                        send 409
                    else
                        send {"_id": res.id}, 201
    else
        db.save body, (err, res) ->
            if err
                # oops unexpected error !                
                console.log "[Create] err: " + JSON.stringify err
                send 500
            else
                send {"_id": res.id}, 201

action 'update', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        if doc
            db.save params.id, body, (err, res) ->
                if err
                    # oops unexpected error !                
                    console.log "[Update] err: " + JSON.stringify err
                    send 500
                else
                    send 200
        else
            send 404

action 'upsert', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        db.save params.id, body, (err, res) ->
            if err
                # oops unexpected error !                
                console.log "[Upsert] err: " + JSON.stringify err
                send 500
            else if doc
                send 200
            else
                send {"_id": res.id}, 201

action 'delete', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        if doc
            db.remove params.id, (err, res) ->
                if err
                    # oops unexpected error !                
                    console.log "[Delete] err: " + JSON.stringify err
                    send 500
                else
                    send 204
        else
            send 404

