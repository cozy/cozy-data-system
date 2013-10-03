http = require 'http'
instantiateApp = require '../server'

exports.instantiateApp = (done) ->
    @timeout 5000
    @app = instantiateApp()
    @app.listen 8888, '0.0.0.0', done


exports.closeApp = (done) ->
    @app.compound.server.close()
    done()

exports.clearDB = (db) -> (done) ->
    @timeout 5000
    db.destroy (err) ->
        if err and err.error isnt 'not_found'
            console.log "db.destroy err : ", err
            return done err

        setTimeout ->
            db.create (err) ->
                console.log "db.create err : ", err if err
                done err
        , 1000

exports.randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

exports.fakeServer = (json, code=200, callback=null) ->
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


exports.Subscriber = class Subscriber
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
