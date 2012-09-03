should = require('chai').Should()
async = require('async')
Client = require('../common/test/client').Client
app = require('../server')

client = new Client("http://localhost:8888/")

# connection to DB for "hand work"
cradle = require 'cradle'
connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database('cozy')

# helpers

cleanRequest = ->
    delete @body
    delete @response

parseBody = (response, body) ->
    if typeof body is "object" then body else JSON.parse body

randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

# Clear DB, create a new one, then init data for tests.
before (done) ->
    db.destroy ->
        console.log 'DB destroyed'
        db.create ->
            console.log 'DB recreated'
            db.save '321', {"value":"val"}, ->
                done()

# Start application before starting tests.
before (done) ->
    app.listen(8888)
    done()

# Stop application after finishing tests.
after (done) ->
    app.close()
    done()



describe "Access to a view", ->
    describe "Access to a non existing view", ->
        before cleanRequest

        it "When I send a request to access view dont-exist", (done) ->
            client.get "request/dont-exist", (error, response, body) =>
                @response = response
                done()

        it "Then error 404 should be returned", ->
            @response.statusCode.should.equal 404
