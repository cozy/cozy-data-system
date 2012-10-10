load 'application'

git = require('git-rev')

Client = require("request-json").JsonClient
client = new Client("http://localhost:5000/")
db = require('../../helpers/db_connect_helper').db_connect()

# Welcome page
action "index", ->
    sendVersion = (commit, branch, tag) ->
        send """
        <strong>Cozy Data System</strong><br />
        revision: #{commit}  <br /> 
        tag: #{tag} <br /> 
        branch: #{branch} <br /> 
        """, 200

    git.long (commit) ->
        git.branch (branch) ->
            git.tag (tag) ->
                 sendVersion(commit, branch, tag)

# GET /data/exist/:id
action 'exist', ->
    db.head params.id, (err, res, status) ->
        if status is 200
            send {"exist": true}
        else if status is 404
            send {"exist": false}

# GET /data/:id
action 'find', ->
    db.get params.id, (err, doc) ->
        if err
            send 404
        else
            delete doc._rev # CouchDB specific, user don't need it
            send doc

# POST /data
# POST /data/:id
action 'create', ->
    delete body._attachments
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
                railway.logger.write "[Create] err: " + JSON.stringify err
                send 500
            else
                send {"_id": res.id}, 201

# PUT /data/:id
action 'update', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        if doc
            delete body._attachments
            db.save params.id, body, (err, res) ->
                if err
                    # oops unexpected error !
                    console.log "[Update] err: " + JSON.stringify err
                    send 500
                else
                    send 200
        else
            send 404

# PUT /data/upsert/:id
action 'upsert', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        delete body._attachments
        db.save params.id, body, (err, res) ->
            if err
                # oops unexpected error !
                console.log "[Upsert] err: " + JSON.stringify err
                send 500
            else if doc
                send 200
            else
                send {"_id": res.id}, 201

# DELETE /data/:id
action 'delete', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        if doc
            db.remove params.id, doc.rev, (err, res) ->
                if err
                    # oops unexpected error !
                    console.log "[Delete] err: " + JSON.stringify err
                    send 500
                else
                    # Doc is removed from indexation
                    client.del "index/#{params.id}/", (err, res, resbody) ->
                        send 204
        else
            send 404

# PUT /data/merge/:id
action 'merge', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.get params.id, (err, doc) ->
        delete body._attachments
        if doc
            db.merge params.id, body, (err, res) ->
                if err
                    # oops unexpected error !
                    console.log "[Merge] err: " + JSON.stringify err
                    send 500
                else
                    send 200
        else
            send 404

