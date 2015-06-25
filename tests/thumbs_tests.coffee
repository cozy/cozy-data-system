should = require('chai').Should()
fs = require 'fs'
Client = require('request-json').JsonClient
helpers = require './helpers'

# connection to DB for "hand work"
db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()

serverUrl = "http://#{helpers.options.serverHost}:#{helpers.options.serverPort}/"

describe "Thumbs", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db

    before helpers.startApp

    # Start application before starting tests.
    before (done) ->
        @client = new Client serverUrl
        @client.setBasicAuth "home", "token"
        files = fs.readdirSync '/tmp'
        @nbOfFileInTmpFolder = files.length
        app =
            "name": "test"
            "slug": "test"
            "state": "installed"
            "password": "secret"
            "permissions":
                "All":
                    "description": "This application needs manage binary because ..."
            "docType": "Application"
        @client.post 'access/', app, (err, res, doc) =>
            @client.setBasicAuth 'test', 'secret'
            done()

    after helpers.stopApp

    describe "Thumb creation", ->

        it "When I post a file (without thumb)", (done) ->
            file = 
                "docType": "File"
                "name": "test.png"
                "class": 'image'
                "path": ""
            @client.post 'data/111/', file, (err, res, doc) =>
                @id = doc._id
                @client.sendFile "data/#{doc._id}/binaries/", "./tests/fixtures/test.png", \
                                name: "file", (err, res, body) =>
                    @err = err
                    @response = res
                    @body = body
                    done()

        it "Then I got a 201 response", ->
            @response.statusCode.should.equal 201
            should.not.exist @err

        it "And file has a file defined in binary field", (done)->
            @client.get "data/#{@id}/", (err, res, file) ->
                should.exist file.binary
                should.exist file.binary.file
                done()

        it "And after 5 seconds file has a thumb and a screen defined in binary field", (done)->
            @timeout 10 * 1000
            setTimeout () =>
                @client.get "data/#{@id}/", (err, res, file) =>
                    should.exist file.binary
                    should.exist file.binary.file
                    should.exist file.binary.thumb
                    should.exist file.binary.screen
                    done()
            , 5 * 1000

        it "And thumb corresponds to thumb file", (done) ->
            dstPath = 'thumb.png'
            writeStream = fs.createWriteStream dstPath
            stream = @client.get "data/#{@id}/binaries/thumb", (err, res) ->
                resultStats = fs.statSync dstPath
                expectedStats = fs.statSync "./tests/fixtures/thumb.png"
                resultStats.size.should.equal expectedStats.size
                fs.unlink dstPath, (err) ->
                    done()
            stream.pipe writeStream

        it "And thumb corresponds to screen file", (done) ->
            dstPath = 'screen.png'
            writeStream = fs.createWriteStream dstPath
            stream = @client.get "data/#{@id}/binaries/screen", (err, res) ->
                resultStats = fs.statSync dstPath
                expectedStats = fs.statSync "./tests/fixtures/screen.png"
                resultStats.size.should.equal expectedStats.size
                fs.unlink dstPath, (err) ->
                    done()
            stream.pipe writeStream

        it "And temporary thumb was deleted from temporary file", ->
            files = fs.readdirSync '/tmp'
            @nbOfFileInTmpFolder.should.equal files.length

    describe 'Thumb updating', ->

        it "When I post a file (without thumb)", (done) ->
            @client.sendFile "data/111/binaries/", "./tests/fixtures/bighappycloud.png", \
                            name: "file", (err, res, body) =>
                @err = err
                @response = res
                @body = body
                done()

        it "Then I got a 201 response", ->
            @response.statusCode.should.equal 201
            should.not.exist @err

        it "And file has a file defined in binary field", (done)->
            @client.get "data/111/", (err, res, file) ->
                should.exist file.binary
                should.exist file.binary.file
                done()

        it "And after 5 seconds file has a thumb and a screen defined in binary field", (done)->
            @timeout 10 * 1000
            setTimeout () =>
                @client.get "data/111/", (err, res, file) =>
                    should.exist file.binary
                    should.exist file.binary.file
                    should.exist file.binary.thumb
                    should.exist file.binary.screen
                    done()
            , 5 * 1000

        it "And thumb corresponds to thumb file", (done) ->
            dstPath = 'thumb.png'
            writeStream = fs.createWriteStream dstPath
            stream = @client.get "data/111/binaries/thumb", (err, res) ->
                resultStats = fs.statSync dstPath
                expectedStats = fs.statSync "./tests/fixtures/thumb-2.png"
                resultStats.size.should.equal expectedStats.size
                fs.unlink dstPath, (err) ->
                    done()
            stream.pipe writeStream

        it "And thumb corresponds to screen file", (done) ->
            dstPath = 'screen.png'
            writeStream = fs.createWriteStream dstPath
            stream = @client.get "data/111/binaries/screen", (err, res) ->
                resultStats = fs.statSync dstPath
                expectedStats = fs.statSync "./tests/fixtures/screen-2.png"
                resultStats.size.should.equal expectedStats.size
                fs.unlink dstPath, (err) ->
                    done()
            stream.pipe writeStream

        it "And temporary thumb was deleted from temporary file", ->
            files = fs.readdirSync '/tmp'
            @nbOfFileInTmpFolder.should.equal files.length

