http = require 'http'
fs = require 'fs'
S = require 'string'


# Get Couch credentials from config file.
initLoginCouch = (callback) ->
    data = fs.readFile '/etc/cozy/couchdb.login', (err, data) ->
        if err
            callback err
        else
            lines = S(data.toString('utf8')).lines()
            callback null, lines


# Module to handle attachment download with the low level http api instead of
# request (the lib used by cradle). This is due to a too high memory
# consumption while dowloading big files with request.
module.exports =

    # Returns the attachment in a callback as a readable stream of data.
    download: (id, attachment, callback) ->

        # Build couch patch to fetch attachements.
        dbName = process.env.DB_NAME or 'cozy'
        path = "/#{dbName}/#{id}/#{attachment}"

        initLoginCouch (err, couchCredentials) ->
            if err and process.NODE_ENV is 'production'
                callback err
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
                http.get options, (res) ->
                    if res.statusCode is 404
                        callback error: 'not_found'
                    else if res.statusCode isnt 200
                        callback
                            error: 'error occured while downloading attachment'
                    else
                        callback null, res
