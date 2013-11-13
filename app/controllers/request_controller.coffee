load 'application'

async = require "async"
db = require('./helpers/db_connect_helper').db_connect()
checkDocType = require('./lib/token').checkDocType
request = require('./lib/request')


# Before and after methods

# Check if application is authorized to manipulate docType given in params.type
before 'permissions', ->
    auth = req.header('authorization')
    checkDocType auth, params.type, (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            @appName = appName
            compound.app.feed.publish 'usage.application', appName
            next()
, except: ['doctypes']

# Lock document to avoid multiple modifications at the same time.
before 'lock request', ->
    @lock = "#{params.type}"
    compound.app.locker.runIfUnlock @lock, =>
        compound.app.locker.addLock @lock
        next()
, only: ['definition', 'remove']

# Unlock document when action is finished
after 'unlock request', ->
    compound.app.locker.removeLock @lock
, only: ['definition', 'remove']


## Actions


# GET /doctypes
# list all doctypes that have been created
# a doctype is a design document with a "all" request
action 'doctypes', ->

    query =
        group: true

    out = []

    db.view "doctypes/all", query, (err, res) ->

        if err
            send 500, err: JSON.stringify err
        else
            res.forEach (key, row, id) ->
                out.push key
            send 200, out


# POST /request/:type/:req_name
action 'results', ->
    request.get @appName, params, (path) =>
        db.view "#{params.type}/" + path, body, (err, res) ->
            if err
                if err.error is "not_found"
                    send error: "not found", 404
                else
                    console.log "[Results] err: " + JSON.stringify err
                    send error: err.message, 500
            else
                res.forEach (value) ->
                    delete value._rev # CouchDB specific, user don't need it
                send res

# PUT /request/:type/:req_name/destroy
action 'removeResults', ->
    removeFunc = (res, callback) ->
        db.remove res.value._id, res.value._rev, callback

    removeAllDocs = (res) ->
        async.forEachSeries res, removeFunc, (err) ->
            if err
                send error: err.message, 500
            else
                delFunc()

    delFunc = =>
        # db.view seems to alter the options object
        # cloning the object before each query prevents that
        query = JSON.parse JSON.stringify body
        request.get @appName, params, (path) =>
            path = "#{params.type}/" + path
            db.view path, query, (err, res) ->
                if err
                    send error: "not found", 404
                else
                    if res.length > 0
                        removeAllDocs(res)
                    else
                        send success: true, 204
    delFunc()

# PUT /request/:type/:req_name
action 'definition', ->
    # no need to precise language because it's javascript
    db.get "_design/#{params.type}", (err, res) =>
        if err && err.error is 'not_found'
            design_doc = {}
            design_doc[params.req_name] = body
            db.save "_design/#{params.type}", design_doc, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send error: err.message, 500
                else
                    send success: true, 200

        else if err
            send error: err.message, 500

        else
            views = res.views
            request.create @appName, params, views, body, (err, path) =>
                views[path] = body
                db.merge "_design/#{params.type}", {views:views}, (err, res) ->
                    if err
                        console.log "[Definition] err: " + JSON.stringify err
                        send error: err.message, 500
                    else
                        send success: true, 200

# DELETE /request/:type/:req_name
action 'remove', ->
    db.get "_design/#{params.type}", (err, res) =>
        if err and err.error is 'not_found'
            send error: "not found", 404
        else if err
            send error: err.message, 500
        else
            views = res.views
            request.get @appName, params, (path) =>
                if path is "#{params.req_name}"
                    send success: true, 204
                else
                    delete views["#{path}"]
                    db.merge "_design/#{params.type}", {views:views}, (err, res) ->
                        if err
                            console.log "[Definition] err: " + JSON.stringify err
                            send error: err.message, 500
                        else
                            send success: true, 204
