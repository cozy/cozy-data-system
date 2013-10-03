should = require('chai').Should()
fs = require 'fs'
helpers = require('./helpers')
Client = require("request-json").JsonClient
db = require('../helpers/db_connect_helper').db_connect()

describe "Attachments", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before (done) ->
        db.save '321', value: "val", done

    before helpers.instantiateApp

    # Start application before starting tests.
    before (done) ->
        @client = new Client "http://localhost:8888/"
        @client.setBasicAuth "home", "token"
        files = fs.readdirSync('/tmp')
        @nbOfFileInTmpFolder = files.length
        done()

    after helpers.closeApp
    after helpers.clearDB db

    describe "Add an attachment", ->

        it "When I post an attachment to an unexisting document", (done) ->
            @client.sendFile "data/123/attachments/", "./test/test.png", \
                            (err, res, body) =>
                console.log err if err
                @response = res
                done()

        it "Then I got a 404 response", ->
            @response.statusCode.should.equal 404

        it "When I post an attachment", (done) ->
            @client.sendFile "data/321/attachments/", "./test/test.png", \
                            (err, res, body) =>
                console.log err if err
                @response = res
                done()

        it "Then I got a success response", ->
            @response.statusCode.should.equal 201

        it "And the file doesn't stay in the ./tmp folder", ->
            files = fs.readdirSync('/tmp')
            @nbOfFileInTmpFolder.should.equal files.length

    describe "Retrieve an attachment", ->

        it "When I claim this attachment", (done) ->
            @client = new Client("http://localhost:8888/")
            @client.setBasicAuth "home", "token"
            @client.saveFile "data/321/attachments/test.png", \
                             './test/test-get.png', -> done()

        it "I got the same file I attached before", ->
            fileStats = fs.statSync('./test/test.png')
            resultStats = fs.statSync('./test/test-get.png')

            resultStats.size.should.equal fileStats.size

    describe "Remove an attachment", ->

        it "When I remove this attachment", (done) ->
            delete @response
            @client.del 'data/321/attachments/test.png', (err, res) =>
                @response = res
                done()

        it "Then I have a success response", ->
            @response.statusCode.should.equal 204

        it "When I claim this attachment", (done) ->
            delete @response
            @client.get 'data/321/attachments/test.png', (err, res, body) =>
                @response = res
                done()

        it "I got a 404 response", ->
            @response.statusCode.should.equal 404
