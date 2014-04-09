fs = require 'fs'
logger = require('printit')
    date: false
    prefix: 'lib:db'
S = require 'string'
Client = require("request-json").JsonClient


initTokens = require('../lib/token').init
request = require('../lib/request')

logger = require('printit')
    date: true
    prefix: 'lib/db'

module.exports = (callback) ->
    feed = require '../lib/feed'
    db = require('../helpers/db_connect_helper').db_connect()
    couchUrl = "http://#{db.connection.host}:#{db.connection.port}/"
    couchClient = new Client couchUrl

    ### Helpers ###

    initLoginCouch = ->
        data = fs.readFileSync '/etc/cozy/couchdb.login'
        lines = S(data.toString('utf8')).lines()
        return lines

    # Add admin to cozy database
    # Result : Unauthorized applications cannot read on cozy
    addCozyAdmin = (callback) ->
        loginCouch = initLoginCouch()
        data =
            "admins":
                "names":[loginCouch[0]]
                "roles":[]
            "readers":
                "names":[loginCouch[0], 'proxy']
                "roles":[]
        couchClient.setBasicAuth(loginCouch[0],loginCouch[1])
        couchClient.put "#{db.name}/_security", data, (err, res, body)->
            callback err

    addCozyUser = (callback) ->
        loginCouch = initLoginCouch()
        data =
            "_id": "org.couchdb.user:proxy",
            "name": "proxy",
            "type": "user",
            "roles": [],
            "password": process.env.TOKEN
        couchClient.setBasicAuth(loginCouch[0],loginCouch[1])
        couchClient.get  '_users/org.couchdb.user:proxy', (err, res, body) =>
            if body?
                couchClient.del  "_users/org.couchdb.user:proxy?rev=#{body._rev}", (err, res, body) =>
                    couchClient.post '_users', data, (err, res, body)->
                        callback err
            else
                couchClient.post '_users', data, (err, res, body)->
                    callback err


    ### Logger ###

    logFound = ->
        logger.info "Database #{db.name} on #{db.connection.host}" +
            ":#{db.connection.port} found."
        feed_start()
        request_create()

    logError = (err) ->
        logger.info "Error on database creation : "
        logger.info err

    logCreated = ->
        logger.info "Database #{db.name} on" +
            " #{db.connection.host}:#{db.connection.port} created."
        feed_start()
        request_create()


    ### Check existence of cozy database or create it ###
    db_ensure = (callback) ->
        db.exists (err, exists) ->
            if err
                couchUrl = "#{db.connection.host}:#{db.connection.port}"
                logger.error "Error: #{err} (#{couchUrl})"
            else if exists
                if process.env.NODE_ENV is 'production'
                    loginCouch = initLoginCouch()
                    addCozyUser (err) ->
                        if err
                            logger.error "Error on database" +
                            " Add user : #{err}"
                            callback()
                        else
                            addCozyAdmin (err) =>
                                if err
                                    logger.error "Error on database" +
                                    " Add admin : #{err}"
                                    callback()
                                else
                                    logFound()
                                    callback()
                else
                    logFound()
                    callback()
            else
                db_create(callback)

    db_create = (callback)->
        logger.info "Database #{db.name} on" +
                " #{db.connection.host}:#{db.connection.port} doesn't exist."
        db.create (err) ->
            if err
                logError(err)
                db_create(callback)
            else if (process.env.NODE_ENV is 'production')
                addCozyUser (err) ->
                    if err
                        logger.error "Error on database" +
                        " Add user : #{err}"
                        callback()
                    else
                        addCozyAdmin (err) =>
                            if err
                                logError(err)
                                callback()
                            else
                                logCreated()
                                callback()
            else
                logCreated()
                callback()

    # this request is used to retrieved all the doctypes in the DS
    request_create = ->
        db.get '_design/doctypes', (err, doc) =>
            if err and err.error is "not_found"
                db.save '_design/doctypes',
                    all:
                        map: """
                        function(doc) {
                            if(doc.docType) {
                                return emit(doc.docType, null);
                            }
                        }
                        """
                        # use to make a "distinct"
                        reduce: """
                        function(key, values) {
                            return true;
                        }
                        """

        db.get '_design/device', (err, doc) =>
            if err and err.error is "not_found"
                db.save '_design/device',
                    all:
                        map: """
                        function(doc) {
                            if(doc.docType && doc.docType.toLowerCase() === "device") {
                                return emit(doc._id, doc);
                            }
                        }
                        """
                    byLogin:
                        map: """
                        function (doc) {
                            if(doc.docType && doc.docType.toLowerCase() === "device") {
                                return emit(doc.login, doc)
                            }
                        }
                        """

        db.get '_design/tags', (err, doc) =>
            if err and err.error is "not_found"

                db.save '_design/tags',
                    all:
                        map: """
                        function (doc) {
                        var _ref;
                        return (_ref = doc.tags) != null ? typeof _ref.forEach === "function" ? _ref.forEach(function(tag) {
                           return emit(tag, null);
                            }) : void 0 : void 0;
                        }
                        """
                        # use to make a "distinct"
                        reduce: """
                        function(key, values) {
                            return true;
                        }
                        """

    feed_start = -> feed.startListening db

    db_ensure () ->
        initTokens (tokens, permissions) =>
            request.init (err) =>
                callback() if callback?

