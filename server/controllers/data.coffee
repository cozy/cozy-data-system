git = require 'git-rev'
Client = require("request-json").JsonClient

db = require('../helpers/db_connect_helper').db_connect()
feed = require '../helpers/db_feed_helper'
locker = require '../lib/locker'
encryption = require '../lib/encryption'

checkDocType = require('../lib/token').checkDocType
updatePermissions = require('../lib/token').updatePermissions

if process.env.NODE_ENV is "test"
    client = new Client "http://localhost:9092/"
else
    client = new Client "http://localhost:9102/"


## Before and after methods

# Recover document from database with id equal to params.id
module.exports.getDoc = (req, res, next) ->
    db.get req.params.id, (err, doc) =>
        if err? and err.error is "not_found"
            locker.removeLock req.lock
            res.send 404, error: "not found"
        else if err?
            console.log "[Get doc] err: " + JSON.stringify err
            locker.removeLock req.lock
            res.send 500, error: err
        else if doc?
            req.doc = doc
            next()
        else
            locker.removeLock req.lock
            res.send 404, error: "not found"

# Check if application is authorized to manage docType of document
# docType corresponds to docType given in parameters
module.exports.permissions_param = (req, res, next) ->
    auth = req.header 'authorization'
    checkDocType auth, req.body.docType, (err, appName, isAuthorized) =>
        if not appName
            err = new Error "Application is not authenticated"
            res.send 401, error: err.message
        else if not isAuthorized
            err = new Error "Application is not authorized"
            res.send 403, error: err.message
        else
            feed.publish 'usage.application', appName
            next()

# Check if application is authorized to manage docType of document
# docType corresponds to docType of recovered document from database
# Required to be processed after "get doc"
# TODO: merge with permissions_param
module.exports.permissions = (req, res, next) ->
    ###
    doctypeName = req.doc?.docType or req.body?.docType or null
    if req.doc?.docType? and req.body?.docType? \
       and req.doc.docType is req.body.docType
       res.send 500, "A document's doctype cannot change"
    else
    ###

    auth = req.header 'authorization'
    checkDocType auth, req.doc.docType, (err, appName, isAuthorized) =>
        if not appName
            err = new Error "Application is not authenticated"
            res.send 401, error: err.message
        else if not isAuthorized
            err = new Error "Application is not authorized"
            res.send 403, error: err.message
        else
            feed.publish 'usage.application', appName
            next()

## Encrypt data in field password
module.exports.encryptPassword = (req, res, next) ->
    doctype = req.body.docType
    if not doctype? or doctype.toLowerCase() isnt "application"
        encryption.encrypt req.body.password, (err, password) ->
            if err?
                res.send 500, error: err
            else if password?
                req.body.password = password
                next()
            else
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
            encryption.encrypt req.body.password, (err, password) ->
                if err?
                    send 500, error: err
                else if password?
                    req.body.password = password
                    next()
                else
                    next()
        else
            next()
    else
        next()

# Decrypt data in field password
module.exports.decryptPassword = (req, res, next) ->
    doctype = req.doc.docType
    if not doctype? or doctype.toLowerCase() isnt "application"
        encryption.decrypt req.doc.password, (err, password) =>
            if err?
                res.send 500, error: err
            else if password?
                req.doc.password = password
                next()
            else
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
module.exports.exist = (req, res) ->
    db.head req.params.id, (err, response, status) ->
        if status is 200
            res.send 200, exist: true
        else if status is 404
            res.send 200, exist: false
        else
            res.send 500, error: JSON.stringify err

# GET /data/:id/
module.exports.find = (req, res) ->
    delete req.doc._rev # CouchDB specific, user don't need it
    res.send 200, req.doc

# POST /data/:id/
# POST /data/
module.exports.create = (req, res) ->
    delete req.body._attachments # attachments management has a dedicated API

    doctype = req.body.docType
    if doctype? and doctype.toLowerCase() is "application"
        updatePermissions req.body

    if req.params.id?
        db.get req.params.id, (err, doc) -> # this GET needed because of cache
            if doc?
                res.send 409, error: "The document already exists"
            else
                db.save req.params.id, req.body, (err, doc) ->
                    if err?
                        res.send 409, error: err.message
                    else
                        res.send 201, "_id": doc.id
    else
        db.save req.body, (err, doc) ->
            if err?
                res.send 500, error: err.message
            else
                res.send 201, "_id": doc.id

# PUT /data/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.update = (req, res, next) ->
    delete req.body._attachments # attachments management has a dedicated API

    doctype = req.body.docType
    if doctype? and doctype.toLowerCase() is "application"
        updatePermissions req.body

    db.save req.params.id, req.body, (err, response) ->
        next()
        if err? then res.send 500, error: err.message
        else res.send 200, success: true

# PUT /data/upsert/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.upsert = (req, res, next) ->
    delete req.body._attachments # attachments management has a dedicated API

    db.get req.params.id, (err, doc) ->
        db.save req.params.id, req.body, (err, savedDoc) ->
            next()
            if err?
                res.send 500, error: err.message
            else if doc?
                res.send 200, success: true
            else
                res.send 201, "_id": savedDoc.id

# DELETE /data/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.delete = (req, res, next) ->
    id = req.params.id
    send_success = () ->
        next()
        feed.feed.removeListener "deletion.#{id}", send_success
        res.send 204, success: true
    db.remove id, req.doc.rev, (err, res) =>
        if err?
            next()
            res.send 500, error: err.message
        else
            # Doc is removed from indexation
            client.del "index/#{id}/", (err, response, resbody) =>
                feed.feed.on "deletion.#{id}", send_success

# PUT /data/merge/:id/
# this doesn't take care of conflict (erase DB with the sent value)
module.exports.merge = (req, res, next) ->
    delete req.body._attachments # attachments management has a dedicated API

    db.merge req.params.id, req.body, (err, doc) ->
        next()
        if err?
            res.send 500, error: err.message
        else
            res.send 200, success: true
