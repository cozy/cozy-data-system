http = require 'http'
Client = require('request-json').JsonClient
logger = require('printit')
    date: false
    prefix: 'tests:helper'
helpers = {}

# Mandatory
process.env.TOKEN = "token"

if process.env.COVERAGE
    helpers.prefix = '../instrumented/'
else if process.env.USE_JS
    helpers.prefix = '../build/'
else
    helpers.prefix = '../'

# server management
helpers.options =
    serverHost: process.env.HOST or 'localhost'
    serverPort: process.env.PORT or 8888

    # default port must also be changed in server/lib/indexer.coffee
    indexerPort: process.env.INDEXER_PORT or 9092
    # default port must also be changed in server/lib/feed.coffee
    axonPort: parseInt process.env.AXON_PORT or 9105

# default client
client = new Client "http://#{helpers.options.serverHost}:#{helpers.options.serverPort}/"

# set the configuration for the server
process.env.HOST = helpers.options.serverHost
process.env.PORT = helpers.options.serverPort

# Returns a client if url is given, default app client otherwise
helpers.getClient = (url = null) ->
    if url?
        return new Client url
    else
        return client

initializeApplication = require "#{helpers.prefix}server"

helpers.startApp = (done) ->

    @timeout 15000
    initializeApplication (app, server) =>
        @app = app
        @app.server = server
        done()

helpers.stopApp = (done) ->

    @timeout 10000
    setTimeout =>
        @app.server.close done
    , 250

helpers.clearDB = (db) -> (done) ->
    @timeout 10000
    logger.info "Clearing DB..."
    db.destroy (err) ->
        logger.info "\t-> Database destroyed!"
        if err and err.error isnt 'not_found'
            logger.info "db.destroy err : ", err
            return done err

        setTimeout ->
            logger.info "Waiting a bit..."
            db.create (err) ->
                logger.info "\t-> Database created"
                logger.info "db.create err : ", err if err
                done err
        , 1000

helpers.randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

helpers.fakeServer = (json, code=200, callback=null) ->
    http.createServer (req, res) ->
        body = ""
        req.on 'data', (chunk) ->
            body += chunk
        req.on 'end', ->
            res.writeHead code, 'Content-Type': 'application/json'
            if callback?
                data = JSON.parse body if body? and body.length > 0
                result = callback req.url, data
            resbody = if result then JSON.stringify result
            else JSON.stringify json
            res.end resbody


helpers.Subscriber = class Subscriber
    calls:[]
    callback: ->
    wait: (callback) ->
        @callback = callback
    listener: (channel, msg) =>
        @calls.push channel:channel, msg:msg
        @callback()
        @callback = ->
    haveBeenCalled: (channel, msg) =>
        @calls.some (call) -> 
            call.channel is channel and call.msg is msg

module.exports = helpers
