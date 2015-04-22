git = require 'git-rev'

db = require('../helpers/db_connect_helper').db_connect()
feed = require '../lib/feed'
dbHelper = require '../lib/db_remove_helper'
errors = require '../middlewares/errors'
encryption = require '../lib/encryption'
client = require '../lib/indexer'

addAccess = require('../lib/token').addAccess
updateAccess = require('../lib/token').updateAccess
removeAccess = require('../lib/token').removeAccess

## Actions


# POST /access/
module.exports.create = (req, res, next) ->
    access = req.body
    access.id = access.app
    addAccess access, (err, access) ->
        callback next err if err
        res.send 201, access

# PUT /access/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.update = (req, res, next) ->
    access = req.body
    updateAccess req.params.id, access, (err, access) ->
        if err
            next err
        else
            res.send 200, success: true

# DELETE /access/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.remove = (req, res, next) ->
    removeAccess req.doc, () ->
        res.send 204, success: true
