db = require('../helpers/db_connect_helper').db_connect()
checkPermissions = require('../helpers/utils').checkReplicationPermissionsSync
request = require 'request'
url = require 'url'
through = require 'through'
log = require('printit')
    date: true
    prefix: 'replication'

getCredentialsHeader = ->
    username = db.connection.auth.username
    password = db.connection.auth.password
    credentials = "#{username}:#{password}"
    basicCredentials = new Buffer(credentials).toString 'base64'
    return "Basic #{basicCredentials}"


uCaseWord = (word) ->
    switch word
        when 'etag' then return 'ETag'
        else
            return word.replace /^./,(l) ->
                return l.toUpperCase()

uCaseHeader = (headerName) ->
    return headerName.replace /\w*/g, uCaseWord

# Add uppercase for fields headers (removed by nodejs)
couchDBHeaders = (nodeHeaders) ->
    couchHeaders = {}
    for  name in Object.keys(nodeHeaders)
        couchHeaders[uCaseHeader(name)] = nodeHeaders[name]
    return couchHeaders


retrieveJsonDocument = (data) ->
    # Retrieve separator
    startJson = data.indexOf 'Content-Type: application/json'
    if startJson is -1
        # Document is not full
        # Appplication/json isn't is data
        return ['document not full', null]
    json = data.substring 0, startJson
    endSeparator = json.lastIndexOf '\n'
    json = json.substring(0, endSeparator)
    startSeparator = json.lastIndexOf '\n'
    separator = data.substring startSeparator+1, endSeparator-1

    # Retrieve Json part
    startJsonPart = data.indexOf separator
    json = data.substring startJson, data.length
    endJsonPart = json.indexOf(separator)
    if endJsonPart is -1
        # Document is not full
        # JSON part isn't full
        return ['document not full', null]
    jsonPart = json.substring 0, endJsonPart

    # Retrieve JSON document
    startJson = jsonPart.indexOf '{'
    endJson = jsonPart.lastIndexOf '}'
    json = jsonPart.substring startJson, endJson+1
    return [null, JSON.parse(json)]


requestOptions = (req) ->
    # Add his creadentials for CouchDB
    headers = couchDBHeaders(req.headers)
    if process.env.NODE_ENV is "production"
        headers['Authorization'] = getCredentialsHeader()
    else
        # Do not forward 'authorization' header in other environments
        # in order to avoid wrong authentications in CouchDB
        headers['Authorization'] = null

    # Retrieve couchDB url
    targetURL = req.url.replace('replication', db.name)
    host = db.connection.host
    port = db.connection.port
    options =
        method: req.method
        headers: headers
        uri: url.resolve "http://#{host}:#{port}", targetURL

    # Retrieve Json body if necessary
    if req.body and options.headers['Content-Type'] is 'application/json'
        if req.body? and Object.keys(req.body).length > 0
            bodyToTransmit = JSON.stringify req.body
            options['body'] = bodyToTransmit
            # Check doc : bodyToTransmit
            docInfo = {id: bodyToTransmit._id, docType: bodyToTransmit.docType}
            err = checkPermissions req, docInfo
            return [err, options]
    return [null, options]


module.exports.proxy = (req, res, next) ->
    [err, options] = requestOptions req
    # Device isn't authorized if err
    return res.status(403).send err if err?

    stream = through()
    couchReq  = request options
        # Receive from couchDB and transmit it to device
        .on 'response', (response) ->
            # Set headers and statusCode
            headers = couchDBHeaders(response.headers)
            res.set headers
            res.statusCode = response.statusCode

            # Retrieve body
            data = []
            permissions = false
            # Permissions already checked
            if req.route.path is '/replication/:id([^_]*)/:name*'
                permissions = true
            response.on 'data', (chunk) ->
                # When replication are heartbeat it's send \n every 10 seconds
                # so we don't want to have a processing
                if req.method is 'GET' and \
                        not (req.query.heartbeat and chunk.toString() is "\n")
                    if permissions
                        res.write chunk
                    else
                        data.push chunk
                        # Retrieve document
                        if headers['Content-Type'] is 'application/json'
                            try
                                doc = JSON.parse Buffer.concat(data)
                            catch err
                                log.info "Buffer isn't a JSON valid."
                        else
                            content = Buffer.concat(data).toString()
                            [err, doc] = retrieveJsonDocument content
                        # Check document docType and id
                        if doc
                            docInfo = {id: doc._id, docType: doc.docType}
                            err = checkPermissions req, docInfo
                            if err
                                # Device isn't authorized
                                res.status(403).send err
                                couchReq.end()
                            else
                                permissions = true
                                res.write Buffer.concat(data)
                else
                    res.write chunk

            response.on 'end', ->
                res.end()

        .on 'error', (err) ->
            return res.status(500).send err

    stream.pipe couchReq

    # Receive body from device and transmit it on couchDB
    data = []
    permissions = false
    req.on 'data', (chunk) ->
        if permissions
            stream.emit 'data', chunk
        else
            data.push chunk
            [err, doc] = retrieveJsonDocument Buffer.concat(data).toString()
            unless err
                # Check doc
                docInfo = {id: doc._id, docType: doc.docType}
                err = checkPermissions req, docInfo
                if err
                    # Device isn't authorized
                    res.status(403).send err
                    stream.emit 'end'
                    couchReq.end()
                    req.destroy()
                else
                    permissions = true
                    stream.emit 'data', Buffer.concat(data)

    req.on 'end', ->
        stream.emit 'end'
