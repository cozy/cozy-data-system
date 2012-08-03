should = require('should')
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


describe "Test section", ->

    before (done) ->
        # check database state for tests : insert id 321
        db.save '321', {}

        # start app
        app.listen(8888)
        done()

    after (done) ->
        app.close()
        done()

    describe "Existence", ->
        it "When I send a request to check existence of Note with id 123", \
                (done) ->
            client.get "data/exist/123/", (error, response, body) =>
                @body = JSON.parse body
                done()

        it "Then {exist: false} should be returned", ->
            should.exist @body.exist
            @body.exist.should.not.be.ok
            
        it "When I send a request to check existence of Note with id 321", \
                (done) ->
            client.get "data/exist/321/", (error, response, body) =>
                @body = JSON.parse body
                done()

        it "Then {exist: true} should be returned", ->
            should.exist @body.exist
            @body.exist.should.be.ok

