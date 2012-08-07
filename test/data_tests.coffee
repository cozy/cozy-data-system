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



before (done) ->
    # Prepare database for tests
    db.save '321', {"value":"val"} # insert id 321 : Existence

    # start app
    app.listen(8888)
    done()

after (done) ->
    app.close()
    done()



describe "Existence", ->
    describe "Check Existence of a Note that does not exist in database", ->
        it "When I send a request to check existence of Note with id 123", \
                (done) ->
            client.get "data/exist/123/", (error, response, body) =>
                response.should.be.json
                response.statusCode.should.equal(200)
                @body = JSON.parse body
                done()

        it "Then {exist: false} should be returned", ->
            should.exist @body.exist
            @body.exist.should.not.be.ok

    describe "Check Existence of a Note that does exist in database", ->
        it "When I send a request to check existence of Note with id 321", \
                (done) ->
            client.get "data/exist/321/", (error, response, body) =>
                response.should.be.json
                response.statusCode.should.equal(200)
                @body = JSON.parse body
                done()

        it "Then {exist: true} should be returned", ->
            should.exist @body.exist
            @body.exist.should.be.ok



describe "Find", ->
    describe "Find a Note that does not exist in database", ->
        it "When I send a request to get Note with id 123", (done) ->
            client.get "data/123/", (error, response, body) =>
                @response = response
                done()

        it "Then error 404 should be returned", ->
            @response.statusCode.should.equal(404)

    describe "Find a Note that does exist in database", ->
        it "When I send a request to get Note with id 321", (done) ->
            client.get 'data/321/', (error, response, body) =>
                response.should.be.json
                response.statusCode.should.equal(200)
                @body = JSON.parse body
                done()

        it "Then { _id: '321', value: 'val'} should be returned", ->
            @body.should.deep.equal {"_id": '321', "value":"val"}
