Client = require("request-json").JsonClient

if process.env.NODE_ENV is "test"
    client = new Client "http://localhost:9092/"
else
    client = new Client "http://localhost:9102/"

db = require('../helpers/db_connect_helper').db_connect()
checkDocType = require('../lib/token').checkDocType
feed = require '../helpers/db_feed_helper'
locker = require '../lib/locker'

## Before and after methods

# Check if application is authorized to manipulate docType given in params.type
module.exports.permissionType = (req, res, next) ->
    auth = req.header 'authorization'
    checkDocType auth, req.params.type, (err, appName, isAuthorized) =>
        if not appName
            err = new Error "Application is not authenticated"
            res.send 401, error: err
        else if not isAuthorized
            err = new Error "Application is not authorized"
            res.send 403, error: err
        else
            feed.publish 'usage.application', appName
            next()

# Check if application is authorized to manipulate all docTypes
module.exports.permissionAll = (req, res, next) ->
    auth = req.header 'authorization'
    checkDocType auth, "all", (err, appName, isAuthorized) =>
        if not appName
            err = new Error "Application is not authenticated"
            send 401, error: err
        else if not isAuthorized
            err = new Error "Application is not authorized"
            send 403, error: err
        else
            feed.publish 'usage.application', appName
            next()

## Helpers

# Check if application is authorized to manipulate docType given in params.type
permission = (req, docType, callback) ->
    auth = req.header 'authorization'
    checkDocType auth, docType, (err, appName, isAuthorized) =>
        feed.publish 'usage.application', appName
        callback()

## Actions

# POST /data/index/:id
# Index given fields of document matching id.
module.exports.index = (req, res, next) ->
    indexDoc = (doc) =>
        doc["id"] = doc._id
        data =
            doc: doc
            fields: req.body.fields
        client.post "index/", data, (err, response, body) ->
            next()
            if err or res.statusCode isnt 200
                res.send 500, error: JSON.stringify err
            else
                res.send 200, success: true
        , false # body = indexation succeeds, do not parse

    db.get req.params.id, (err, doc) ->
        if doc?
            permission req, doc.docType, ->
                indexDoc doc
        else
            next()
            res.send 404, error: "not found"


# POST /data/search/
# Returns documents matching given text query
module.exports.search = (req, res) ->
    data =
        docType: req.params.type
        query: req.body.query

    client.post "search/", data, (err, response, body) ->
        if err
            res.send 500, error: err.message
        else if not response?
            res.send 500, error: err.message
        else if response.statusCode isnt 200
            console.log response.statusCode, body
            res.send response.statusCode, body
        else
            db.get body.ids, (err, docs) ->
                if err
                    res.send 500, error: err.message
                else
                    results = []
                    for doc in docs
                        if doc.doc?
                            resDoc = doc.doc
                            resDoc.id = doc.id
                            results.push resDoc

                    res.send 200, rows: results


# DELETE /data/index/:id
# Remove index for given document
module.exports.remove = (req, res, next) ->
    removeIndex = ->
        client.del "index/#{params.id}/", (err, response, body) ->
            next()
            if err?
                res.send 500, error: err.message
            else
                res.send 200, success: true
        , false # body is not JSON

    db.get req.params.id, (err, doc) ->
        permission req, doc.docType, ->
            if doc?
                permission req, doc.docType, ->
                    removeIndex doc
            else
                next()
                res.send 404, err: "not found"


# DELETE /data/index/clear-all/
# Remove all index from data system
module.exports.removeAll = (req, res) ->
    client.del "clear-all/", (err, response, body) ->
        if err
            res.send 500, error: err.message
        else
            res.send 200, success: true
    , false  # body is not JSON
