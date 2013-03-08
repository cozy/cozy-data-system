load 'application'

Client = require("request-json").JsonClient

Crypto = require '../../lib/crypto'
User = require '../../lib/user'
randomString = require('../../lib/random').randomString


client = new Client("http://localhost:9102/")
crypto = new Crypto()
user = new User()
db = require('../../helpers/db_connect_helper').db_connect()


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
, only: ['findAccount', 'updateAccount', 'mergeAccount', 'deleteAccount']


# helpers
encryptPassword = (callback)->
    if @body.password
        if app.crypto? and app.crypto.masterKey and app.crypto.slaveKey
            slaveKey = crypto.decrypt app.crypto.masterKey, app.crypto.slaveKey
            newPwd = crypto.encrypt slaveKey, @body.password
            @body.password = newPwd
            @body.docType = "Account"
            callback true
        else
            callback false, new Error("master key and slave key don't exist")
    else
        callback false

toString = ->
    "[Account for model: #{@id}]"


# POST /accounts/password/
action 'initializeKeys', =>
    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            send 500
        else
            app.crypto = {} if not app.crypto?
            if user.salt? and user.slaveKey?
                app.crypto.masterKey =
                    crypto.genHashWithSalt body.password, user.salt
                app.crypto.slaveKey = user.slaveKey
                send 200
            else
                salt = crypto.genSalt(32 - body.password.length)
                masterKey = crypto.genHashWithSalt body.password, salt
                slaveKey = randomString()
                encryptedSlaveKey = crypto.encrypt masterKey, slaveKey
                app.crypto.masterKey = masterKey
                app.crypto.slaveKey  = encryptedSlaveKey
                data = salt: salt, slaveKey: encryptedSlaveKey
                db.merge user._id, data, (err, res) =>
                    if err
                        console.log "[initializeKeys] err: #{err}"
                        send 500
                    else
                        send 200


#PUT /accounts/password/
action 'updateKeys', ->
    if body.password?
        user.getUser (err, user) ->
            if err
                console.log "[updateKeys] err: #{err}"
                send 500
            else
                if app.crypto? and app.crypto.masterKey? and
                        app.crypto.slaveKey?
                    slaveKey =
                        crypto.decrypt app.crypto.masterKey, app.crypto.slaveKey
                    salt = crypto.genSalt(32 - body.password.length)
                    app.crypto.masterKey =
                        crypto.genHashWithSalt body.password, salt
                    app.crypto.slaveKey =
                        crypto.encrypt app.crypto.masterKey, slaveKey
                    data = slaveKey: app.crypto.slaveKey, salt: salt
                    db.merge user._id, data, (err, res) =>
                        if err
                            console.log "[updateKeys] err: #{err}"
                            send 500
                        else
                            send 200
                else
                    console.log "[updateKeys] err: masterKey and slaveKey don't\
                        exist"
                    send 500
    else
        send 500


#DELETE /accounts/
action 'deleteKeys', ->
    if app.crypto? and app.crypto.masterKey and app.crypto.slaveKey
        app.crypto.masterKey = null
        app.crypto.slaveKey = null
        send 204
    else
        console.log "[updateKeys] err: masterKey and slaveKey don't exist"
        send 500



#POST /account/
action 'createAccount', ->
    @body = body
    body.docType = "Account"
    body.toString = @toString "Account"
    encryptPassword (pwdExist, err) ->
        if err
            console.log "[createAccount] err: #{err}"
            send 500
        else
            if pwdExist
                db.save @body, (err, res) ->
                    if err
                        railway.logger.write "[createAccount] err: #{err}"
                        send 50
                    else
                        send _id: res._id, 201
            else
                send 401


#GET /account/:id
action 'findAccount', ->
    delete @doc._rev # CouchDB specific, user don't need it
    if @doc.password?
        encryptedPwd = @doc.password
        slaveKey = crypto.decrypt app.crypto.masterKey, app.crypto.slaveKey
        @doc.toString = toString
        @doc.password = crypto.decrypt slaveKey, encryptedPwd
        send @doc
    else
        send 500


#GET /account/exist/:id
action 'existAccount', ->
    db.head params.id, (err, res, status) ->
        if status is 200
            send {"exist": true}
        else if status is 404
            send {"exist": false}


#PUT /account/:id
action 'updateAccount', ->
    @body = body
    encryptPassword (pwdExist, err) ->
        if err
            console.log "[updateAccount] err: #{err}"
            send 500
        else
            if pwdExist
                db.save params.id, @body, (err, res) ->
                    if err
                        # oops unexpected error !
                        console.log "[Update] err: #{err}"
                        send 500
                    else
                        send 200
            else
                send 401


#PUT /account/merge/:id
action 'mergeAccount', ->
    @body = body
    encryptPassword (pwdExist, err) ->
        if err
            console.log "[mergeAccount] err: #{err}"
            send 500
        else
            db.merge params.id, @body, (err, res) ->
                if err
                    # oops unexpected error !
                    console.log "[Merge] err: #{err}"
                    send 500
                else
                    send 200


#PUT /account/upsert/:id
action 'upsertAccount', ->
    @body = body
    encryptPassword (pwdExist, err) ->
        if pwdExist and not err
            db.get params.id, (err, doc) ->
                db.save params.id, body, (err, res) ->
                    if err
                        # oops unexpected error !
                        console.log "[Upsert] err: #{err}"
                        send 500
                    else if doc
                        send 200
                    else
                        send {"_id": res.id}, 201
        else
            send 500


#DELETE /account/:id
action 'deleteAccount', ->
    # this version don't take care of conflict (erase DB with the sent value)
    db.remove params.id, @doc.rev, (err, res) ->
        if err
            # oops unexpected error !
            console.log "[DeleteAccount] err: #{err}"
        else
            # Doc is removed from indexation
            client.del "index/#{params.id}/", (err, res, resbody) ->
                send 204
