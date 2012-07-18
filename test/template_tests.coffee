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

    describe "My test", ->
        it "When I run a test, it succeeds", (done) ->
            should.exist "my testi"
            done()
