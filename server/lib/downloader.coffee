http = require 'http'
fs = require 'fs'
querystring = require 'querystring'
S = require 'string'
errors = require '../middlewares/errors'

# Get Couch credentials from config file.
initLoginCouch = (callback) ->
    data = fs.readFile '/etc/cozy/couchdb.login', (err, data) ->
        if err
            callback err
        else
            lines = S(data.toString('utf8')).lines()
            callback null, lines

# when the download fail, stream should be drained in order to release the
# http connection from the pool. This function put stream in flowing mode
# and discard the data. When this function is called, the short content
# ({error: "not_found"}) is already buffered, so its simpler to read &
# discard than to abort.
releaseStream = (stream) ->
    stream.on 'data', ->
    stream.on 'end', ->
    stream.resume()



# Module to handle attachment download with the low level http api instead of
# request (the lib used by cradle). This is due to a too high memory
# consumption while dowloading big files with request.
module.exports =

    # Returns the attachment in a callback as a readable stream of data.
    download: (id, attachment, rawcallback) ->

        # Build couch path to fetch attachements.
        dbName = process.env.DB_NAME or 'cozy'
        attachment = querystring.escape attachment
        path = "/#{dbName}/#{id}/#{attachment}"
        aborted = false
        request = null
        callback = (err, stream) ->
            rawcallback err, stream
            callback = ->

        initLoginCouch (err, couchCredentials) ->
            return callback err if err and process.NODE_ENV is 'production'
            return callback new Error 'aborted' if aborted

            # Build options.
            options =
                host: process.env.COUCH_HOST or 'localhost'
                port: process.env.COUCH_PORT or 5984
                path: path

            # Add couch credentials only in production environment.
            if not err and process.env.NODE_ENV is 'production'
                id = couchCredentials[0]
                pwd = couchCredentials[1]

                credentialsBuffer = new Buffer("#{id}:#{pwd}")
                basic = "Basic #{credentialsBuffer.toString('base64')}"
                options.headers =
                    Authorization: basic

            # Perform request
            request = http.get options, (res) ->
                if res.statusCode is 404
                    callback errors.http 404, 'Not Found'
                    # discard the couchdb request
                    releaseStream res
                else if res.statusCode isnt 200
                    msg = err.message
                    err = callback new Error """
                        error occured while downloading attachment #{msg} """
                    err.status = res.statusCode
                    callback err
                    # discard the couchdb request
                    releaseStream res
                else
                    callback null, res

            request.on 'error', callback

        return abortable =
            abort: ->
                aborted = true
                request?.abort()
                callback new Error 'aborted'

