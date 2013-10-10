load 'application'

async = require "async"
db = require('./helpers/db_connect_helper').db_connect()
checkDocType = require('./lib/token').checkDocType
request = require('./lib/request')


# Before and after methods

# Check if application is authorized to manipulate docType given in params.type
###before 'permissions', ->
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
, only: ['definition', 'remove']###


## Actions


# PUT /filter/:req_name
action 'definition', ->
    console.log "definition filter"
    # no need to precise language because it's javascript
    db.get "_design/filter", (err, res) =>
        if err && err.error is 'not_found'
            design_doc = {}
            design_doc[params.req_name] = body.filter
            console.log design_doc
            db.save "_design/filter", {views: {} ,filters:design_doc}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send error: true, msg: err.message, 500
                else
                    send success: true, 200

        else if err
            send error: true, msg: err.message, 500

        else
            filters = res.filters
            filters[params.req_name] = body.filter
            db.merge "_design/filter", {filters:filters}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send error: true, msg: err.message, 500
                else
                    send success: true, 200

# DELETE /filter/:type/:req_name
action 'remove', ->
    db.get "_design/filter", (err, res) =>
        if err and err.error is 'not_found'
            send error: "not found", 404
        else if err
            send error: true, msg: err.message, 500
        else
            filters = res.filters
            delete filters[params.req_name]
            db.merge "_design/filter", {views:{}, filters: filters}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send error: true, msg: err.message, 500
                else
                    send success: true, 204
