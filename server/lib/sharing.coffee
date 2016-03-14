db = require('../helpers/db_connect_helper').db_connect()
async = require 'async'
request = require 'request-json'
log = require('printit')
    prefix: 'sharing'

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

# If the hostUrl is already set, do not get the domain to avoid
# unacessary call and potential domain mismatch on the target side
checkDomain = (params, callback) ->
    unless params.hostUrl?
        # Get the cozy url to let the target knows who is the sender
        getDomain (err, domain) ->
            if err? or not domain?
                callback new Error 'No instance domain set'
            else
                params.hostUrl = domain
                callback err, params
    else
        callback null, params


# Send a notification to a target url on the specified path
# Params must at least contain:
#   url     -> the url of the target
#   hostUrl -> [optionnal] the url of the cozy. Will be get if not set

# A successful request is expected to return a 200 HTTP status 
module.exports.notifyTarget = (path, params, callback) ->
    # Get the domain if not already set
    checkDomain params, (err, params) ->

        remote = request.createClient params.url
        remote.post path, params, (err, result, body) ->
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
        auth = params.id + ":" + params.target.token
        url = params.target.url.replace "://", "://" + auth + "@" 

        replication =
            source: "cozy"
            target: url + "/services/sharing/replication/" 
            continuous: params.continuous or false
            doc_ids: params.docIDs

        log.info  "Replicate " + JSON.stringify params.docIDs + " to " + url

        db.replicate replication.target, replication, (err, body) ->
            if err? then callback err
            else if not body.ok
                err = "Replication failed"
                callback err
            else
                # The _local_id field is returned only if continuous
                callback null, body._local_id

# Interrupt the running replication
module.exports.cancelReplication = (replicationID, callback) ->
    unless replicationID?
        err = new Error 'Parameters missing'
        err.status = 400
        callback err
    else
        cancel =
            replication_id: replicationID
            cancel: true

        db.replicate '', cancel, (err, body) ->
            if err?
                callback err
            else if not body.ok
                err = "Cancel replication failed"
                callback err
            else
                callback()
