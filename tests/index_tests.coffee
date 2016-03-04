should = require('chai').Should()
async = require 'async'
helpers = require './helpers'

# connection to DB for "hand work"
db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()

client = helpers.getClient()
indexer = require('../server/lib/indexer')

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
            return callback error if error
            dragonNoteId = body._id if title is "Note 02"

            # we keep this to ensure older app wont break with
            # indexer2, but it is not necessary
            client.post "data/index/#{body._id}", fields: ["title", "content"]
            , (error, response, resbody) ->
                should.not.exist error
                should.exist response
                should.exist resbody
                response.should.have.property 'statusCode'
                response.statusCode.should.equal 200
                resbody.should.have.property "success"
                resbody.success.should.be.ok
                callback error

createFoo = (data) -> (done) ->
    data.docType = 'foo'
    client.post "data/", data, done

describe "Indexation", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before helpers.startApp

    before indexer.init
    before indexer.cleanup

    after helpers.stopApp

    describe "Install application which can manage note", ->

        it "When I send a request to post an application", (done) ->
            data =
                "name": "test"
                "slug": "test"
                "state": "installed"
                "password": "token"
                "permissions":
                    "note":
                        "description": "This application needs ..."
                    "foo":
                        "description": "Handle foos"
                "docType": "Application"
            client.setBasicAuth "home", "token"
            client.post 'access/', data, (err, res, body) =>
                @body = body
                @err = err
                @res = res
                done()

        it "Install application to manage all", (done) ->
            data =
                "name": "testall"
                "slug": "testall"
                "state": "installed"
                "password": "tokenall"
                "permissions": "all": "description": "..."
                "docType": "Application"
            client.setBasicAuth "home", "token"
            client.post 'access/', data, (err, res, body) =>
                @body = body
                @err = err
                @res = res
                done()

        it "Then no error should be returned", ->
            should.equal  @err, null

        it "And HTTP status 201 should be returned", ->
            @res.statusCode.should.equal 201

    describe "Register an index definition", ->

        it "Register definition for foo", (done) =>
            indexDefinition =
                content:
                    nGramLength: 1,
                    stemming: true, weight: 4, fieldedSearch: false

                date:
                    searchable: false, filter: true

            client.setBasicAuth "test", "token"
            client.post "data/index/define/foo", indexDefinition
            , (error, response, body) ->
                return done error if error
                response.statusCode.should.equal 200
                done null

    describe "indexing and searching", ->
        it "Given I index four notes", (done) =>
            async.series [
                createNoteFunction "Note 01", "little stories begin"
                createNoteFunction "Note 02", "great dragons are coming"
                createNoteFunction "Note 03", "small hobbits are afraid"
                createNoteFunction "Note 04", "such as humans"
                (cb) ->
                    client.post "data/",
                        docType: 'foo',
                        content: 'Great, I am speaking of dragons too'
                        otherField: 'something about cozy'
                    , cb
            ], done

        it "wait a bit", helpers.wait 2000

        it "When I send a request to search the notes with dragons", (done) ->
            client.post "data/search/note", { query: "dragons" }
            , (error, response, body) =>
                return done error if error
                @result = body
                done()

        it "Then result is the second note I created", ->
            @result.rows.length.should.equal 1
            @result.rows[0].title.should.equal "Note 02"
            @result.rows[0].content.should.equal "great dragons are coming"

        it "When I send a request to search the foo with dragons", (done) ->
            client.post "data/search/foo", { query: "dragons" }
            , (error, response, body) =>
                return done error if error
                @result = body
                done()

        it "Then result is the foo object", ->
            @result.rows.length.should.equal 1
            @result.rows[0].content.should.equal """
                Great, I am speaking of dragons too"""

        it "When I send a request to search everything with dragons", (done) ->
            client.setBasicAuth "test", "token"
            client.post "data/search/", { query: "dragons" }
            , (error, response, body) =>
                return done error if error
                @res = response
                done()

        it "Then result I get a 403", ->
            if process.env.NODE_ENV is 'test'
                @res.statusCode.should.equal 403

        it "When I send a request to search everything with dragons", (done) ->
            client.setBasicAuth "testall", "tokenall"
            client.post "data/search/", { query: "dragons" }
            , (error, response, body) =>
                return done error if error
                response.statusCode.should.equal 200
                @result = body
                done()

        it "Then result I get both", ->
            @result.rows.length.should.equal 2


    describe "Reindexing", ->

        it "When I erase the index", (done) ->
            require('../server/lib/indexer').cleanup done

        it "And stop the DS", helpers.stopApp
        it "And start the DS", helpers.startApp

        it "wait a bit", helpers.wait 2000

        it "Then the index was restored", (done) ->
            client.post "data/search/", { query: "dragons" }
            , (error, response, body) =>
                return done error if error
                body.rows.length.should.equal 2
                done()

    describe "Change the index definition", ->

        it "Searching doesnt work in non indexed field", (done) ->
            client.post "data/search/", { query: "cozy" }
            , (error, response, body) =>
                return done error if error
                body.rows.length.should.equal 0
                done()

        it "Change definition for foo", (done) =>
            indexDefinition =
                content:
                    nGramLength: {gte: 1, lte: 2},
                    stemming: true, weight: 1, fieldedSearch: true
                otherField:
                    stemming: true, weight: 1

            client.post "data/index/define/foo", indexDefinition
            , (error, response, body) ->
                return done error if error
                done null

        it "Wait a few seconds", helpers.wait 2000

        it "Then the index was updated", (done) ->
            client.post "data/search/", { query: "cozy" }
            , (error, response, body) =>
                return done error if error
                body.rows.length.should.equal 1
                done()

    describe "Stemming", ->

        it "Can find with or without plural/conjugated form", (done) ->

            client.post "data/search/", { query: ["speak", "dragon"] }
            , (error, response, body) =>
                return done error if error
                body.rows.length.should.equal 1
                done()

    describe "ngramming", ->

        it "Can find document containing several term", (done) ->

            client.post "data/search/", { query: ["great", "dragon"] }
            , (error, response, body) =>
                return done error if error
                body.rows.length.should.equal 2
                done()

        it "Can find document with accurate sentence", (done) ->

            client.post "data/search/", { query: ["great dragons"] }
            , (error, response, body) =>
                return done error if error
                body.rows.length.should.equal 1
                done()

    describe "Filtering", ->

        before createFoo content: "Hello 1", date: "2015-10-10T10:10:00"
        before createFoo content: "Hello 2", date: "2015-20-10T10:10:00"
        before createFoo content: "Hello 3", date: "2015-30-10T10:10:00"

        it "Wait a bit", helpers.wait 2000

        it "Can find document with filter", (done) ->

            options =
                query: "Hello"
                filter: date: [['2015-05', '2015-25']]

            client.post "data/search/", options, (error, response, body) =>
                return done error if error
                body.rows.length.should.equal 2
                done()

    describe "Facets", ->

        it "When I send a request to search everything with dragons", (done) ->
            options =
                query: 'dragons'
                facets: docType: {}

            client.post "data/search/", options, (error, response, body) =>
                return done error if error
                @result = body
                done()

        it "Then I can see the repartition of docTypes in body", ->
            @result.facets.length.should.equal 1
            @result.facets[0].key.should.equal 'docType'
            @result.facets[0].value.length.should.equal 2
            hasOneNote = @result.facets[0].value.some (v) ->
                v.key is 'note' and v.value is 1
            hasOneFoo = @result.facets[0].value.some (v) ->
                v.key is 'foo' and v.value is 1

            (hasOneFoo and hasOneNote).should.be.true
