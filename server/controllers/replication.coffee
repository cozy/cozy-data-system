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
    targetURL = req.url.replace('replication', db.name)

    options =
        method: req.method
        headers: req.headers
        uri: url.resolve "http://#{db.connection.host}:#{db.connection.port}", targetURL

    # restringify the body

    if req.body? and Object.keys(req.body).length > 0
        bodyToTransmit = JSON.stringify req.body
        options['body'] = bodyToTransmit
    request options, (err, couchRes, body) ->
        req.headers['authorization'] = auth
        if err? or not couchRes?
            console.log err
            res.send 500, err
        else
            if req.method is 'GET'
                req.info = [couchRes.headers, couchRes.statusCode]
                req.body = body
                next()
            else
                res.set couchRes.headers
                res.statusCode = couchRes.statusCode
                res.send body
