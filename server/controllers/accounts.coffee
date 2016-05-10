db = require('../helpers/db_connect_helper').db_connect()
encryption = require '../lib/encryption'

async = require 'async'
Client = require("request-json").JsonClient
User = require '../lib/user'

checkProxyHome = require('../lib/token').checkProxyHome
errors = require '../middlewares/errors'

user = new User()
apps = []


# Restart Application <app>
restartApp = (app, cb) ->
    homeClient = new Client 'http://localhost:9103'
    # Stop application via cozy-home
    homeClient.post "api/applications/#{app}/stop", {}, (err, res) ->
        console.log err if err?
        db.view 'application/byslug', {key: app}, (err, appli) ->
            # Recover manifest
            if appli[0]?
                appli = appli[0].value
                descriptor =
                    user: appli.slug
                    name: appli.slug
                    domain: "127.0.0.1"
                    repository:
                        type: "git",
                        url: appli.git
                    scripts:
                        start: "server.coffee"
                    password: appli.password
                # Start application via cozy-home
                url = "api/applications/#{app}/start"
                homeClient.post url, {start: descriptor}, (err, res) ->
                    console.log err if err?
                    cb()
            else
                cb()

# Add application in array <tabs> : use to restart application
module.exports.addApp = (app) ->
    unless app in apps
        apps.push app

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
            isLog = encryption.isLog()
            encryption.logIn req.body.password, user, (err)->
                return next err if err
                if isLog
                    res.status(200).send success: true
                else
                    # Temporary : restart application which use encrypted data
                    async.forEach apps, (app, cb) ->
                        restartApp app, cb
                    , (err) ->
                        console.log err if err?
                        res.status(200).send success: true
        ## First connection
        else
            encryption.init req.body.password, user, (err)->
                return next err if err
                res.status(200).send success: true

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
                    res.status(200).send success: true


#DELETE /accounts/reset/
module.exports.resetKeys = (req, res, next) ->
    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            return next err

        encryption.reset user, (err) ->
            return next err if err

            res.status(204).send success: true
