load 'application'

git = require('git-rev')
Client = require("request-json").JsonClient

encryption = require './lib/encryption'

checkDocType = require('./lib/token').checkDocType
updatePermissions = require('./lib/token').updatePermissions
if process.env.NODE_ENV is "test"
    client = new Client "http://localhost:9092/"
else
    client = new Client "http://localhost:9102/"

db = require('./helpers/db_connect_helper').db_connect()

## Helpers
toString = ->
    "[Account for model: #{@id}]"


## Before and after methods

# Lock document to avoid multiple modifications at the same time.
before 'lock request', ->
    @lock = "#{params.id}"
    app.locker.runIfUnlock @lock, =>
        app.locker.addLock(@lock)
        next()
, only: ['update', 'upsert', 'delete', 'merge']

# Unlock document when action is finished
after 'unlock request', ->
    app.locker.removeLock @lock
, only: ['update', 'upsert', 'delete', 'merge']

# Recover document from database with id equal to params.id
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
, only: ['find','update', 'delete', 'merge']

# Check if application is authorized to manage docType of document
# docType corresponds to docType given in parameters
before 'permissions_param', ->
    auth = req.header('authorization')
    checkDocType auth, body.docType, (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err.message, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err.message, 403
        else
            compound.app.feed.publish 'usage.application', appName
            next()
, only: ['create', 'update', 'merge', 'upsert']

# Check if application is authorized to manage docType of document
# docType corresponds to docType of recovered document from database
# Required to be processed after "get doc"
before 'permissions', ->
    auth = req.header('authorization')
    checkDocType auth, @doc.docType, (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err.message, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err.message, 403
        else
            compound.app.feed.publish 'usage.application', appName
            next()
, only: ['find', 'delete', 'merge']

## Encrypt data in field password
before 'encryptPassword', ()->
    if not body.docType? or not (body.docType.toLowerCase() is "application")
        encryption.encrypt body.password, (err, password) ->
            if err?
                send error: err, 500
            else if password?
                body.password = password
    next()
, only: ['create', 'update', 'upsert']

## Encrypt data in field password
before 'encryptPassword', ()->
    if not body.docType? or not (body.docType.toLowerCase() is "application")
        if not @doc.docType? or not (@doc.docType.toLowerCase() is "application")
            encryption.encrypt body.password, (err, password) ->
                if err?
                    send error: err, 500
                else if password?
                    body.password = password
    next()
, only: ['merge']

# Decrypt data in field password
before 'decryptPassword', ()->
    if not @doc.docType? or not(@doc.docType.toLowerCase() is "application")
        encryption.decrypt @doc.password, (err, password) =>
            if err?
                send error: err, 500
            else if password?
                @doc.password = password
    next()
, only: ['find']


## Actions

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
        else
            send 500, error: JSON.stringify err

# GET /data/:id
action 'find', ->
    delete @doc._rev # CouchDB specific, user don't need it
    send @doc

# POST /data/:id
# POST /data
action 'create', ->
    delete body._attachments
    if body.docType? and body.docType.toLowerCase() is "application"
        updatePermissions body
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
    if body.docType? and body.docType.toLowerCase() is "application"
        updatePermissions body
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
    send_success = () ->
        send success: true, 204
        app.feed.feed.removeListener "deletion.#{params.id}", send_success
    # this version don't take care of conflict (erase DB with the sent value)
    db.remove params.id, @doc.rev, (err, res) =>
        if err
            # oops unexpected error !
            console.log "[Delete] err: " + JSON.stringify err
            send error: err.message, 500
        else            
            # Doc is removed from indexation
            client.del "index/#{params.id}/", (err, res, resbody) =>
                app.feed.feed.on "deletion.#{params.id}", send_success

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
