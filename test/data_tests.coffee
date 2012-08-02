should = require('should')
async = require('async')
Client = require('../common/test/client').Client
app = require('../server')


client = new Client("http://localhost:8888/")


describe "Test section", ->

    before (done) ->
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
            
	# L'element d'id 321 doit etre ajoute a la main dans la base.
        it "When I send a request to check existence of Note with id 321", \
                (done) ->
            client.get "data/exist/321/", (error, response, body) =>
                @body = JSON.parse body
                done()

        it "Then {exist: true} should be returned", ->
            should.exist @body.exist
            @body.exist.should.be.ok

