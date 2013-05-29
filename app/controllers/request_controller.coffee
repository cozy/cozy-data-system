load 'application'

async = require "async"
db = require('./helpers/db_connect_helper').db_connect()
checkToken = require('./lib/token').checkToken

## Helpers
before 'requireToken', ->
    checkToken req.header('authorization'), app.tokens, (err) =>
        next()
, only: ['definition', 'results', 'remove', 'removeResults' ]    

before 'lock request', ->
    @lock = "#{params.type}"
    compound.app.locker.runIfUnlock @lock, =>
        compound.app.locker.addLock @lock

        next()
, only: ['definition', 'remove']

after 'unlock request', ->
    compound.app.locker.removeLock @lock
, only: ['definition', 'remove']

# POST /request/:type/:req_name
action 'results', ->
    db.view "#{params.type}/#{params.req_name}", body, (err, res) ->
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
                send error: true, msg: err.message, 500
            else
                delFunc()

    delFunc = ->
        db.view "#{params.type}/#{params.req_name}", body, (err, res) ->
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
    db.get "_design/#{params.type}", (err, res) ->

        if err && err.error is 'not_found'
            design_doc = {}
            design_doc[params.req_name] = body
            db.save "_design/#{params.type}", design_doc, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send error: true, msg: err.message, 500
                else
                    send success: true, 200

        else if err
            send error: true, msg: err.message, 500

        else
            views = res.views
            views[params.req_name] = body
            db.merge "_design/#{params.type}", {views:views}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send error: true, msg: err.message, 500
                else
                    send success: true, 200

# DELETE /request/:type/:req_name
action 'remove', ->
    db.get "_design/#{params.type}", (err, res) ->
        if err and err.error is 'not_found'
            send error: "not found", 404
        else if err
            send error: true, msg: err.message, 500
        else
            views = res.views
            delete views[params.req_name]
            db.merge "_design/#{params.type}", {views:views}, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send error: true, msg: err.message, 500
                else
                    send success: true, 204
