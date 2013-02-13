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
, only: []

after 'unlock request', ->
    app.locker.removeLock @lock
, only: []

before 'get doc', ->
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
, only: []

# POST /accounts/password/
action 'initializeMasterKey', ->
    delete body._attachments
    # recover the User
    db.view 'all/user', {} , (err, res) ->
        @res = res
    @user = @res.rows[0]
    if @user.salt?
        @salt = @user.salt
    else
        # generate the salt and save it in the database
        @salt = app.crypto.genSalt(32-body.pwd.length)
        db.merge @user._id, {"salt":@salt}, (err, res) ->
            if err
                console.log "[Merge] err: " + JSON.stringify err
                send 500
    app.crypto.masterKey = app.crypto.genHashWithSalt(body.pwd, @salt) 
    send 200

#DELETE /accounts/
action 'deleteMasterKey', ->
    app.crypto.masterKey = null
    send 204

