async = require "async"
db = require('../helpers/db_connect_helper').db_connect()
checkDocType = require('../lib/token').checkDocType
request = require '../lib/request'
filter = require '../lib/default_filter'
locker = require '../lib/locker'
feed = require '../helpers/db_feed_helper'

# Before and after methods

# Check if application is authorized to manipulate docType given in params.type
module.exports.permissions = (req, res, next) ->
    auth = req.header 'authorization'
    checkDocType auth, "device", (err, appName, isAuthorized) =>
        if not appName
            err = new Error "Application is not authenticated"
            res.send error: err, 401
        else if not isAuthorized
            err = new Error "Application is not authorized"
            res.send error: err, 403
        else
            @appName = appName
            next()

## Helpers ##

# Define random function for application's token
randomString = (length) ->
    string = ""
    while (string.length < length)
        string = string + Math.random().toString(36).substr(2)
    return string.substr 0, length

createFilter = (id, callback) ->
    db.get "_design/#{id}", (err, res) =>
        if err && err.error is 'not_found'
            designDoc = {}
            filterFunction = filter.get id
            designDoc.filter = filterFunction
            filterDocTypeFunction = filter.getDocType id
            designDoc.filterDocType = filterDocTypeFunction
            db.save "_design/#{id}", {views: {} ,filters:designDoc}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    callback err.message
                else
                    callback null

        else if err
            callback err.message

        else
            designDoc = res.filters
            filterName = id + "filter"
            filterFunction = filter.get id
            designDoc.filter = filterFunction
            db.merge "_design/#{id}", {filters:designDoc}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    callback err.message
                else
                    callback null

## Actions

# POST /device
module.exports.create = (req, res) ->
    # Create device
    device =
        login: req.body.login
        password: randomString 32
        docType: "Device"
        configuration:
            "File": "all"
            "Folder": "all"
    # Check if an other device hasn't the same name
    db.view 'device/byLogin', key: device.login, (err, response) ->
        if err?
            res.send 500, error: err
        else if response.length isnt 0
            res.send 400, error: "This name is already used"
        else
            db.save device, (err, docInfo) =>
                # Create filter
                createFilter docInfo._id, (err) ->
                    if err?
                        res.send 500, error: err
                    else
                        device.id = docInfo._id
                        res.send 200, device

# DELETE /device/:id
module.exports.remove = (req, res, next) ->
    send_success = () ->
        feed.feed.removeListener "deletion.#{req.params.id}", send_success
        next()
        # status code is 200 because 204 is not transmit by httpProxy
        res.send 200, success: true
    id = req.params.id
    db.remove "_design/#{id}", (err, response) =>
        if err?
            console.log "[Definition] err: " + JSON.stringify err
            next()
            res.send 500, error: err.message
        else
            db.remove id, req.doc._rev, (err, response) ->
                if err?
                    console.log "[Definition] err: " + JSON.stringify err
                    next()
                    res.send 500, error: err.message
                else
                    feed.feed.on "deletion.#{req.params.id}", send_success
