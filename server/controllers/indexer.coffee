feed = require '../lib/feed'
indexer = require '../lib/indexer'

db = require('../helpers/db_connect_helper').db_connect()

## Actions

# POST /data/index/:id
# Index given fields of document matching id.
module.exports.index = (req, res, next) ->
    console.log 'app used deprecated POST /data/index/:id'
    setTimeout ->
        indexer.waitIndexing req.params.id, (err) ->
            res.send 200, success: true
    , 300

# POST /data/index/define/:type
# Register parameters on how to index Index given fields of document matching id.
module.exports.defineIndex = (req, res, next) ->
    docType = req.params.type.toLowerCase()
    indexer.registerIndexDefinition docType, req.body, (err) ->
        return next err if err
        res.send 200, success: true

module.exports.indexingStatus = (req, res, next) ->
    indexer.status (err, status) ->
        return next err if err
        res.send 200, status

# POST /data/search/
# POST /data/search/:type
# Returns documents matching given text query
module.exports.search = (req, res, next) ->

    if req.params.type
        docTypes = [req.params.type]
    else
        docTypes = req.body.doctypes or []

    indexer.search docTypes, req.body, (err, results) ->
        return next err if err

        ids = results.hits.map (hit) -> hit.id

        db.get ids, (err, rows) ->
            return next err if err

            results.rows = (row.doc for row in rows)
            res.send results

# Remove index for given document
module.exports.remove = (req, res, next) ->
    console.log 'app used deprecated DELETE /data/index/:id'
    setTimeout (-> res.send 200, success: true), 100


# DELETE /data/index/clear-all/
# Remove all index from data system
module.exports.removeAll = (req, res, next) ->
    indexer.cleanup (err) ->
        return next err if err
        res.send 200, success: true
