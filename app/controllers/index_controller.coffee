load 'application'

Client = require("request-json").JsonClient

if process.env.NODE_ENV is "test"
    client = new Client "http://localhost:9092/"
else
    client = new Client "http://localhost:9102/"

db = require('./helpers/db_connect_helper').db_connect()
checkDocType = require('./lib/token').checkDocType


## Before and after methods

# Check if application is authorized to manipulate docType given in params.type
before 'permission', ->
    auth = req.header('authorization')
    checkDocType auth, params.type, (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            compound.app.feed.publish 'usage.application', appName
            next()
, only: ['search']

# Check if application is authorized to manipulate all docTypes
before 'permission', ->
    auth = req.header('authorization')
    checkDocType auth, "all", (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            compound.app.feed.publish 'usage.application', appName
            next()
, only: ['removeAll']

# Lock document to avoid multiple modifications at the same time.
before 'lock request', ->
    @lock = "#{params.id}"
    app.locker.runIfUnlock @lock, =>
        app.locker.addLock(@lock)
        next()
, only: ['index', 'remove']

# Unlock document when action is finished
after 'unlock request', ->
    app.locker.removeLock @lock
, only: ['index', 'remove']


## Helpers

# Check if application is authorized to manipulate docType given in params.type
permission = (docType, callback) ->
    auth = req.header('authorization')
    checkDocType auth, docType, (err, appName, isAuthorized) =>
        compound.app.feed.publish 'usage.application', appName
        callback()


## Actions

# POST /data/index/:id
# Index given fields of document matching id.
action 'index', ->
    indexDoc = (doc) =>
        doc["id"] = doc._id
        data =
            doc: doc
            fields: body.fields
        client.post "index/", data, (err, res, resbody) ->
            if err or res.statusCode != 200
                send 500
            else
                send resbody, res.statusCode

    db.get params.id, (err, doc) ->
        if doc?
            permission doc.docType, () =>
                indexDoc(doc)
        else
            send 404


# POST /data/search/
# Returns documents matching given text query
action 'search', ->
    data =
        docType: params.type
        query: body.query

    client.post "search/", data, (err, res, resbody) ->
        if err
            send 500
        else if not res?
            send 500
        else if res.statusCode != 200
            send resbody, res.statusCode
        else
            db.get resbody.ids, (err, docs) ->
                if err
                    send 500
                else
                    results = []
                    for doc in docs
                        if doc.doc?
                            resDoc = doc.doc
                            resDoc.id = doc.id
                            results.push resDoc

                    send rows: results, 200


# DELETE /data/index/:id
# Remove index for given document
action 'remove', ->
    removeIndex = ->
        client.del "index/#{params.id}/", (err, res, resbody) ->
            if err
                send 500
            else
                send resbody, res.statusCode

    db.get params.id, (err, doc) ->
        permission doc.docType, () =>
            if doc?
                permission doc.docType, () =>
                    removeIndex(doc)
            else
                send 404


# DELETE /data/index/clear-all/
# Remove all index from data system
action 'removeAll', ->
    client.del "clear-all/", (err, res, resbody) ->
        if err
            send 500
        else
            send resbody, res.statusCode
