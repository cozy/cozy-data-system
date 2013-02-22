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
    if @body.pwd
        slaveKey = crypto.decrypt app.crypto.masterKey, app.crypto.slaveKey
        newPwd = crypto.encrypt slaveKey, @body.pwd
        @body.pwd = newPwd
        @body.docType = "Account"
        callback true
    else
        callback false


# POST /accounts/password/
action 'initializeKeys', =>
    user.getUser (err, user) ->
        if err
            console.log "[Merge] err: #{err}"
            send 500
        else
            app.crypto = {} if !(app.crypto?)
            if user.salt? and user.slaveKey?
                app.crypto.masterKey =
                    crypto.genHashWithSalt body.pwd, user.salt
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
                        console.log "[Merge] err: #{err}"
                        send 500
                    else
                        send 200


#PUT /accounts/password/
action 'updateKeys', ->
    if body.pwd?
        user.getUser (err, user) ->
            if err
                console.log "[Merge] err: #{err}"
                send 500
            else
                slaveKey =
                    crypto.decrypt app.crypto.masterKey, app.crypto.slaveKey
                app.crypto.masterKey =
                    crypto.genHashWithSalt body.pwd, user.salt
                app.crypto.slaveKey =
                    crypto.encrypt app.crypto.masterKey, slaveKey
                data = slaveKey: app.crypto.slaveKey
                db.merge user._id, data, (err, res) =>
                    if err
                        console.log "[Merge] err: #{err}"
                        send 500
                    else
                        send 200
    else
        send 500


#DELETE /accounts/
action 'deleteKeys', ->
    app.crypto.masterKey = null
    app.crypto.slaveKey = null
    send 204


#POST /account/:id
#POST /account/
action 'createAccount', ->
    @body = body
    encryptPassword (pwdExist) ->
        if pwdExist
            newBody = @body
            if params.id
                db.get params.id, (err, doc) ->
                    if doc
                        send 409
                    else
                        db.save params.id, newBody, (err, res) ->
                            if err
                                send 409
                            else
                                send _id: res.id, 201
            else
                db.save @body, (err, res) ->
                    if err
                        railway.logger.write "[Create] err: #{err}"
                        send 500
                    else
                        send _id: res.id, 201
        else
            send 409


#GET /account/:id
action 'findAccount', ->
    delete @doc._rev # CouchDB specific, user don't need it
    if @doc.pwd?
        encryptedPwd = @doc.pwd
        slaveKey = crypto.decrypt app.crypto.masterKey, app.crypto.slaveKey
        @doc.pwd = crypto.decrypt slaveKey, encryptedPwd
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
    encryptPassword (pwdExist) ->
        if pwdExist
            db.save params.id, @body, (err, res) ->
                if err
                    # oops unexpected error !
                    console.log "[Update] err: #{err}"
                    send 500
                else
                    send 200
        else
            send 500


#PUT /account/merge/:id
action 'mergeAccount', ->
    @body = body
    encryptPassword (pwdExist) ->
        db.merge params.id, @body, (err, res) ->
            if err
                # oops unexpected error !
                console.log "[Merge] err: #{err}"
                send 500
            else
                send success: true, 200



#PUT /account/upsert/:id
action 'upsertAccount', ->
    @body = body
    encryptPassword (pwdExist) ->
        if pwdExist
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
            console.log "[Delete] err: #{err}"
        else
            # Doc is removed from indexation
            client.del "index/#{params.id}/", (err, res, resbody) ->
                send 204