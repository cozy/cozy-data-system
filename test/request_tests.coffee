should = require('chai').Should()
async = require('async')
Client = require('../common/test/client').Client
app = require('../server')

client = new Client("http://localhost:8888/")

# connection to DB for "hand work"
cradle = require 'cradle'
connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database('cozy')

# helpers

cleanRequest = ->
    delete @body
    delete @response

parseBody = (response, body) ->
    if typeof body is "object" then body else JSON.parse body

randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

describe "Request handling tests", ->

    # Clear DB, create a new one, then init data for tests.
    before (done) ->
        db.destroy ->
            console.log 'DB destroyed'
            db.create ->
                console.log 'DB recreated'
                docs = ({'type':'dumb_doc', 'num':num} for num in [0..100])
                map_no_doc = (doc) ->
                map_every_docs = (doc) ->
                    emit doc._id, null
                    return

                views = {no_doc:{map:map_no_doc}, \
                        every_docs:{map:map_every_docs}}

                db.save "_design/cozy-request", views, ->
                    db.save docs, ->
                        done()

    # Start application before starting tests.
    before (done) ->
        app.listen(8888)
        done()

    # Stop application after finishing tests.
    after (done) ->
        app.close()
        done()



    describe "Access to a view without option", ->
        describe "Access to a non existing view", ->
            before cleanRequest

            it "When I send a request to access view dont-exist", (done) ->
                client.get "request/dont-exist", (error, response, body) =>
                    @response = response
                    done()

            it "Then error 404 should be returned", ->
                @response.statusCode.should.equal 404
        
        describe "Access to an existing view : no_doc", ->
            before cleanRequest

            it "When I send a request to access view no_doc", (done) ->
                client.get "request/no_doc/", (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = parseBody response, body
                    done()

            it "Then I should have no document returned", ->
                @body.should.be.empty

        describe "Access to an existing view : every_docs", (done) ->
            before cleanRequest

            it "When I send a request to access view every_docs", (done) ->
                client.get "request/every_docs/", (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = parseBody response, body
                    done()

            it "Then I should have 101 documents returned", ->
                @body.should.have.length 101

    describe "View creation or update", ->
        describe "Creation of a new view", ->
            before cleanRequest

            it "When I send a request to create view even_num", (done) ->
                map = (doc) ->
                    emit doc._id, null if (doc.num && (doc.num % 2) is 0)
                view = {map:map}

                client.put '/request/even_num/', view, \
                        (error, response, body) =>
                    response.statusCode.should.equal 200
                    done()

            it "Then this view should be accessible", (done) ->
                client.get '/request/even_num/', (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = parseBody response, body
                    done()

            it "And the other views should still exist", (done) ->
                db.get '_design/cozy-request', (err, res) ->
                    should.not.exist err
                    res.views.should.have.property 'every_docs'
                    res.views.should.have.property 'no_doc'
                    done()

            it "And I should retrieve 51 documents with even num", ->
                @body.should.have.length 51
                @body.forEach (doc) ->
                    expect(doc.num % 2).to.equal 0

        describe "Update of an existing view", ->
            before cleanRequest
