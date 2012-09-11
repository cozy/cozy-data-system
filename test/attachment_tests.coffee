should = require('chai').Should()
async = require 'async'
app = require '../server'
fs = require 'fs'

FormData = require 'form-data'
request = require "request"

Client = require("request-json").JsonClient

# connection to DB for "hand work"
cradle = require 'cradle'
connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database('cozy')


describe "Attachments", ->

    # Clear DB, create a new one, then init data for tests.
    before (done) ->
        db.destroy ->
            console.log 'DB destroyed'
            db.create ->
                console.log 'DB recreated'
                db.save '321', {"value":"val"}, ->
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

