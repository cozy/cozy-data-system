http = require 'http'
instantiateApp = require '..'

exports.instantiateApp = (done) ->
    @app = instantiateApp()
    @app.listen 8888
    @app.on 'db ready', done


exports.closeApp = (done) ->
    @app.compound.server.close()
    done()

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
                callback req.url, data
            res.end(JSON.stringify json)


exports.Subscriber = class Subscriber
    calls:[]
    callback: ->
    wait: (callback) ->
        @callback = callback
    listener: (pattern, channel, msg) =>
        @calls.push channel:channel, msg:msg
        @callback()
        @callback = ->
    haveBeenCalled: (channel, msg) =>
        @calls.some (call) -> call.channel is channel and call.msg is msg
