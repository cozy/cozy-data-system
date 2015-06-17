db = require('../helpers/db_connect_helper').db_connect()
async = require 'async'
request = {}
log = require('printit')
    date: true
    prefix: 'lib/request'

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
## Store new view with name <app>-request name in case of conflict
## Callback view name (req.req_name or name-req.req_name)
module.exports.create = (app, req, views, newView, callback) =>
    storeRam = (path) =>
        request[app] ?= {}
        request[app]["#{req.type}/#{req.req_name}"] = path
        callback null, path

    if productionOrTest
        # If classic view already exists and view is different :
        # store in app-req.req_name
        if views?[req.req_name]? and
                JSON.stringify(views[req.req_name]) isnt JSON.stringify(newView)
            storeRam "#{app}-#{req.req_name}"
        else
            # Else store view in classic path (req.req_name)
            if views?["#{app}-#{req.req_name}"]?
                # If views app-req.req_name exists, remove it.
                delete views["#{app}-#{req.req_name}"]
                db.merge "_design/#{req.type}", views: views, \
                (err, response) ->
                    if err
                        log.error "[Definition] err: " + err.message
                    storeRam req.req_name
            else
                storeRam req.req_name
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
            callback null, []
        else
            res.forEach (app) =>
                apps.push app.name
            callback null, apps

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
        callback null, docs

## function recoverDocs (callback)
## @callback {function} Continuation to pass control back to when complete.
## Callback all design documents from database
recoverDesignDocs = (callback) =>
    filterRange =
        startkey: "_design/"
        endkey: "_design0"
    db.all filterRange, (err, res) =>
        return callback err if err?
        recoverDocs res, [], callback


# Data system uses some views, this function initialize it.
initializeDSView = (callback) ->
    views =
        # Usefull for function 'doctypes' (controller/request. Databrowser)
        doctypes:
            all:
                map: """
                function(doc) {
                    if(doc.docType) {
                        return emit(doc.docType, null);
                    }
                }
                """
                # use to make a "distinct"
                reduce: """
                function(key, values) {
                    return true;
                }
                """
        # Usefull to manage device access
        device:
            all:
                map: """
                function(doc) {
                    if(doc.docType && doc.docType.toLowerCase() === "device") {
                        return emit(doc._id, doc);
                    }
                }
                """
            byLogin:
                map: """
                function (doc) {
                    if(doc.docType && doc.docType.toLowerCase() === "device") {
                        return emit(doc.login, doc)
                    }
                }
                """
        # Usefull to manage device access
        application:
            all:
                map: """
                function(doc) {
                    if(doc.docType && doc.docType.toLowerCase() === "application") {
                        return emit(doc._id, doc);
                    }
                }
                """
        # Usefull to remove binary lost
        binary:
            all:
                map: """
                function(doc) {
                    if(doc.docType && doc.docType.toLowerCase() === "binary") {
                        emit(doc._id, null);
                    }
                }
                """
            byDoc:
                map: """
                function(doc) {
                    if(doc.binary) {
                        for (bin in doc.binary) {
                            emit(doc.binary[bin].id, doc._id);
                        }
                    }
                }
                """
        # Usefull for thumbs creation
        file:
            withoutThumb:
                map: """
                function(doc) {
                    if(doc.docType && doc.docType.toLowerCase() === "file") {
                        if(doc.class === "image" && doc.binary && doc.binary.file && !doc.binary.thumb) {
                            emit(doc._id, null);
                        }
                    }
                }
                """
        # Usefull for API tags
        tags:
            all:
                map: """
                function (doc) {
                var _ref;
                return (_ref = doc.tags) != null ? typeof _ref.forEach === "function" ? _ref.forEach(function(tag) {
                   return emit(tag, null);
                    }) : void 0 : void 0;
                }
                """
                # use to make a "distinct"
                reduce: """
                function(key, values) {
                    return true;
                }
                """
    async.forEach Object.keys(views), (docType, cb) ->
        view = views[docType]
        db.get "_design/#{docType}", (err, doc) ->
            if err and err.error is 'not_found'
                db.save "_design/#{docType}", view, cb
            else if err
                log.error err
                cb()
            else
                for type in Object.keys(view)
                    doc.views[type] = view[type]
                db.save "_design/#{docType}", doc, cb
    , callback


## function init (callback)
## @callback {function} Continuation to pass control back to when complete.
## Initialize request
module.exports.init = (callback) =>
    removeEmptyView = (doc, callback) ->
        if Object.keys(doc.views).length is 0 or not doc?.views?
            db.remove doc._id, doc._rev, (err, response) ->
                if err
                    log.error "[Definition] err: " + err.message
                callback err
        else
            callback()

    storeAppView = (apps, doc, view, body, callback) ->
        # Search if view start with application name
        # Views as <name>-
        if view.indexOf('-') isnt -1
            # Link view and app in RAM
            #   -> Linked to an application
            if view.split('-')[0] in apps
                app = view.split('-')[0]
                type = doc._id.substr 8, doc._id.length-1
                req_name = view.split('-')[1]
                request[app] = {} if not request[app]
                request[app]["#{type}/#{req_name}"] = view
                callback()
            else
                # Remove view
                #   -> linked to an undefined application
                delete doc.views[view]
                db.merge doc._id, views: doc.views, \
                (err, response) ->
                    if err
                        log.error "[Definition] err: " +
                            err.message
                    removeEmptyView doc, (err) ->
                        log.error err if err?
                        callback()
        else
            callback()

    # Initialize view used by data-system
    initializeDSView ->
        if productionOrTest
            # Recover all applications in database
            recoverApp (err, apps) =>
                return callback err if err?
                # Recover all design docs in database
                recoverDesignDocs (err, docs) =>
                    return callback err if err?
                    async.forEach docs, (doc, cb) ->
                        #console.log doc
                        async.forEach Object.keys(doc.views), (view, cb) ->
                            body = doc.views[view]
                            storeAppView apps, doc, view, body, cb
                        , (err) ->
                            removeEmptyView doc, (err) ->
                                log.error err if err?
                                cb()
                    , (err) ->
                        log.error err if err?
                        callback()
        else
            callback null
