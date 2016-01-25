addAccess = require('../lib/token').addAccess
updateAccess = require('../lib/token').updateAccess
removeAccess = require('../lib/token').removeAccess

## Actions


# POST /access/
module.exports.create = (req, res, next) ->
    access = req.body
    access.id = access.app
    addAccess access, (err, access) ->
        if err
            next err
        else
            res.status(201).send access

# PUT /access/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.update = (req, res, next) ->
    access = req.body
    updateAccess req.params.id, access, (err, access) ->
        if err
            next err
        else
            res.status(200).send success: true

# DELETE /access/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.remove = (req, res, next) ->
    removeAccess req.doc, (err) ->
        if err
            next err
        else
            res.status(204).send success: true
