load 'application'

git = require('git-rev')

Client = require("request-json").JsonClient
client = new Client("http://localhost:9102/")
db = require('../../helpers/db_connect_helper').db_connect()
crypto = require('../../lib/crypto.coffee')

before 'lock request', ->
    @lock = "#{params.id}"
    app.locker.runIfUnlock @lock, =>
        app.locker.addLock(@lock)
        next()
, only: ['update', 'upsert', 'delete', 'merge']

after 'unlock request', ->
    app.locker.removeLock @lock
, only: ['update', 'upsert', 'delete', 'merge']

###before 'get doc', ->
    db.get params.id, (err, doc) =>
        if err and err.error == "not_found"
            app.locker.removeLock @lock
            send 404
        else if err
            console.log "[Get doc] err: " + JSON.stringify err
            app.locker.removeLock @lock
            send 500
        else if doc?
            @doc = doc
            next()
        else
            app.locker.removeLock @lock
            send 404
, only: ['find','update', 'delete', 'merge']###

# POST /accounts/password/
action 'initializeMasterKey', ->
    delete body._attachments

    # je vais chercher salt dans la base de donnée db.
    # if salt exist -> on utilise l'existant 
    # sinon salt = crypto.randomBytes(32-body.userPwd.length) 
    # et enregister salt dans la BD

    app.crypto.masterKey = app.crypto.genHashWithSalt(body.userPwd, salt)
    