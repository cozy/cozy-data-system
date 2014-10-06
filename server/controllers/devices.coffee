async = require "async"
feed = require '../lib/feed'
db = require('../helpers/db_connect_helper').db_connect()
request = require '../lib/request'
default_filter = require '../lib/default_filter'
dbHelper = require '../lib/db_remove_helper'

## Helpers ##

# Define random function for application's token
randomString = (length) ->
    string = ""
    while (string.length < length)
        string = string + Math.random().toString(36).substr(2)
    return string.substr 0, length

createFilter = (id, callback) ->
    db.get "_design/#{id}", (err, res) ->
        if err && err.error is 'not_found'
            # setup the default filters (replicate Files & Folders)
            designDoc =
                views:
                    filterView: map: default_filter.asView id
                filters:
                    filter: default_filter.get id
                    filterDocType: default_filter.getDocType id

            db.save "_design/#{id}", designDoc, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    callback err.message
                else
                    callback null

        else if err
            callback err.message

        else
            designDoc = res.filters
            filterFunction = default_filter.get id
            designDoc.filter = filterFunction
            db.merge "_design/#{id}", {filters:designDoc}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    callback err.message
                else
                    callback null

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
            err = new Error "This name is already used"
            err.status = 400
            next err
        else
            db.save device, (err, docInfo) ->
                # Create filter
                createFilter docInfo._id, (err) ->
                    if err?
                        next new Error err
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
        if err?
            console.log "[Definition] err: " + JSON.stringify err
            next new Error err.error
            next()
        else
            dbHelper.remove req.doc, (err, response) ->
                if err?
                    console.log "[Definition] err: " + JSON.stringify err
                    next new Error err.error
                else
                    send_success()
