load 'application'

cradle = require "cradle"

connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database("cozy")

Client = require("request-json").JsonClient
client = new Client("http://localhost:5000/")

# POST /data/index/:id
# Index given fields of document matching id.
action 'index', ->
    indexDoc = (doc) =>
        
        console.log doc._id
        
        doc["id"] = doc._id
        console.log doc
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
        query: body

    client.post "search/", body, (err, res, resbody) ->
        if err
            send 500
        if res.statusCode != 200
            send resbody, res.statusCode
        else
            db.get resbody.ids, (err, docs) ->
                if err
                    send 500
                else
                    results = []
                    results.push doc.doc for doc in docs
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

