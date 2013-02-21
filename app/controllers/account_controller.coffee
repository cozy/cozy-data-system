load 'application'

Client = require("request-json").JsonClient
client = new Client("http://localhost:9102/")
db = require('../../helpers/db_connect_helper').db_connect()
crypto = require('../../lib/crypto.coffee')
user = require('../../lib/user.coffee')


#Helpers
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
, only: ['findAccount']


randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length



# POST /accounts/password/
action 'initializeMasterKey', =>
    delete body._attachments
    app.user.getUser (err, res) ->
        if err
            console.log "[Merge] err: " + JSON.stringify err
            send 500
        else
            user = res
            if user.salt? && user.slaveKey?
                app.crypto.masterKey = 
                        app.crypto.genHashWithSalt body.pwd, user.salt
                app.crypto.slaveKey = user.slaveKey
                send 200
            else 
                salt = app.crypto.genSalt 32-body.pwd.length
                masterKey = app.crypto.genHashWithSalt body.pwd, salt
                slaveKey = randomString()
                encryptedSlaveKey = app.crypto.encrypt masterKey, slaveKey
                app.crypto.masterKey = masterKey
                app.crypto.slaveKey  = encryptedSlaveKey
                db.merge user._id, {salt: salt, slaveKey: encryptedSlaveKey}, \
                            (err, res) =>
                    if err
                        console.log "[Merge] err: " + JSON.stringify err
                        send 500
                    else
                        send 200


#DELETE /accounts/
action 'deleteMasterKey', ->
    app.crypto.masterKey = null
    app.crypto.slaveKey = null
    send 204


#POST /account/:id
#POST /account/
action 'createAccount', ->
    delete body._attachments
    if body.pwd
        @slaveKey = app.crypto.decrypt app.crypto.masterKey, app.crypto.slaveKey
        @newPwd = app.crypto.encrypt @slaveKey, body.pwd
        body.pwd = @newPwd
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
    else
        send 409


#PUT /account/:id

#PUT /account/merge/:id

#GET /account/:id
action 'findAccount', ->
    delete @doc._rev # CouchDB specific, user don't need it
    if @doc.pwd?
        @encryptedPwd = @doc.pwd
        @slaveKey = app.crypto.decrypt app.crypto.masterKey, app.crypto.slaveKey
        @pwd = app.crypto.decrypt @slaveKey, @encryptedPwd
        @doc.pwd = @pwd
        send @doc
    else
        send 500

#GET /account/exist/:id

#DELETE /account/:id

###

#POST /account/:id

#GET /account/upsert/:id

