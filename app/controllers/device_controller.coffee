load 'application'

async = require "async"
db = require('./helpers/db_connect_helper').db_connect()
checkDocType = require('./lib/token').checkDocType
request = require('./lib/request')
filter = require('./lib/default_filter')


# Before and after methods

# Check if application is authorized to manipulate docType given in params.type
before 'permissions', ->
    auth = req.header('authorization')
    checkDocType auth, "device", (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            @appName = appName
            next()

# Lock document to avoid multiple modifications at the same time.
before 'lock request', ->
    @lock = "#{params.id}"
    app.locker.runIfUnlock @lock, =>
        app.locker.addLock(@lock)
        next()
, only: ['remove']

# Unlock document when action is finished
after 'unlock request', ->
    app.locker.removeLock @lock
, only: ['remove']

# Recover document from database with id equal to params.id
before 'get doc', ->
    db.get params.id, (err, doc) =>
        if err and err.error is "not_found"
            app.locker.removeLock @lock
            send error: "not found", 404
        else if err
            console.log "[Get doc] err: " + JSON.stringify err
            app.locker.removeLock @lock
            send error: err, 500
        else if doc?
            @doc = doc
            next()
        else
            app.locker.removeLock @lock
            send error: "not found", 404
, only: ['remove']

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
            filterFunction = filter.get(id)
            if filterFunction is null
                send error: true, msg: "This default filter doesn't exist", 400
            designDoc.filter = filterFunction
            db.save "_design/#{id}", {views: {} ,filters:designDoc}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send error: true, msg: err.message, 500
                else
                    callback null

        else if err
            callback err.message

        else
            designDoc = res.filters
            filterName = id + "filter"
            filterFunction = filter.get(defaultFilter, id)
            designDoc.filter = filterFunction
            db.merge "_design/#{id}", {filters:designDoc}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send error: true, msg: err.message, 500
                else
                    callback null

## Actions

# POST /device
action 'create', ->
    # Create device
    device =
        login: body.login
        password: randomString 32
        docType: "Device"
        configuration: 
            "File": "all"
            "Folder": "all"
    # Check if an other device hasn't the same name
    db.view 'device/byLogin', key: device.login, (err, res) ->
        if res.length isnt 0
            send error:true, msg: "This name is already used", 400
        else
            db.save device, (err, res) =>
                # Create filter
                createFilter res._id, (err) ->
                    if err
                        send error:true, msg: err, 500
                    else
                        device.id = res._id
                        send device, 200
        

# DELETE /device/:id
action 'remove', ->
    id = params.id
    db.remove "_design/#{id}", (err, res) =>
        if err
            console.log "[Definition] err: " + JSON.stringify err
            send error: true, msg: err.message, 500
        else
            db.remove id, @doc._rev, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send error: true, msg: err.message, 500
                else
                    send success: true, 204