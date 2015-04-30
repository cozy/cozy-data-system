db = require('../helpers/db_connect_helper').db_connect()
json = require 'request-json'
request = require 'request'
url = require 'url'

getCredentialsHeader = ->
    credentials = "#{db.connection.auth.username}:#{db.connection.auth.password}"
    basicCredentials = new Buffer(credentials).toString 'base64'
    return "Basic #{basicCredentials}"

module.exports.proxy = (req, res, next) ->
    # Add his creadentials for CouchDB
    auth = req.headers['authorization']
    if process.env.NODE_ENV is "production"
        req.headers['authorization'] = getCredentialsHeader()
    else
        # Do not forward 'authorization' header in other environments
        # in order to avoid wrong authentications in CouchDB
        req.headers['authorization'] = null
    req.url = req.url.replace('replication', db.name)

    targetURL = req.url.replace 'replication', 'cozy'
    options =
        method: req.method
        headers: req.headers
        uri: url.resolve "http://#{db.connection.host}:#{db.connection.port}", targetURL

    # restringify the body
    bodyToTransmit = JSON.stringify req.body
    if bodyToTransmit? and bodyToTransmit.length > 0
        options['body'] = bodyToTransmit
    if options.method is 'HEAD'
        delete options.body
    request options, (err, couchRes, body) ->
        req.headers['authorization'] = auth
        if err? or not couchRes?
            console.log err
            res.send 500, err
        else
            if req.method is 'GET'
                req.info = [couchRes.headers, couchRes.statusCode]
                res.body = body
                next()
            else
                res.set couchRes.headers
                res.statusCode = couchRes.statusCode
                res.send body
