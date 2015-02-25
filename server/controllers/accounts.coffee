db = require('../helpers/db_connect_helper').db_connect()
encryption = require '../lib/encryption'

Client = require("request-json").JsonClient
CryptoTools = require '../lib/crypto_tools'
User = require '../lib/user'

randomString = require('../lib/random').randomString
checkProxyHome = require('../lib/token').checkProxyHome
errors = require '../middlewares/errors'

cryptoTools = new CryptoTools()
user = new User()
correctWitness = "Encryption is correct"

## Before and after methods

# Check if application which want manage encrypted keys is Proxy
module.exports.checkPermissions = (req, res, next) ->
    checkProxyHome req.header('authorization'), (err, isAuthorized) ->
        if not isAuthorized
            next errors.notAuthorized()
        else
            next()

## Actions

#POST /accounts/password/
module.exports.initializeKeys = (req, res, next) ->
    if not req.body.password?
        return next errors.http 400, "No password field in request's body"

    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            return next err

        ## User has already been connected
        if user.salt? and user.slaveKey?
            encryption.logIn req.body.password, user, (err)->
                if err
                    next err
                else
                    res.send 200, success: true
        ## First connection
        else
            encryption.init req.body.password, user, (err)->
                return if err
                    next err
                else
                    res.send 200, success: true

#PUT /accounts/password/
module.exports.updateKeys = (req, res, next) ->
    unless req.body.password?
        return next errors.http 400,  "No password field in request's body"

    user.getUser (err, user) ->
        if err
            console.log "[updateKeys] err: #{err}"
            next err
        else
            encryption.update req.body.password, user, (err) ->
                if err
                    next err
                else
                    res.send 200, success: true


#DELETE /accounts/reset/
module.exports.resetKeys = (req, res, next) ->
    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            return next err

        encryption.reset user, (err) ->
            return next err if err

            res.send 204, success: true


#DELETE /accounts/
## TODO : Remove this function (wait proxy updating)
module.exports.deleteKeys = (req, res) ->
    res.send 204, sucess: true

