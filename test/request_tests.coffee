should = require('chai').Should()
async = require('async')
Client = require('request-json').JsonClient
app = require('../server')

client = new Client("http://localhost:8888/")

# connection to DB for "hand work"
cradle = require 'cradle'
connection = new cradle.Connection
    cache: false,
    raw: false
db = connection.database('cozy')

# helpers

cleanRequest = ->
    delete @body
    delete @response


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



    describe "View creation", ->
        describe "Creation of the first view + design document creation", ->
            before cleanRequest

            it "When I send a request to create view every_docs", (done) ->
                map = (doc) ->
                    emit doc._id, doc
                    return
                @viewAll = {map:map.toString()}

                client.put 'request/every_docs/', @viewAll, \
                        (error, response, body) =>
                    response.statusCode.should.equal 200
                    done()
            
            it "Then the design document should exist and contain the view", \
                    (done) ->
                db.get '_design/cozy-request', (err, res) ->
                    should.not.exist err
                    should.exist res
                    res.views.should.have.property 'every_docs', @viewAll
                    done()

        describe "Creation of a new view", ->
            before cleanRequest

            it "When I send a request to create view even_num", (done) ->
                map = (doc) ->
                    emit doc._id, doc if (doc.num? && (doc.num % 2) is 0)
                    return
                @viewEven = {map:map.toString()}

                client.put 'request/even_num/', @viewEven, \
                        (error, response, body) =>
                    response.statusCode.should.equal 200
                    done()

            it "Then the design document should exist and contain the views", \
                    (done) ->
                db.get '_design/cozy-request', (err, res) ->
                    should.not.exist err
                    should.exist res
                    res.views.should.have.property 'every_docs', @viewAll
                    res.views.should.have.property 'even_num', @viewEven
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

        describe "Access to an existing view : every_docs", (done) ->
            before cleanRequest

            it "When I send a request to access view every_docs", (done) ->
                client.get "request/every_docs/", (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 101 documents returned", ->
                @body.should.have.length 101

        describe "Access to an existing view : even_num", (done) ->
            before cleanRequest

            it "When I send a request to access view every_docs", (done) ->
                client.get "request/even_num/", (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 51 documents returned", ->
                @body.should.have.length 51

    describe "Update of an existing view", ->
        describe "Redefinition of existing view even_num", ->
            before cleanRequest

            it "When I send a request to create view even_num", (done) ->
                map = (doc) ->
                    emit doc._id, doc if (doc.num? && (doc.num % 2) isnt 0)
                    return
                @viewEven = {map:map.toString()}

                client.put 'request/even_num/', @viewEven, \
                        (error, response, body) =>
                    response.statusCode.should.equal 200
                    done()

            it "Then the design document should exist and contain the views", \
                    (done) ->
                db.get '_design/cozy-request', (err, res) ->
                    should.not.exist err
                    should.exist res
                    res.views.should.have.property 'every_docs', @viewAll
                    res.views.should.have.property 'even_num', @viewEven
                    done()

            it "And I should retrieve the good values", (done) ->
                client.get "request/even_num/", (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    @body.should.have.length 50
                    done()
                    
    describe "Deletion of an existing view", ->
        before cleanRequest

        it "When I send a request to delete view even_num", (done) ->
            client.del "request/even_num/", (error, response, body) =>
                    response.statusCode.should.equal 204

        it "And I send a request to access view even_num", (done) ->
            client.get "request/even_num", (error, response, body) =>
                @response = response
                done()

        it "Then error 404 should be returned", ->
            @response.statusCode.should.equal 404


