async = require "async"

db = require('../helpers/db_connect_helper').db_connect()
request = require '../lib/request'
encryption = require '../lib/encryption'
dbHelper = require '../lib/db_remove_helper'
errors = require '../middlewares/errors'
util = require 'util'

log = require('printit')
    prefix: 'requests'

## Actions

# GET /doctypes
# list all doctypes that have been created
# a doctype is a design document with a "all" request
module.exports.doctypes = (req, res, next) ->

    query = group: true
    out = []

    db.view "doctypes/all", query, (err, docs) ->
        if err
            next err
        else
            docs.forEach (key, row, id) -> out.push key
            res.send 200, out

# GET /tags
# list all tags
# tags are item of a tags:[] field
module.exports.tags = (req, res, next) ->

    query = group: true
    out = []

    db.view "tags/all", query, (err, docs) ->
        if err
            next err
        else
            docs.forEach (key, row, id) -> out.push key
            res.send 200, out

# POST /request/:type/:req_name/
module.exports.results = (req, res, next) ->
    sendRev = req.body.show_revs
    delete req.body.show_revs
    request.get req.appName, req.params, (path) ->
        db.view "#{req.params.type}/" + path, req.body, (err, docs) ->
            if err
                log.error err
                next err
            else if util.isArray(docs)
                docs.forEach (value) ->
                    unless sendRev
                        # Revisions are usefull for devices
                        delete value._rev # CouchDB specific, user don't need it

                    if value.password? and value.docType?.toLowerCase() not in [
                        'application', 'user'
                    ]
                        try
                            value.password = encryption.decrypt value.password
                        catch
                            # catch error
                            value._passwordStillEncrypted = true

                res.send docs
            else
                res.send docs

# PUT /request/:type/:req_name/destroy/
module.exports.removeResults = (req, res, next) ->

    options = JSON.parse JSON.stringify req.body
    options.limit = 100
    viewName = null

    delFunc = ->
        db.view viewName, options, (err, docs) ->
            if err
                if err.error is "not_found"
                    next errors.http 404, "Request #{viewName} was not found"
                else
                    log.error "Deletion by request failed for #{viewName}"
                    log.error err
                    # The fact that no docs with the proper key exsits raised
                    # an error. But that's what we are seeking for: removing
                    # all docs. That's why we ignore the error.
                    if options.startkey?
                        res.send 204, success: true
                    else
                        next err
            else
                if docs.length > 0
                    # Put a timeout to give some breath because each doc
                    # deletion raises an event.
                    dbHelper.removeAll docs, ->
                        setTimeout delFunc, 500
                else
                    res.send 204, success: true

    request.get req.appName, req.params, (path) ->
        viewName = "#{req.params.type}/#{path}"
        delFunc()


# PUT /request/:type/:req_name/
module.exports.definition = (req, res, next) ->
    # no need to precise language because it's javascript
    db.get "_design/#{req.params.type}", (err, docs) ->
        if err && err.error is 'not_found'
            design_doc = {}
            design_doc[req.params.req_name] = req.body
            db.save "_design/#{req.params.type}", design_doc, (err, response) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    next err
                else
                    res.send 200, success: true
                    next()

        else if err
            next err

        else
            views = docs.views
            request.create req.appName, req.params, views, req.body, \
            (err, path) ->
                views[path] = req.body
                db.merge "_design/#{req.params.type}", views: views, \
                (err, response) ->
                    if err
                        console.log "[Definition] err: " + JSON.stringify err
                        next err
                    else
                        res.send 200, success: true
                        next()

# DELETE /request/:type/:req_name
module.exports.remove = (req, res, next) ->
    db.get "_design/#{req.params.type}", (err, docs) ->
        if err and err.error is 'not_found'
            next errors.http 404, "Not Found"
        else if err
            next err
        else
            views = docs.views
            request.get req.appName, req.params, (path) ->
                if path is "#{req.params.req_name}"
                    res.send 204, success: true
                    next()
                else
                    delete views["#{path}"]
                    db.merge "_design/#{req.params.type}", views: views, \
                    (err, response) ->
                        if err
                            console.log "[Definition] err: " + err.message
                            next err
                        else
                            res.send 204, success: true
                            next()
