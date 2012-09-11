should = require('chai').Should()
async = require 'async'
app = require '../server'
fs = require 'fs'

FormData = require 'form-data'
request = require "request"


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
        app.listen(8888)
        done()

    
    describe "Add an attachment", ->
        
        it "When I post an attachment to an unexisting document", (done) ->
            form = new FormData
            form.append 'file', fs.createReadStream("./test/test.png")
            form.submit "http://localhost:8888/data/123/attachments/", (err, res) =>
                console.log err if err
                @response = res
                done()

        it "Then I got a 404 response", ->
            @response.statusCode.should.equal 404
        
        it "When I post an attachment", (done) ->
            form = new FormData
            form.append 'file', fs.createReadStream("./test/test.png")
            form.submit "http://localhost:8888/data/321/attachments/", (err, res) =>
                console.log err if err
                @response = res
                done()
            
        it "Then I got a success response", ->
            @response.statusCode.should.equal 201

    describe "Retrieve an attachment", ->

        it "When I claim this attachment", (done) ->
            stream = request('http://localhost:8888/data/321/attachments/test.png', -> done())
            stream.pipe fs.createWriteStream('./test/test-get.png')

        it "I got the same file I attached before", ->
            fileStats = fs.statSync('./test/test.png')
            resultStats = fs.statSync('./test/test-get.png')
            
            resultStats.size.should.equal fileStats.size

    describe "Remove an attachment", ->

        it "When I remove this attachment", (done) ->
            delete @response
            request.del 'http://localhost:8888/data/321/attachments/test.png', \
                        (err, res) =>
                @response = res
                done()

        it "Then I have a success response", ->
            @response.statusCode.should.equal 204

        it "When I claim this attachment", (done) ->
            delete @response
            request 'http://localhost:8888/data/321/attachments/test.png', \
                    (err, res, body) =>
                @response = res
                done()

        it "I got a 404 response", ->
            @response.statusCode.should.equal 404

