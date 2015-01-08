http = require 'http'
fs = require 'fs'
querystring = require 'querystring'
S = require 'string'

log =  require('printit')
    date: true
    prefix: 'downloader'

# Get Couch credentials from config file.
initLoginCouch = (callback) ->
    data = fs.readFile '/etc/cozy/couchdb.login', (err, data) ->
        if err
            callback err
        else
            lines = S(data.toString('utf8')).lines()
            callback null, lines


makeAborter = () ->
    aborted = false
    return abortable =
        aborted: -> aborted
        abort: ->
            aborted = true
            this.err = new Error 'aborted'



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
            if err and process.NODE_ENV is 'production'
                callback err
            else if aborted
                callback new Error 'aborted'
            else

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
                        err = new Error 'Not Found'
                        err.statusCode = 404
                        callback err
                    else if res.statusCode isnt 200
                        err = callback new Error """
                            error occured while downloading attachment #{err.message} """
                        err.statusCode = res.statusCode
                        callback err
                    else
                        callback null, res

                request.on 'error', callback

        return abortable =
            abort: ->
                aborted = true
                request?.abort()
                callback new Error 'aborted'

