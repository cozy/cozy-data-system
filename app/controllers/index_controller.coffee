load 'application'

Client = require("request-json").JsonClient

if process.env.NODE_ENV is "test"
    client = new Client "http://localhost:9092/"
else
    client = new Client "http://localhost:9102/"

db = require('./helpers/db_connect_helper').db_connect()
checkToken = require('./lib/token').checkToken


before 'requireToken', ->
    checkToken req.header('authorization'), app.tokens, (err) =>
        next()

before 'lock request', ->
    @lock = "#{params.id}"
    app.locker.runIfUnlock @lock, =>
        app.locker.addLock(@lock)
        next()
, only: ['index', 'remove']

after 'unlock request', ->
    app.locker.removeLock @lock
, only: ['index', 'remove']

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
        if doc? then indexDoc(doc) else send 404
            

# POST /data/search/
# Returnds documents matching given text query
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
        if doc? then removeIndex(doc) else send 404


# DELETE /data/index/clear-all/
# Remove all index from data system
action 'removeAll', ->
    client.del "clear-all/", (err, res, resbody) ->
        if err
            send 500
        else
            send resbody, res.statusCode
