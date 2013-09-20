should = require('chai').Should()
async = require('async')
fakeServer = require('./helpers').fakeServer
Client = require('request-json').JsonClient
helpers = require('./helpers')
process.env.TOKEN = "token"

client = new Client("http://localhost:8888/")
db = require('../helpers/db_connect_helper').db_connect()



# helpers

dragonNoteId = "0"

# Function for async to create and index notes
createNoteFunction = (title, content) ->
    (callback) ->
        note =
            title: title
            content: content
            docType: "Note"

        client.setBasicAuth "test", "token"
        client.post "data/", note, (error, response, body) ->
            console.log error if error
            dragonNoteId = body._id if title is "Note 02"

            client.post "data/index/#{body._id}",
                fields: ["title", "content"]
                , (error, response, body) ->
                callback error, body


describe "Indexation", ->

    # Clear DB, create a new one, then init data for tests.
    before (done) ->
        indexer = new Client("http://localhost:9102/")
        indexer.del "clear-all/", (err, response) ->
            console.log err if err
            db.destroy ->
                db.create ->
                    done()

    before helpers.instantiateApp

    after helpers.closeApp

<<<<<<< HEAD
    after (done) ->
        db.destroy ->
            db.create (err) ->
                console.log err if err
                done()
=======
    describe "Install application which can manage note", ->

        it "When I send a request to post an application", (done) ->
            data =
                "name": "test"
                "slug": "test"
                "state": "installed"
                "password": "token"
                "permissions":
                    "Note":
                        "description": "This application needs ..."
                "docType": "Application"
            client.setBasicAuth "home", "token"
            client.post 'data/', data, (err, res, body) =>
                @body = body
                @err = err
                @res = res
                done()

        it "Then no error should be returned", ->
            should.equal  @err, null

        it "And HTTP status 201 should be returned", ->
            @res.statusCode.should.equal 201
>>>>>>> 4378c93caf499a0c226d13445118bac55d03fe92

    describe "indexing and searching", ->
        it "Given I index four notes", (done) =>
            async.series [
                createNoteFunction "Note 01", "little stories begin"
                createNoteFunction "Note 02", "great dragons are coming"
                createNoteFunction "Note 03", "small hobbits are afraid"
                createNoteFunction "Note 04", "such as humans"
            ], =>
                done()

        it "When I send a request to search the notes with dragons", (done) ->
            data = ids: [dragonNoteId]
            indexer = fakeServer data, 200, (url, body) ->
                if url is '/index/'
                    should.exist body.fields
                    should.exist body.doc
                    should.exist body.doc.docType
                if url is '/search'
                    should.exist body.query
                    body.query.should.equal "dragons"

            indexer.listen 9092

            client.post "data/search/note", { query: "dragons" }, \
                    (error, response, body) =>
                @result = body
                indexer.close()
                done()

        it "Then result is the second note I created", ->
            @result.rows.length.should.equal 1
            @result.rows[0].title.should.equal "Note 02"
            @result.rows[0].content.should.equal "great dragons are coming"

    describe "Fail indexing", ->

        it "When I index a document that does not exist", (done) ->
            data =
                fields: ["title", "content"]

            client.setBasicAuth "test", "token"
            client.post "data/index/923", data, (error, response, body) =>
                @response = response
                done()

        it "Then it returns a 404 error", ->
            @response.statusCode.should.equal 404
