should = require('chai').Should()
fs = require 'fs'

Client = require("request-json").JsonClient

instantiateApp = require('..')

db = require('../helpers/db_connect_helper').db_connect()
app = instantiateApp()


describe "Attachments", ->

    # Clear DB, create a new one, then init data for tests.
    before (done) ->
        db.destroy ->
            db.create ->
                db.save '321', value: "val", ->
                    done()

    # Start application before starting tests.
    before (done) ->
        @client = new Client("http://localhost:8888/")
        app.listen(8888)
        done()

    
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

    describe "Retrieve an attachment", ->

        it "When I claim this attachment", (done) ->
            @client = new Client("http://localhost:8888/")
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
