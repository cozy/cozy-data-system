async = require "async"
feed = require '../lib/feed'
db = require('../helpers/db_connect_helper').db_connect()
request = require '../lib/request'
dbHelper = require '../lib/db_remove_helper'
errors = require '../middlewares/errors'

## Helpers ##

# Define random function for application's token
randomString = (length) ->
    string = ""
    while (string.length < length)
        string = string + Math.random().toString(36).substr(2)
    return string.substr 0, length

## Actions

# POST /device
module.exports.create = (req, res, next) ->
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
        if err
            next err
        else if response.length isnt 0
            next errors.http 400, "This name is already used"
        else
            db.save device, (err, docInfo) ->
                if err
                    next err
                else
                    device.id = docInfo._id
                    res.send 200, device

# DELETE /device/:id
module.exports.remove = (req, res, next) ->
    send_success = () ->
        # status code is 200 because 204 is not transmit by httpProxy
        res.send 200, success: true
        next()
    id = req.params.id
    db.remove "_design/#{id}", (err, response) ->
        if err
            console.log "[Definition] err: " + JSON.stringify err
            next err
        else
            dbHelper.remove req.doc, (err, response) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    next err
                else
                    send_success()
