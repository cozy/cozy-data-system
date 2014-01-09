load 'application'

Client = require("request-json").JsonClient

Account = require './lib/account'
CryptoTools = require './lib/crypto_tools'
User = require './lib/user'
randomString = require('./lib/random').randomString

accountManager = new Account()

checkProxyHome = require('./lib/token').checkProxyHome
checkDocType = require('./lib/token').checkDocType
cryptoTools = new CryptoTools()
user = new User()
keys = require('./lib/encryption')
initPassword = require('./lib/init').initPassword
db = require('./helpers/db_connect_helper').db_connect()
correctWitness = "Encryption is correct"


## Before and after methods

# Check if application which want manage encrypted keys is Proxy
before 'permission_keys', ->
    console.log("permission_keys")
    checkProxyHome req.header('authorization'), (err, isAuthorized) =>
        if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            next()
, only: ['initializeKeys','updateKeys', 'deleteKeys', 'resetKeys']

# Check if application is authorized to manage EncryptedKeys sdocType
before 'permission', ->
    auth = req.header('authorization')
    checkDocType auth, "Account",  (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            compound.app.feed.publish 'usage.application', appName
            next()
, only: ['createAccount', 'findAccount', 'existAccount', 'updateAccount',
        'upsertAccount', 'deleteAccount', 'deleteAllAccounts', 'mergeAccount']

# Recover doc from database  with id equal to params.id
# and check if decryption of witness is correct
before 'get doc with witness', ->
    # Recover doc
    db.get params.id, (err, doc) =>
        if err and err.error is "not_found"
            send 404
        else if err
            console.log "[Get doc] err: #{err}"
            send 500
        else if doc?
            if app.crypto? and app.crypto.masterKey and app.crypto.slaveKey
                slaveKey = cryptoTools.decrypt app.crypto.masterKey,
                    app.crypto.slaveKey
                if doc.witness?
                    try
                        # Check witness decryption
                        witness = cryptoTools.decrypt slaveKey, doc.witness
                        if witness is correctWitness
                            @doc = doc
                            next()
                        else
                            console.log "[Get doc] err: data are corrupted"
                            send 402
                    catch err
                        console.log "[Get doc] err: data are corrupted"
                        send 402
                else
                    # Add witness in document for the next time
                    witness = cryptoTools.encrypt slaveKey, correctWitness
                    db.merge params.id, witness: witness, (err, res) =>
                        if err
                            console.log "[Merge] err: #{err}"
                            send 500
                        else
                            @doc = doc
                            next()
            else
                console.log "err : master key and slave key don't exist"
                send 500
        else
            send 404
, only: ['findAccount', 'updateAccount', 'mergeAccount']

# Recover document from database with id equal to params.id
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
, only: ['deleteAccount']


## Helpers

## function encryptPassword (body, callback)
## @body {Object} Application:
##    * body.password : password to be encrypted
## @callback {function} Continuation to pass control back to when complete.
## Encrypt password of application and add docType "Account"
encryptPassword = (body, callback)->
    app = compound.app
    if body.password
        if app.crypto? and app.crypto.masterKey and app.crypto.slaveKey
            slaveKey =
                cryptoTools.decrypt app.crypto.masterKey, app.crypto.slaveKey
            newPwd = cryptoTools.encrypt slaveKey, body.password
            body.password = newPwd
            body.docType = "Account"
            witness = cryptoTools.encrypt slaveKey, correctWitness
            body.witness = witness
            callback true
        else
            callback false, new Error("master key and slave key don't exist")
    else
        callback false

## function toString ()
## Helpers to hide password in logger
toString = ->
    "[Account for model: #{@id}]"


## Actions

#POST /accounts/password/
action 'initializeKeys', =>
    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            send 500
        else
            ## User has already been connected
            if user.salt? and user.slaveKey?
                keys.logIn body.password, user, (err)->
                    send error: err, 500 if err?
                    initPassword () =>
                        send success: true
            ## First connection
            else
                keys.init body.password, user, (err)->
                    if err
                        send error: err, 500
                    else
                        send success: true


#PUT /accounts/password/
action 'updateKeys', ->
    if body.password?
        user.getUser (err, user) ->
            if err
                console.log "[updateKeys] err: #{err}"
                send 500
            else
                keys.update body.password, user, (err) ->
                    if err
                        send error: err, 500
                    else
                        send success: true
    else
        send 500


#DELETE /accounts/reset/
action 'resetKeys', ->
    console.log("resetKeys")
    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            send 500
        else
            console.log('reset')
            keys.reset user, (err) ->
                if err
                    send error:err, 500
                else
                    send success: true, 204


#DELETE /accounts/
action 'deleteKeys', ->
    keys.logOut (err) ->
        if err
            send error: err, 500
        else
            send sucess: true, 204


#POST /account/
action 'createAccount', ->
    body.docType = "Account"
    body.toString = toString
    encryptPassword body, (pwdExist, err) ->
        if err
            console.log "[createAccount] err: #{err}"
            send 500
        else
            if pwdExist
                db.save body, (err, res) ->
                    if err
                        railway.logger.write "[createAccount] err: #{err}"
                        send 500
                    else
                        send _id: res._id, 201
            else
                send 401


#GET /account/:id
action 'findAccount', ->
    delete @doc._rev # CouchDB specific, user don't need it
    if @doc.password?
        encryptedPwd = @doc.password
        slaveKey = cryptoTools.decrypt app.crypto.masterKey, app.crypto.slaveKey
        @doc.password = cryptoTools.decrypt slaveKey, encryptedPwd
        @doc.toString = toString
        send @doc
    else
        send 500


#GET /account/exist/:id
action 'existAccount', ->
    db.head params.id, (err, res, status) ->
        if status is 200
            send exist: true
        else if status is 404
            send exist: false


#PUT /account/:id
action 'updateAccount', ->
    encryptPassword body, (pwdExist, err) ->
        if err
            console.log "[updateAccount] err: #{err}"
            send 500
        else
            if pwdExist
                db.save params.id, body, (err, res) ->
                    if err
                        # oops unexpected error !
                        console.log "[updateAccount] err: #{err}"
                        send 500
                    else
                        send success: true
            else
                send 401


#PUT /account/merge/:id
action 'mergeAccount', ->
    encryptPassword body, (pwdExist, err) ->
        if err
            console.log "[mergeAccount] err: #{err}"
            send 500
        else
            db.merge params.id, body, (err, res) ->
                if err
                    # oops unexpected error !
                    console.log "[Merge] err: #{err}"
                    send 500
                else
                    send success: true


#PUT /account/upsert/:id
action 'upsertAccount', ->
    encryptPassword body, (pwdExist, err) ->
        if pwdExist and not err
            db.get params.id, (err, doc) ->
                db.save params.id, body, (err, res) ->
                    if err
                        # oops unexpected error !
                        console.log "[Upsert] err: #{err}"
                        send 500
                    else if doc
                        send success: true
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
            send 500
        else
            send 204


#DELETE /account/all
action 'deleteAllAccounts', ->

    deleteAccounts = (accounts, callback) =>
        if accounts.length > 0
            account = accounts.pop()
            id = account.value._id
            db.remove id, account.value._rev, (err, res) =>
                if err
                    callback err
                else
                    deleteAccounts accounts, callback
        else
            callback()

    accountManager.getAccounts (err, accounts) ->
        if err
            send 500
        else
            deleteAccounts accounts, (err) =>
                if err
                    send 500
                else
                    send 204

