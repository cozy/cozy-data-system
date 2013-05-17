load 'application'

git = require('git-rev')
Client = require("request-json").JsonClient

client = new Client "http://localhost:9102/"
db = require('./helpers/db_connect_helper').db_connect()


before 'get doc', ->
    db.get params.id, (err, doc) =>
        if err and err.error is "not_found"
            app.locker.removeLock @lock
            send error: "not found", 404
        else if err
            console.log "[Get doc] err: " + JSON.stringify err
            app.locker.removeLock @lock
            send error: err, 500
        else if doc?
            @doc = doc
            next()
        else
            app.locker.removeLock @lock
            send error: "not found", 404
, only: ['delete']


# POST /doctype
action 'create', ->
    delete body._attachments
    if (body.docType? and body.docType isnt "docType") or !body.name
        send error: "docType should be equal to 'docType' and field name are "+
                "required", 409
    else
        body.docType = "docType"
        if params.id
            db.get params.id, (err, doc) -> # this GET needed because of cache
                if doc
                    send error: "The document exists", 409
                else
                    db.save params.id, body, (err, res) ->
                        if err
                            send error: err.message, 409
                        else
                            send "_id": res.id, 201
        else
            db.save body, (err, res) ->
                if err
                    railway.logger.write "[Create] err: " + JSON.stringify err
                    send error: err.message, 500
                else
                    send "_id": res.id, 201

# DELETE /data/:id
action 'delete', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.remove params.id, @doc.rev, (err, res) =>
        if err
            # oops unexpected error !
            console.log "[Delete] err: " + JSON.stringify err
            send error: err.message, 500
        else
            # Event is emited
            doctype = @doc.docType?.toLowerCase()
            doctype ?= 'null'
            app.feed.publish "#{doctype}.delete", @doc.id
            # Doc is removed from indexation
            client.del "index/#{params.id}/", (err, res, resbody) ->
                send success: true, 204
