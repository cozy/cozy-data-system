git = require 'git-rev'

db = require('../helpers/db_connect_helper').db_connect()
feed = require '../lib/feed'
dbHelper = require '../lib/db_remove_helper'
encryption = require '../lib/encryption'
client = require '../lib/indexer'

addAccess = require('../lib/token').addApplicationAccess
removeAccess = require('../lib/token').removeAccess

## Before and after methods

## Encrypt data in field password
module.exports.encryptPassword = (req, res, next) ->
    doctype = req.body.docType
    if not doctype? or doctype.toLowerCase() isnt "application"
        try
            password = encryption.encrypt req.body.password
        catch error
            # do nothing to prevent error in apps
            # todo add a way to send a warning in the http response

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
                # do nothing to prevent error in apps
                # todo add a way to send a warning in the http response

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
            # do nothing to prevent error in apps
            # todo add a way to send a warning in the http response

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
            next err

# GET /data/:id/
module.exports.find = (req, res) ->
    delete req.doc._rev # CouchDB specific, user don't need it
    res.send 200, req.doc

# POST /data/:id/
# POST /data/
module.exports.create = (req, res, next) ->
    checkApp = (cb) ->
        doctype = req.body.docType
        if doctype? and doctype.toLowerCase() is "application"
            console.log "addApplicationAccess"
            addAccess req.body, (err, appli) ->
                req.body = appli
                cb()
        else
            cb()

    delete req.body._attachments # attachments management has a dedicated API
    checkApp () ->
        if req.params.id?
            db.get req.params.id, (err, doc) -> # this GET needed because of cache
                if doc?
                    err = new Error "The document already exists."
                    err.status = 409
                    next err
                else
                    db.save req.params.id, req.body, (err, doc) ->
                        if err
                            err = new Error "The document already exists."
                            err.status = 409
                            next err
                        else
                            res.send 201, _id: doc.id
        else
            db.save req.body, (err, doc) ->
                if err
                    next err
                else
                    res.send 201, _id: doc.id

# PUT /data/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.update = (req, res, next) ->
    checkApp = (cb) ->
        doctype = req.body.docType
        if doctype? and doctype.toLowerCase() is "application"
            addAccess req.body, (err, appli) ->
                req.body = appli
                cb()
        else
            cb()
    delete req.body._attachments # attachments management has a dedicated API

    checkApp () ->
        db.save req.params.id, req.body, (err, response) ->
            if err then next err
            else
                res.send 200, success: true
                next()

# PUT /data/upsert/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.upsert = (req, res, next) ->
    delete req.body._attachments # attachments management has a dedicated API

    db.get req.params.id, (err, doc) ->
        db.save req.params.id, req.body, (err, savedDoc) ->
            if err
                next err
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
        res.send 204, success: true
        next()

    doctype = req.doc.docType
    if doctype? and doctype.toLowerCase() is "application"
       removeAccess req.doc

    dbHelper.remove req.doc, (err, res) ->
        if err
            next err
        else
            # Doc is removed from indexation
            client.del "index/#{id}/", (err, response, resbody) ->
                send_success()

# PUT /data/merge/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.merge = (req, res, next) ->
    delete req.body._attachments # attachments management has a dedicated API

    checkApp = (cb) ->
        doctype = req.body.docType
        if doctype?
            if doctype.toLowerCase() is "application"
                delete req.body.password
            cb()
        else
            db.get req.params.id, (err, doc) ->
                doctype = doc.docType
                if doctype? and doctype.toLowerCase() is "application"
                    delete req.body.password
                cb()

    checkApp () ->
        db.merge req.params.id, req.body, (err, doc) ->
            if err
                next err
            else
                res.send 200, success: true
                next()
