load 'application'

Client = require("request-json").JsonClient
db = require('../../helpers/db_connect_helper').db_connect()
crypto = require '../../lib/crypto'
user = require '../../lib/user'
randomString = require('../../lib/random').randomString

crypto = new Crypto()
client = new Client("http://localhost:9102/")


before 'get doc', ->
    db.get params.id, (err, doc) =>
        if err and err.error is "not_found"
            send 404
        else if err
            console.log "[Get doc] err: #{err}"
            send 500
        else if doc?
            @doc = doc
            next()
        else
            send 404
, only: ['findAccount']


# POST /accounts/password/
action 'initializeMasterKey', =>
    app.user.getUser (err, user) ->
        if err
            console.log "[Merge] err: #{err}"
            send 500
        else
            app.crypto = {} if app.crypto?
            if user.salt? and user.slaveKey?
                app.crypto.masterKey =
                    app.crypto.genHashWithSalt body.pwd, user.salt
                app.crypto.slaveKey = user.slaveKey
                send 200
            else
                salt = crypto.genSalt(32 - body.pwd.length)
                masterKey = crypto.genHashWithSalt body.pwd, salt
                slaveKey = randomString()
                encryptedSlaveKey = crypto.encrypt masterKey, slaveKey
                app.crypto.masterKey = masterKey
                app.crypto.slaveKey  = encryptedSlaveKey
                data = salt: salt, slaveKey: encryptedSlaveKey
                db.merge user._id, data, (err, res) =>
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
    if body.pwd
        @slaveKey = crypto.decrypt app.crypto.masterKey, app.crypto.slaveKey
        @newPwd = crypto.encrypt @slaveKey, body.pwd
        body.pwd = @newPwd
        body.docType = "Account"
        if params.id
            db.get params.id, (err, doc) -> # this GET needed because of cache
                if doc
                    send 409
                else
                    db.save params.id, body, (err, res) ->
                        if err
                            send 409
                        else
                            send _id: res.id, 201
        else
            db.save body, (err, res) ->
                if err
                    railway.logger.write "[Create] err: #{err}"
                    send 500
                else
                    send _id: res.id, 201
    else
        send 409


#PUT /account/:id

#PUT /account/merge/:id

#GET /account/:id
action 'findAccount', ->
    delete @doc._rev # CouchDB specific, user don't need it
    if @doc.pwd?
        encryptedPwd = @doc.pwd
        slaveKey = crypto.decrypt app.crypto.masterKey, app.crypto.slaveKey
        @doc.pwd = app.crypto.decrypt slaveKey, encryptedPwd
        send @doc
    else
        send 500

#GET /account/exist/:id

#DELETE /account/:id

###

#POST /account/:id

#GET /account/upsert/:id

