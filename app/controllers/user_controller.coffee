load 'application'

git = require('git-rev')
Client = require("request-json").JsonClient
keys = require './lib/encryption'

checkDocType = require('./lib/token').checkDocType
client = new Client "http://localhost:9102/"
db = require('./helpers/db_connect_helper').db_connect()


before 'permissions_add', ->
    checkDocType req.header('authorization'), "User", (err, isAuthenticated, isAuthorized) =>
        next()
, only: ['create','merge']

before 'lock request', ->
    @lock = "#{params.id}"
    app.locker.runIfUnlock @lock, =>
        app.locker.addLock(@lock)
        next()
, only: ['merge']

after 'unlock request', ->
    app.locker.removeLock @lock
, only: ['merge']

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
, only: ['merge']

before 'permissions', ->
    checkDocType req.header('authorization'), @doc.docType, (err, isAuthenticated, isAuthorized) =>
        next()
, only: ['merge']

# POST /user
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

# PUT /user/merge/:id
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