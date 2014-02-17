should = require('chai').Should()
fs = require 'fs'
Client = require('request-json').JsonClient
helpers = require './helpers'

# connection to DB for "hand work"
db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()

serverUrl = "http://#{helpers.options.serverHost}:#{helpers.options.serverPort}/"

process.env.TOKEN = "token"

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

        it "I got the same file I attached before", ->
            fileStats = fs.statSync './tests/fixtures/test.png'
            resultStats = fs.statSync './tests/fixtures/test-get.png'
            resultStats.size.should.equal fileStats.size

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
