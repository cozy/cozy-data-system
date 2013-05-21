load 'application'

git = require('git-rev')
Client = require("request-json").JsonClient

client = new Client "http://localhost:9102/"
db = require('./helpers/db_connect_helper').db_connect()

authorizedDocType = []

## Helpers

publish('requireToken', requireToken)
requireToken = () ->
    if req.header('authorization')
        auth = req.header('authorization')
        # Recover application
        console.log(auth.toString('utf8'))
        next()
        db.view 'application/byToken', key: token , (err, doc) =>
            if (err)
                console.log(err)
                authorizedDocType = []
                console.log "Warning : err, application is not authenticated"
                next()
            else 
                # Check authorized docType
                console.log("Application is authenticated")
                #authorizedDocType = doc.authorizedDocType
                next()
    else
        authorizedDocType = []
        console.log "Warning : application is not authenticated"
        next()


before ->
     requireToken()  


before 'lock request', ->
    @lock = "#{params.id}"
    app.locker.runIfUnlock @lock, =>
        app.locker.addLock(@lock)
        next()
, only: ['update', 'upsert', 'delete', 'merge']

after 'unlock request', ->
    app.locker.removeLock @lock
, only: ['update', 'upsert', 'delete', 'merge']


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
            ###if authorizedDoctype.indexOf(doc) isnt -1
                @doc = doc
                next()
            else
                console.log("Application is not authorized to use this docType")
                #send error : "You are not authorized to use this docType", 404###
            @doc = doc
            next()
        else
            app.locker.removeLock @lock
            send error: "not found", 404
, only: ['find','update', 'delete', 'merge']


###before 'checkAuthorization', ->
    if params.docType? and authorizedDoctype.indexOf(params.docType) is -1
        console.log("Application is not authorized to use this docType")
        #send error : "You are not authorized to use this docType", 404
, only: ['create', 'upsert']###


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
            send "exist": true
        else if status is 404
            send "exist": false

# GET /data/:id
action 'find', ->
    delete @doc._rev # CouchDB specific, user don't need it
    send @doc
# POST /data/:id

# POST /data
action 'create', ->
    delete body._attachments
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

# PUT /data/:id
action 'update', ->
    # this version don't take care of conflict (erase DB with the sent value)
    delete body._attachments
    db.save params.id, body, (err, res) ->
        if err
            console.log "[Update] err: " + JSON.stringify err
            send error: err.message, 500
        else
            send success: true, 200

# PUT /data/upsert/:id
action 'upsert', ->
    db.get params.id, (err, doc) ->
        # this version dont take care of conflict (erase DB with the sent value)
        delete body._attachments
        db.save params.id, body, (err, res) ->
            if err
                console.log "[Upsert] err: " + JSON.stringify err
                send error: err.message, 500
            else if doc
                send success: true, 200
            else
                send {"_id": res.id}, 201

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

# PUT /data/merge/:id
action 'merge', ->
    # this version don't take care of conflict (erase DB with the sent value)
    delete body._attachments
    db.merge params.id, body, (err, res) ->
        if err
            # oops unexpected error !
            console.log "[Merge] err: " + JSON.stringify err
            send error: err.message, 500
        else
            send success: true, 200
