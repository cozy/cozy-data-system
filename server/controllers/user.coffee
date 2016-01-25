db = require('../helpers/db_connect_helper').db_connect()
logger = require('printit')(prefix: 'controllers/user')
errors = require '../middlewares/errors'

# POST /user/
module.exports.create = (req, res, next) ->
    delete req.body?._attachments
    if req.params.id
        db.get req.params.id, (err, doc) -> # this GET needed because of cache
            if doc
                next errors.http 409, "The document exists"
            else
                db.save req.params.id, req.body, (err, response) ->
                    if err
                        next errors.http 409, "The document exists"
                    else
                        res.status(201).send _id: response.id
    else
        db.save req.body, (err, response) ->
            if err
                logger.error err
                next err
            else
                res.status(201).send _id: response.id

# PUT /user/merge/:id
module.exports.merge = (req, res, next) ->
    # this version don't take care of conflict (erase DB with the sent value)
    delete req.body?._attachments
    db.merge req.params.id, req.body, (err, response) ->
        if err
            logger.error err
            next err
        else
            res.status(200).send success: true
            next()
