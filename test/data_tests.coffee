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



describe "Existence", ->
    describe "Check Existence of a Document that does not exist in database", ->
        before cleanRequest

        it "When I send a request to check existence of Document with id 123", \
                (done) ->
            client.get "data/exist/123/", (error, response, body) =>
                response.statusCode.should.equal(200)
                @body = parseBody response, body
                done()

        it "Then {exist: false} should be returned", ->
            should.exist @body.exist
            @body.exist.should.not.be.ok

    describe "Check Existence of a Document that does exist in database", ->
        before cleanRequest

        it "When I send a request to check existence of Document with id 321", \
                (done) ->
            client.get "data/exist/321/", (error, response, body) =>
                response.statusCode.should.equal(200)
                @body = parseBody response, body
                done()

        it "Then {exist: true} should be returned", ->
            should.exist @body.exist
            @body.exist.should.be.ok



describe "Find", ->
    describe "Find a Document that does not exist in database", ->
        before cleanRequest

        it "When I send a request to get Document with id 123", (done) ->
            client.get "data/123/", (error, response, body) =>
                @response = response
                done()

        it "Then error 404 should be returned", ->
            @response.statusCode.should.equal(404)

    describe "Find a Document that does exist in database", ->
        before cleanRequest

        it "When I send a request to get Document with id 321", (done) ->
            client.get 'data/321/', (error, response, body) =>
                response.statusCode.should.equal(200)
                @body = parseBody response, body
                done()

        it "Then { _id: '321', value: 'val'} should be returned", ->
            @body.should.deep.equal {"_id": '321', "value":"val"}

describe "Create", ->
    describe "Try to Create a Document with id 321", ->
        before cleanRequest

        it "When I send a request to create a document with id 321", (done) ->
            client.post 'data/321/', {"value":"created value"}, \
                        (error, response, body) =>
                @response = response
                done()

        it "Then error 409 should be returned", ->
            @response.statusCode.should.equal(409)

    describe "Create a Document with id 987", ->
        before cleanRequest

        it "When I send a request to create a document with id 987", (done) ->
            client.post 'data/987/', {"value":"created value"}, \
                        (error, response, body) =>
                response.statusCode.should.equal 201
                @body = parseBody response, body
                done()

        it "Then { _id: '987' } should be returned", ->
            @body.should.have.property '_id', '987'

    describe "Create a Document without an id", ->
        before cleanRequest

        it "When I send a request to create a document without an id", (done) ->
            client.post 'data/', {"value":"created value"}, \
                        (error, response, body) =>
                response.statusCode.should.equal(201)
                @body = parseBody response, body
                done()

        it "Then the id of the new document should be returned", ->
            @body.should.have.property '_id'

