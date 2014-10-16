db = require('../helpers/db_connect_helper').db_connect()
request = {}

# Define random function for application's token
randomString = (length) ->
    string = ""
    while (string.length < length)
        string = string + Math.random().toString(36).substr(2)
    return string.substr 0, length

productionOrTest = process.env.NODE_ENV is "production" or
    process.env.NODE_ENV is "test"

## function create (app, req, views, newView, callback)
## @app {String} application name
## @req {Object} contains type and request name
## @views {Object} contains all existing view for this type
## @newView {Object} contains function map/reduce of new view
## @callback {function} Continuation to pass control back to when complete.
## Store new request name in case of conflict
## Callback new request name
module.exports.create = (app, req, views, newView, callback) =>
    storeRam = (path, callback) =>
        request[app] = {} if not request[app]
        request[app]["#{req.type}/#{req.req_name}"] = path
        callback null, path

    if productionOrTest
        # If classic view already exists and view is different :
        # store in app-req.req_name
        if views[req.req_name]? and
                JSON.stringify(views[req.req_name]) isnt JSON.stringify(newView)
            storeRam "#{app}-#{req.req_name}", callback
        else
            # Else store view in classic path (req.req_name)
            if views["#{app}-#{req.req_name}"]?
                # If views app-req.req_name exists, remove it.
                delete views["#{app}-#{req.req_name}"]
                db.merge "_design/#{req.type}", views: views, \
                (err, response) ->
                    if err?
                        console.log "[Definition] err: " + err.message
                    storeRam req.req_name, callback
            else
                storeRam req.req_name, callback
    else
        callback null, req.req_name


## function get (app, req, callback)
## @app {String} application name
## @req {Object} contains type and request name
## @callback {function} Continuation to pass control back to when complete.
## Callback correct request name
module.exports.get = (app, req, callback) =>
    if productionOrTest and request[app]?["#{req.type}/#{req.req_name}"]?
        callback request[app]["#{req.type}/#{req.req_name}"]
    else
        callback "#{req.req_name}"


## Helpers for init function ##

## function recoverApp (callback)
## @callback {function} Continuation to pass control back to when complete.
## Callback all application names from database
recoverApp = (callback) =>
    apps = []
    db.view 'application/all', (err, res) =>
        if err
            callback err
        else if not res
            callback []
        else
            res.forEach (app) =>
                apps.push app.name
            callback apps

## function recoverDocs (callback)
## @res {tab} design docs without views
## @docs {tab} design docs with view
## @callback {function} Continuation to pass control back to when complete.
## Callback all design documents from database
recoverDocs = (res, docs, callback) =>
    if res and res.length isnt 0
        doc = res.pop()
        db.get doc.id, (err, result) =>
            docs.push(result)
            recoverDocs res, docs, callback
    else
        callback docs

## function recoverDocs (callback)
## @callback {function} Continuation to pass control back to when complete.
## Callback all design documents from database
recoverDesignDocs = (callback) =>
    filterRange =
        startkey: "_design/"
        endkey: "_design0"
    db.all filterRange, (err, res) =>
        recoverDocs res, [], callback

## function init (callback)
## @callback {function} Continuation to pass control back to when complete.
## Initialize request
module.exports.init = (callback) =>
    if productionOrTest
        recoverApp (apps) =>
            recoverDesignDocs (docs) =>
                for app in apps
                    for doc in docs
                        for view, body of doc.views
                            # Search if view start with application name
                            if view.indexOf(app + '-') is 0
                                type = doc._id.substr 8, doc._id.length-1
                                req_name = view.split('-')[1]
                                request[app] = {} if not request[app]
                                request[app]["#{type}/#{req_name}"] = view
                callback null
    else
        callback null
