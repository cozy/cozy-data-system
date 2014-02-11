db = require('../helpers/db_connect_helper').db_connect()
feed = require '../helpers/db_feed_helper'
encryption = require '../lib/encryption'

Client = require("request-json").JsonClient
Account = require '../lib/account'
CryptoTools = require '../lib/crypto_tools'
User = require '../lib/user'

randomString = require('../lib/random').randomString
checkProxyHome = require('../lib/token').checkProxyHome
checkDocType = require('../lib/token').checkDocType
initPassword = require('../lib/init').initPassword

accountManager = new Account()
cryptoTools = new CryptoTools()
user = new User()
correctWitness = "Encryption is correct"


## Before and after methods

# Check if application which want manage encrypted keys is Proxy
module.exports.permission_keys = (req, res, next) ->
    checkProxyHome req.header('authorization'), (err, isAuthorized) ->
        if not isAuthorized
            err = new Error "Application is not authorized"
            res.send 403, error: err
        else
            next()

## Actions

#POST /accounts/password/
module.exports.initializeKeys = (req, res) ->
    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            res.send 500, error: err
        else
            ## User has already been connected
            if user.salt? and user.slaveKey?
                encryption.logIn req.body.password, user, (err)->
                    res.send 500, error: err if err?
                    initPassword ->
                        res.send 200, success: true
            ## First connection
            else
                encryption.init req.body.password, user, (err)->
                    if err
                        res.send 500, error: err
                    else
                        res.send 200, success: true


#PUT /accounts/password/
module.exports.updateKeys = (req, res) ->
    if req.body.password?
        user.getUser (err, user) ->
            if err
                console.log "[updateKeys] err: #{err}"
                res.send 500, error: err
            else
                encryption.update req.body.password, user, (err) ->
                    if err? and err is 400
                        res.send 400, error: err
                    else if err
                        res.send 500, error: err
                    else
                        res.send 200, success: true
    else
        res.send 400, "no password field in body"


#DELETE /accounts/reset/
module.exports.resetKeys = (req, res) ->
    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            res.send 500, error: err
        else
            encryption.reset user, (err) ->
                if err
                    send 500, error: err
                else
                    send 204, success: true


#DELETE /accounts/
module.exports.deleteKeys = (req, res) ->
    encryption.logOut (err) ->
        if err
            res.send 500, error: err
        else
            res.send 204, sucess: true

