git = require 'git-rev'

db = require('../helpers/db_connect_helper').db_connect()
feed = require '../lib/feed'
encryption = require '../lib/encryption'
client = require '../lib/indexer'

updatePermissions = require('../lib/token').updatePermissions

## Before and after methods

## Encrypt data in field password
module.exports.encryptPassword = (req, res, next) ->
    doctype = req.body.docType
    if not doctype? or doctype.toLowerCase() isnt "application"
        try
            password = encryption.encrypt req.body.password
        catch error
            next error

        req.body.password = password if password?
        next()
    else
        next()

## Encrypt data in field password
# TODO: merge with encryptPassword
module.exports.encryptPassword2 = (req, res, next) ->
    doctypeBody = req.body.docType
    doctypeDoc = req.doc.docType
    if not doctypeBody? or doctypeBody.toLowerCase() isnt "application"
        if not doctypeDoc? or doctypeDoc.toLowerCase() isnt "application"
            try
                password = encryption.encrypt req.body.password
            catch error
                next error

            req.body.password = password if password?
            next()
        else
            next()
    else
        next()

# Decrypt data in field password
module.exports.decryptPassword = (req, res, next) ->
    doctype = req.doc.docType
    if not doctype? or doctype.toLowerCase() isnt "application"
        try
            password = encryption.decrypt req.doc.password
        catch error
            next error

        req.doc.password = password if password?
        next()
    else
        next()


## Actions

# Welcome page
module.exports.index = (req, res) ->

    git.long (commit) ->
        git.branch (branch) ->
            git.tag (tag) ->
                res.send 200, """
                <strong>Cozy Data System</strong><br />
                revision: #{commit}  <br />
                tag: #{tag} <br />
                branch: #{branch} <br />
                """

# GET /data/exist/:id/
module.exports.exist = (req, res, next) ->
    db.head req.params.id, (err, response, status) ->
        if status is 200
            res.send 200, exist: true
        else if status is 404
            res.send 200, exist: false
        else
            next new Error err

# GET /data/:id/
module.exports.find = (req, res) ->
    delete req.doc._rev # CouchDB specific, user don't need it
    res.send 200, req.doc

# POST /data/:id/
# POST /data/
module.exports.create = (req, res, next) ->
    delete req.body._attachments # attachments management has a dedicated API

    doctype = req.body.docType
    if doctype? and doctype.toLowerCase() is "application"
        updatePermissions req.body

    if req.params.id?
        db.get req.params.id, (err, doc) -> # this GET needed because of cache
            if doc?
                err = new Error "The document already exists."
                err.status = 409
                next err
            else
                db.save req.params.id, req.body, (err, doc) ->
                    if err?
                        err = new Error "The document already exists."
                        err.status = 409
                        next err
                    else
                        res.send 201, _id: doc.id
    else
        db.save req.body, (err, doc) ->
            if err?
                next new Error err.error
            else
                res.send 201, _id: doc.id

# PUT /data/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.update = (req, res, next) ->
    delete req.body._attachments # attachments management has a dedicated API

    doctype = req.body.docType
    if doctype? and doctype.toLowerCase() is "application"
        updatePermissions req.body

    db.save req.params.id, req.body, (err, response) ->
        if err? then next new Error err.error
        else
            res.send 200, success: true
            next()

# PUT /data/upsert/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.upsert = (req, res, next) ->
    delete req.body._attachments # attachments management has a dedicated API

    db.get req.params.id, (err, doc) ->
        db.save req.params.id, req.body, (err, savedDoc) ->
            if err?
                next new Error err.error
            else if doc?
                res.send 200, success: true
                next()
            else
                res.send 201, _id: savedDoc.id
                next()

# DELETE /data/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.delete = (req, res, next) ->
    id = req.params.id
    send_success = () ->
        feed.feed.removeListener "deletion.#{id}", send_success
        res.send 204, success: true
        next()
    db.remove id, req.doc.rev, (err, res) ->
        if err?
            next new Error err.error
        else
            # Doc is removed from indexation
            client.del "index/#{id}/", (err, response, resbody) ->
                feed.feed.on "deletion.#{id}", send_success

# PUT /data/merge/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.merge = (req, res, next) ->
    delete req.body._attachments # attachments management has a dedicated API

    db.merge req.params.id, req.body, (err, doc) ->
        if err?
            next new Error err.error
        else
            res.send 200, success: true
            next()
