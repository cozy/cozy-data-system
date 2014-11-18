should = require('chai').Should()
fs = require 'fs'
Client = require('request-json').JsonClient
helpers = require './helpers'

# connection to DB for "hand work"
db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()

serverUrl = "http://#{helpers.options.serverHost}:#{helpers.options.serverPort}/"

describe "Binaries", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before (done) ->
        db.save '321', value: "val", done

    before helpers.startApp

    # Start application before starting tests.
    before (done) ->
        @client = new Client serverUrl
        @client.setBasicAuth "home", "token"
        files = fs.readdirSync '/tmp'
        @nbOfFileInTmpFolder = files.length
        done()

    after helpers.stopApp

    describe "Add a binary", ->

        it "When I post an attachment to an unexisting document", (done) ->
            @client.sendFile "data/123/binaries/", "./tests/fixtures/test.png", \
                            (err, res, body) =>
                console.log err if err
                @response = res
                done()

        it "Then I got a 404 response", ->
            @response.statusCode.should.equal 404

        it "When I post an attachment", (done) ->
            @client.sendFile "data/321/binaries/", "./tests/fixtures/test.png", \
                            (err, res, body) =>
                console.log err if err?
                @response = res
                done()

        it "Then I got a success response", ->
            @response.statusCode.should.equal 201

        it "And the file doesn't stay in the ./tmp folder", ->
            files = fs.readdirSync '/tmp'
            @nbOfFileInTmpFolder.should.equal files.length

        it "And id and revision of binary should be updated", (done)->
            @client.get "data/321/", (err, res, body) =>
                console.log err if err
                id = body.binary["test.png"].id
                rev = body.binary["test.png"].rev
                db.get id, (err, body) ->
                    body._rev.should.be.equal rev
                    done()

    describe "Retrieve a binary", ->

        it "When I claim this binary", (done) ->
            @client = new Client serverUrl
            @client.setBasicAuth "home", "token"
            @client.saveFile "data/321/binaries/test.png", \
                             './tests/fixtures/test-get.png', -> done()

        it "I got the same file I attached before", (done) ->
            @timeout 5000
            setTimeout ->
                fileStats = fs.statSync './tests/fixtures/test.png'
                resultStats = fs.statSync './tests/fixtures/test-get.png'
                resultStats.size.should.equal fileStats.size
                done()
            , 2000

    describe "Remove an attachment", ->

        it "When I remove this binary", (done) ->
            delete @response
            @client.del 'data/321/binaries/test.png', (err, res) =>
                @response = res
                done()

        it "Then I have a success response", ->
            @response.statusCode.should.equal 204

        it "When I claim this attachment", (done) ->
            delete @response
            @client.get 'data/321/binaries/test.png', (err, res, body) =>
                @response = res
                done()

        it "And I got a 404 response", ->
            @response.statusCode.should.equal 404

        it "And binary of data should be deleted", (done) ->
            @client.get 'data/321/', (err, res, body) =>
                should.not.exist body.binary["test.png"]
                done()

    describe "Convert attachment to binary", ->
        it "When I create a document with two attachments", (done) ->
            db.save '321', value: "val", (err, res, body) =>
                path = "data/321/attachments/"
                file = "./tests/fixtures/test.png"
                @client.sendFile path, file, (err, res, body) =>
                    file = "./tests/fixtures/test-get.png"
                    @client.sendFile path, file, (err, res, body) =>
                        done()

        it "And I convert document", (done) ->
            @client.get 'data/321/binaries/convert', (err, res, body) ->
                @err = err
                done()

        it "Then document should have only binary", (done) ->
            @client.get 'data/321/', (err, res, doc) =>
                should.exist doc.binaries
                should.not.exist doc._attachment
                should.exist doc.binaries['test.png']
                should.exist doc.binaries['test-get.png']
                @binary1 = doc.binaries['test.png'].id
                @binary2 = doc.binaries['test-get.png'].id
                done()

        it "And add an application to access to binary", (done) ->
            app =
                "name": "test"
                "slug": "test"
                "state": "installed"
                "password": "secret"
                "permissions":
                    "Binary":
                        "description": "This application needs manage binary because ..."
                "docType": "Application"
            @client.post 'data/', app, (err, res, doc) =>
                @client.setBasicAuth 'test', 'secret'
                done()

        it "And document wich contain first binary should exist", (done) ->
            @client.setBasicAuth 'test', 'secret'
            @client.get "data/#{@binary1}/", (err, res, doc) =>
                should.exist doc._attachments
                should.exist doc._attachments['test.png']
                should.exist doc.docType
                doc.docType.should.equal 'Binary'
                done()

        it "And document wich contain second binary should exist", (done) ->
            @client.get "data/#{@binary2}/", (err, res, doc) ->
                should.exist doc._attachments
                should.exist doc._attachments['test-get.png']
                should.exist doc.docType
                doc.docType.should.equal 'Binary'
                done()