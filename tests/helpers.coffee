http = require 'http'

helpers = {}

# server management
helpers.options = {}
helpers.app = null

initializeApplication = require '../server'

helpers.startApp = (done) ->
    @timeout 10000

    process.env.HOST = helpers.options.serverHost
    process.env.PORT = helpers.options.serverPort

    initializeApplication (app, server) =>
        @app = app
        @app.server = server
        done()

helpers.stopApp = (done) ->
    @timeout 1000
    setTimeout =>
        @app.server.close done
    , 250

helpers.clearDB = (db) -> (done) ->
    @timeout 10000
    console.log "Clearing DB..."
    db.destroy (err) ->
        console.log "\t-> Database destroyed!"
        if err and err.error isnt 'not_found'
            console.log "db.destroy err : ", err
            return done err

        setTimeout ->
            console.log "Waiting a bit..."
            db.create (err) ->
                console.log "\t-> Database created"
                console.log "db.create err : ", err if err
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
        @calls.some (call) -> call.channel is channel and call.msg is msg

module.exports = helpers
