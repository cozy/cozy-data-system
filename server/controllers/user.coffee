db = require('../helpers/db_connect_helper').db_connect()
keys = require '../lib/encryption'

# POST /user
module.exports.create = (req, res) ->
    delete body._attachments
    if req.params.id
        db.get req.params.id, (err, doc) -> # this GET needed because of cache
            if doc
                res.send 409, error: "The document exists"
            else
                db.save params.id, req.body, (err, response) ->
                    if err
                        res.send 409, error: err.message
                    else
                        res.send 201, _id: response.id
    else
        db.save req.body, (err, response) ->
            if err
                console.log "[Create] err: " + JSON.stringify err
                res.send 500, error: err.message
            else
                res.send 201, _id: response.id

# PUT /user/merge/:id
module.exports.merge = (req, res, next) ->
    # this version don't take care of conflict (erase DB with the sent value)
    delete body._attachments
    db.merge req.params.id, req.body, (err, response) ->
        next()
        if err
            # oops unexpected error !
            console.log "[Merge] err: " + JSON.stringify err
            res.send 500, error: err.message
        else
            res.send 200, success: true
