feed = require '../lib/feed'
client = require '../lib/indexer'

db = require('../helpers/db_connect_helper').db_connect()

## Actions

# POST /data/index/:id
# Index given fields of document matching id.
module.exports.index = (req, res, next) ->
    req.doc.id = req.doc._id
    data =
        doc: req.doc
        fields: req.body.fields
    client.post "index/", data, (err, response, body) ->
        if err or response.statusCode isnt 200
            next new Error err
        else
            res.send 200, success: true
            next()
    , false # body = indexation succeeds, do not parse

# POST /data/search/
# Returns documents matching given text query
module.exports.search = (req, res, next) ->
    data =
        docType: req.params.type
        query: req.body.query

    client.post "search/", data, (err, response, body) ->
        if err
            next new Error err
        else if not response?
            next new Error "Response not found"
        else if response.statusCode isnt 200
            res.send response.statusCode, body
        else
            db.get body.ids, (err, docs) ->
                if err
                    next new Error err.error
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
    client.del "index/#{req.params.id}/", (err, response, body) ->
        if err?
            next new Error err
        else
            res.send 200, success: true
            next()
    , false # body is not JSON


# DELETE /data/index/clear-all/
# Remove all index from data system
module.exports.removeAll = (req, res, next) ->
    client.del "clear-all/", (err, response, body) ->
        if err
            next new Error err
        else
            res.send 200, success: true
    , false  # body is not JSON
