load 'application'

git = require('git-rev')
Client = require("request-json").JsonClient
DocType = require './lib/doctype'

client = new Client "http://localhost:9102/"
docTypeManager = new DocType()
db = require('./helpers/db_connect_helper').db_connect()

## Helpers

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


docTypeExist = (name, callback) ->

    findDocType = (name, docTypes, callback) =>
        if docTypes.length > 0
            docType = docTypes.pop()
            id = docType.value._id
            db.get id, (err, res) =>
                if err 
                    callback err
                else if res.name.toLowerCase() is name
                    callback null, true
                else 
                    findDocType name, docTypes, callback
        else
            callback null, false

    docTypeManager.getDocTypes (err, docTypes) ->
        if err
            railway.logger.write "[docTypeExist] err: " + JSON.stringify err
            send 500
        else
            findDocType name, docTypes, (err, exist) =>
                if err
                    railway.logger.write "[docTypeExist] err: " + 
                            JSON.stringify err
                    send 500
                else
                    callback null, exist


# POST /doctype
# POST /doctype/:id
action 'create', ->
    delete body._attachments
    if (body.docType? and body.docType.toLowerCase() isnt "doctype") or !body.name
        send error: "docType should be equal to 'docType' and field name are "+
                "required", 409
    else
        docTypeExist body.name.toLowerCase(), (err, exist) =>
            if exist
                send error : "docType is already created", 409
            else
                body.docType = "doctype"
                if params.id
                    db.get params.id, (err, doc) -> 
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
                            railway.logger.write "[Create] err: " + 
                                    JSON.stringify err
                            send error: err.message, 500
                        else
                            send "_id": res.id, 201

# DELETE /doctype/:id
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