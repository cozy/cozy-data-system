fs = require 'fs'
db = require('../helpers/db_connect_helper').db_connect()
nodemailer = require "nodemailer"
CryptoTools = require('./crypto_tools')
randomString = require('./random').randomString
logger = require('printit')(prefix: 'lib/encryption')
errors = require '../middlewares/errors'
timeout = null

User = require './user'
user = new User()

cryptoTools = new CryptoTools()

masterKey = null
slaveKey = null
day = 24 * 60 * 60 * 1000

sendEmail = (mailOptions, callback) ->
    transport = nodemailer.createTransport "SMTP", {}
    transport.sendMail mailOptions, (error, response) ->
        transport.close()
        callback error, response

getBody = (domain) ->
    body =  """
        Hello,

        Your Cozy has been recently restarted.
        For security reasons, a restart disables encryption and decryption.
        Some features of your applications are therefore desactivated.
        They will be reactivated automatically when you will log into your Cozy instance.
        """
    if domain? and domain isnt ''
        body += "Click here to login #{domain}."

    body += """

        Cozy Team.

        P-S: If you have any question, let us know at contact@cozycloud.cc or in our IRC channel #cozycloud on freenode.net.

        """
    return body



resetTimeout = -> timeout = null
sendMailNow = ->
    if (masterKey? and slaveKey?)
        return resetTimeout()

    user.getUser (err, user) ->
        if err
            logger.error "[sendMailToUser] an error occured while" +
                " retrieving user data from database:"
            logger.raw err
        else
            db.view 'cozyinstance/all', (err, instance) ->
                if instance?[0]?.value.domain?
                    domain = instance[0].value.domain
                else
                    domain = false
                mailOptions =
                    to: user.email
                    from: "noreply@cozycloud.cc"
                    subject: "Your Cozy has been restarted"
                    text: getBody(domain)
                sendEmail mailOptions, (error, response) ->
                    logger.error error if error?


                timeout = setTimeout resetTimeout, 3*day

sendMail = ->
    if timeout is null
        timeout = setTimeout sendMailNow, 1*day


## function updateKeys (oldKey,password, encryptedslaveKey, callback)
## @oldKey {string} Old master key
## @password {string} user's password
## @encryptedslaveKey {string} encrypted slave key
## @callback {function} Continuation to pass control back to when complete.
## Update keys, return in data new encrypted slave key and new salt
updateKeys = (oldKey, password, encryptedslaveKey, callback) ->
    salt = cryptoTools.genSalt(32 - password.length)
    masterKey = cryptoTools.genHashWithSalt password, salt
    encryptedSlaveKey = cryptoTools.encrypt masterKey, slaveKey
    data = slaveKey: encryptedSlaveKey, salt: salt
    callback data


## function encrypt (password, callback)
## @password {string} document password
## @callback {function} Continuation to pass control back to when complete.
## Return encrypted password
exports.encrypt = (password) ->
    if password? and process.env.NODE_ENV isnt "development"
        if masterKey? and slaveKey?
            newPwd = cryptoTools.encrypt slaveKey, password
            return newPwd
        else
            sendMail()
            err = new Error "master key and slave key don't exist"
            logger.error err.message
            throw err
    else
        return password


exports.get = () -> return masterKey


## function decrypt (password, callback)
## @password {string} document password
## @callback {function} Continuation to pass control back to when complete.
## Return decrypted password if password was encrypted
exports.decrypt = (password) ->
    if password? and process.env.NODE_ENV isnt "development"
        if masterKey? and slaveKey?
            newPwd = password
            try
                newPwd = cryptoTools.decrypt slaveKey, password
            return newPwd
        else
            sendMail()
            err = "master key and slave key don't exist"
            logger.error "[decrypt]: #{err}"
            throw err
    else
        return password


## function init (password, user, callback)
## @password {string} user's password
## @user {object} user
## @callback {function} Continuation to pass control back to when complete.
## Init keys at the first connection
exports.init = (password, user, callback) ->
    # Generate salt and masterKey
    salt = cryptoTools.genSalt(32 - password.length)
    masterKey = cryptoTools.genHashWithSalt password, salt
    # Generate slaveKey
    slaveKey = randomString()
    encryptedSlaveKey = cryptoTools.encrypt masterKey, slaveKey
    # Store in database
    data = salt: salt, slaveKey: encryptedSlaveKey
    db.merge user._id, data, (err, res) =>
        if err
            logger.error "[initializeKeys] err: #{err}"
            callback err
        else
            callback null


## function login (password, user, callback)
## @password {string} user's password
## @user {object} user
## @callback {function} Continuation to pass control back to when complete.
## Init keys when user log in
exports.logIn = (password, user, callback) ->
    # Recover master and slave keys
    masterKey =
        cryptoTools.genHashWithSalt(password, user.salt)
    encryptedSlaveKey = user.slaveKey
    slaveKey =
        cryptoTools.decrypt masterKey, encryptedSlaveKey
    callback()


## function update (pasword, user, callback)
## @password {string} user's password
## @user {object} user
## @callback {function} Continuation to pass control back to when complete.
## Update keys when user changes his password
exports.update = (password, user, callback) ->
    unless masterKey? and slaveKey?
        err = errors.http 400, "masterKey and slaveKey don't exist"
        logger.error "[update] : #{err}"
        return callback err

    if masterKey.length isnt 32
        err = errors.http 400, """
            password to initialize keys is different than user password"""
        logger.error "[update] : #{err}"
        return callback err

    updateKeys masterKey, password, slaveKey, (data) =>
        db.merge user._id, data, (err, res) =>
            if err
                logger.error "[update] : #{err}"
                return callback err

            callback null

## function reset (pasword, user, callback)
## @password {string} user's password
## @user {object} user
## @callback {function} Continuation to pass control back to when complete.
## Reset keys when user resets his password
exports.reset = (user, callback) ->
    data = slaveKey: null, salt: null
    db.merge user._id, data, (err, res) =>
        if err
            callback new Error "[resetKeys] err: #{err}"
        else
            callback()

## function isLog ()
## Return if keys exist so if user is connected
exports.isLog = () ->
    return slaveKey? and masterKey?
