db = require('../helpers/db_connect_helper').db_connect()
keys = require '../lib/encryption'

# POST /user/
module.exports.create = (req, res, next) ->
    delete req.body?._attachments
    if req.params.id
        db.get req.params.id, (err, doc) -> # this GET needed because of cache
            if doc
                err = new Error "The document exists"
                err.status = 409
                next err
            else
                db.save req.params.id, req.body, (err, response) ->
                    if err
                        err = new Error "The document exists"
                        err.status = 409
                        next err
                    else
                        res.send 201, _id: response.id
    else
        db.save req.body, (err, response) ->
            if err
                console.log "[Create] err: " + JSON.stringify err
                console.log err.error
                next new Error err.error
            else
                res.send 201, _id: response.id

# PUT /user/merge/:id
module.exports.merge = (req, res, next) ->
    # this version don't take care of conflict (erase DB with the sent value)
    delete req.body?._attachments
    db.merge req.params.id, req.body, (err, response) ->
        if err
            # oops unexpected error !
            console.log "[Merge] err: " + JSON.stringify err
            next new Error err.error
        else
            res.send 200, success: true
            next()
