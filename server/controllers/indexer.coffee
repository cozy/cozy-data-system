feed = require '../lib/feed'
client = require '../lib/indexer'

db = require('../helpers/db_connect_helper').db_connect()

## Actions

# POST /data/index/:id
# Index given fields of document matching id.
module.exports.index = (req, res, next) ->
    req.doc.id = req.doc._id

    # if the app has sent mapped values, we replace the actual values
    # by the mapped ones
    if req.body.mappedValues?
        for field, mappedValue of req.body.mappedValues
            req.doc[field] = mappedValue
    data =
        doc: req.doc
        fields: req.body.fields
        fieldsType: req.body.fieldsType

    client.post "index/", data, (err, response, body) ->
        if err
            next err
        else if response.statusCode isnt 200
            err = new Error
            err.status = response.statusCode
            next err
        else
            res.send 200, success: true
            next()
    , false # body = indexation succeeds, do not parse

# POST /data/search/
# Returns documents matching given text query
module.exports.search = (req, res, next) ->

    doctypes = req.params.type or req.body.doctypes or []

    showNumResults = req.body.showNumResults
    data =
        docType: doctypes
        query: req.body.query
        numPage: req.body.numPage
        numByPage: req.body.numByPage
        showNumResults: showNumResults

    client.post "search/", data, (err, response, body) ->
        if err
            next err
        else if not response?
            next new Error "Response not found"
        else if response.statusCode isnt 200
            res.send response.statusCode, body
        else

            db.get body.ids, (err, docs) ->
                if err
                    next err
                else
                    results = []
                    for doc in docs
                        if doc.doc?
                            resDoc = doc.doc
                            resDoc.id = doc.id
                            results.push resDoc


                    resultObject = rows: results

                    # Preserves old format while supporting "show number
                    # of results" response
                    if showNumResults
                        resultObject.numResults = body.numResults

                    res.send 200, resultObject


# DELETE /data/index/:id
# Remove index for given document
module.exports.remove = (req, res, next) ->
    client.del "index/#{req.params.id}/", (err, response, body) ->
        if err
            next err
        else
            res.send 200, success: true
            next()
    , false # body is not JSON


# DELETE /data/index/clear-all/
# Remove all index from data system
module.exports.removeAll = (req, res, next) ->
    client.del "clear-all/", (err, response, body) ->
        if err
            next err
        else
            res.send 200, success: true
    , false  # body is not JSON
