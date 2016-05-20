db = require('../helpers/db_connect_helper').db_connect()
replicator = require('../helpers/db_connect_helper').db_replicator_connect()
async = require 'async'
request = require 'request-json'
log = require('printit')
    prefix: 'sharing'
User = require './user'
user = new User()

replications = {}


# Called each time a change occurs in the _replicator db
onChange = (change) ->
    if replications[change.id]?
        cb = replications[change.id]
        delete replications[change.id]

        # Check the replication status
        replicator.get change.id, (err, doc) ->
            if err?
                cb err
            else if doc._replication_state is "error"
                err = "Replication failed"
                cb err
            else
                cb null, change.id


# Get the Cozy url
getDomain = (callback) ->
    db.view 'cozyinstance/all', (err, instance) ->
        return callback err if err?

        if instance?[0]?.value.domain?
            domain = instance[0].value.domain
            domain = "https://#{domain}/" if not (domain.indexOf('http') > -1)
            callback null, domain
        else
            callback null


# Retrieve the domain if the url is not set, to avoid
# unacessary call and potential domain mismatch on the target side
checkDomain = (url, callback) ->
    unless url?
        # Get the cozy url to let the target knows who is the sender
        getDomain (err, domain) ->
            if err? or not domain?
                callback new Error 'No instance domain set'
            else
                callback err, domain
    else
        callback null, url


# Utility function to handle notifications responses
handleNotifyResponse = (err, result, body, callback) ->
    if err?
        callback err
    else if not result?.statusCode?
        err = new Error "Bad request"
        err.status = 400
        callback err
    else if body?.error?
        err = body
        err.status = result.statusCode
        callback err
    else if result?.statusCode isnt 200
        err = new Error "The request has failed"
        err.status = result.statusCode
        callback err
    else
        callback()


# Send a notification to a recipient url on the specified path
# A successful request is expected to return a 200 HTTP status
module.exports.notifyRecipient = (url, path, params, callback) ->
    # Get the domain if not already set
    checkDomain params.sharerUrl, (err, domain) ->
        return err if err?
        params.sharerUrl = domain

        # Get the user name
        user.getUser (err, userInfos) ->
            return err if err?
            params.sharerName = userInfos.public_name

            # Send to recipient
            remote = request.createClient url
            remote.post path, params, (err, result, body) ->
                handleNotifyResponse err, result, body, callback


# Send a notification to a recipient url on the specified path
# A successful request is expected to return a 200 HTTP status
module.exports.notifySharer = (url, path, params, callback) ->
    # Get the domain if not already set
    checkDomain params.recipientUrl, (err, domain) ->
        return err if err?

        params.recipientUrl = domain
        remote = request.createClient url
        remote.post path, params, (err, result, body) ->
            handleNotifyResponse err, result, body, callback


# Send a revocation request to the specified url
module.exports.sendRevocation = (url, path, params, callback) ->
    remote = request.createClient url
    remote.del path, params, (err, result, body) ->
        handleNotifyResponse err, result, body, callback


# Replicate documents to the specified target
# Params must contain:
#   id         -> the Sharing id, used as a login
#   target     -> contains the url and the token of the target
#   docIDs     -> the ids of the documents to replicate
#   continuous -> [optionnal] if the sharing is synchronous or not
module.exports.replicateDocs = (params, callback) ->
    unless params.target? and params.docIDs? and params.id?
        err = new Error 'Parameters missing'
        err.status = 400
        callback err
    else
        # Add the credentials in the url
        auth = "#{params.id}:#{params.target.token}"
        url = params.target.recipientUrl.replace "://", "://#{auth}@"

        couchCred = db.connection
        couch = [couchCred.host, couchCred.port]
        if couchCred.auth?
            couchAuth = "#{couchCred.auth.username}:#{couchCred.auth.password}"
            source = "http://#{couchAuth}@#{couch[0]}:#{couch[1]}/cozy"
        else
            source = "http://#{couch[0]}:#{couch[1]}/cozy"

        replication =
            source: source
            target: url + "/services/sharing/replication/"
            continuous: params.continuous or false
            doc_ids: params.docIDs


        # When a continuous replication is triggered, it must be saved in the
        # _relicator db to retrieve the connection even after a restart
        if replication.continuous
            replicator.save replication, (err, body) ->
                if err? then callback err
                else if not body.ok
                    err = "Replication failed"
                    callback err
                else
                    # The replication id and callback are needed when
                    # the changes feed is triggered
                    replications[body.id] = callback

        # The replication is not continuous : no need to keep it in db
        else
            db.replicate replication.target, replication, (err, body) ->
                if err? then callback err
                else if not body.ok
                    err = "Replication failed"
                    callback err
                else
                    callback null


# Interrupt the running replication
module.exports.cancelReplication = (replicationID, callback) ->
    unless replicationID?
        err = new Error 'Parameters missing'
        err.status = 400
        callback err
    else
        replicator.remove replicationID, (err) ->
            callback err


# Listen for a change on the replicator db, to know when a
# replication has been launched
changes = replicator.changes since: 'now'
changes.on 'change', onChange
changes.on 'error', (err) ->
    log.error "Replicator feed error : #{err.stack}"
