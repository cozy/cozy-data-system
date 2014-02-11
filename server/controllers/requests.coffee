async = require "async"

db = require('../helpers/db_connect_helper').db_connect()
feed = require '../helpers/db_feed_helper'
locker = require '../lib/locker'
request = require '../lib/request'
encryption = require '../lib/encryption'
checkDocType = require('../lib/token').checkDocType

# Before and after methods

# Check if application is authorized to manipulate docType given in params.type

module.exports.permissions = (req, res, next) ->
    auth = req.header 'authorization'
    checkDocType auth, req.params.type, (err, appName, isAuthorized) =>
        if not appName
            err = new Error "Application is not authenticated"
            res.send 401, error: err
        else if not isAuthorized
            err = new Error "Application is not authorized"
            res.send 403, error: err
        else
            req.appName = appName
            feed.publish 'usage.application', appName
            next()

## Actions

# GET /doctypes
# list all doctypes that have been created
# a doctype is a design document with a "all" request
module.exports.doctypes = (req, res) ->

    query = group: true
    out = []

    db.view "doctypes/all", query, (err, docs) ->
        if err?
            res.send 500, err: JSON.stringify err
        else
            docs.forEach (key, row, id) -> out.push key
            res.send 200, out

# GET /tags
# list all tags
# tags are item of a tags:[] field
module.exports.tags = (req, res) ->

    query = group: true
    out = []

    db.view "tags/all", query, (err, docs) ->
        if err?
            send 500, error: JSON.stringify err
        else
            docs.forEach (key, row, id) -> out.push key
            res.send 200, out

# POST /request/:type/:req_name/
module.exports.results = (req, res) ->
    request.get req.appName, req.params, (path) =>
        db.view "#{req.params.type}/" + path, req.body, (err, docs) ->
            if err?
                if err.error is "not_found"
                    res.send 404, error: "not found"
                else
                    console.log "[Results] err: " + JSON.stringify err
                    res.send 500, error: err.message
            else
                docs.forEach (value) ->
                    delete value._rev # CouchDB specific, user don't need it
                    if value.password? and not (
                        (value.docType? and
                        (value.docType.toLowerCase() is "application" or
                            value.docType.toLowerCase() is "user")
                        ))
                        encryption.decrypt value.password, (err, password) ->
                            value.password = password if not err?

                res.send docs

# PUT /request/:type/:req_name/destroy/
module.exports.removeResults = (req, res) ->
    removeFunc = (doc, callback) ->
        db.remove doc.value._id, doc.value._rev, callback

    removeAllDocs = (docs) ->
        async.forEachSeries docs, removeFunc, (err) ->
            if err?
                res.send 500, error: err.message
            else
                delFunc()

    delFunc = =>
        # db.view seems to alter the options object
        # cloning the object before each query prevents that
        query = JSON.parse JSON.stringify req.body
        request.get req.appName, req.params, (path) =>
            path = "#{req.params.type}/" + path
            db.view path, query, (err, docs) ->
                if err?
                    res.send 404, error: "not found"
                else
                    if docs.length > 0
                        removeAllDocs docs
                    else
                        res.send 204, success: true
    delFunc()

# PUT /request/:type/:req_name/
module.exports.definition = (req, res, next) ->
    # no need to precise language because it's javascript
    db.get "_design/#{req.params.type}", (err, docs) =>
        if err? && err.error is 'not_found'
            design_doc = {}
            design_doc[req.params.req_name] = req.body
            db.save "_design/#{req.params.type}", design_doc, (err, response) ->
                next()
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    res.send 500, error: err.message
                else
                    res.send 200, success: true

        else if err?
            next()
            res.send 500, error: err.message

        else
            views = docs.views
            request.create req.appName, req.params, views, req.body, (err, path) =>
                views[path] = req.body
                db.merge "_design/#{req.params.type}", views: views, (err, response) ->
                    next()
                    if err?
                        console.log "[Definition] err: " + JSON.stringify err
                        res.send 500, error: err.message
                    else
                        res.send 200, success: true

# DELETE /request/:type/:req_name
module.exports.remove = (req, res, next) ->
    db.get "_design/#{req.params.type}", (err, docs) =>
        if err? and err.error is 'not_found'
            next()
            res.send 404, error: "not found"
        else if err?
            next()
            res.send 500, error: err.message
        else
            views = docs.views
            request.get req.appName, req.params, (path) =>
                if path is "#{req.params.req_name}"
                    next()
                    res.send 204, success: true
                else
                    delete views["#{path}"]
                    db.merge "_design/#{req.params.type}", views: views, (err, response) ->
                        next()
                        if err?
                            console.log "[Definition] err: " + JSON.stringify err
                            res.send 500, error: err.message
                        else
                            res.send 204, success: true
