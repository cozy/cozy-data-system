should = require('chai').Should()
async = require('async')
Client = require('request-json').JsonClient
helpers = require('./helpers')

client = new Client("http://localhost:8888/")
db = require('../helpers/db_connect_helper').db_connect()


# helpers

cleanRequest = ->
    delete @body
    delete @response

randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

describe "Doctype handling tests", ->

    # Clear DB, create a new one, then init data for tests.
    before (done) ->
        db.destroy ->
            db.create ->
                done()
    

    before helpers.instantiateApp

    after helpers.closeApp

    after (done)->
        db.destroy ->
            db.create ->
                done()

    describe "Create", ->
        describe "Create a Doctype in Database", ->
            before cleanRequest
            after ->
                delete @randomValue

            it "When I send a request to create a doc with id 321", (done) ->
                @randomValue = randomString()
                data = 
                    "name": @randomValue
                    "docType": "docType" 
                client.post 'doctype/321/', data, (error, response, body) =>
                    @response = response
                    @body = body
                    done()

            it "Then HTTP status 201 should be returned", ->
                @response.statusCode.should.equal 201

            it "And { _id: '321' } should be returned", ->
                @body.should.have.property '_id', '321'

            it "And the doc with id 321 should exist in database", (done) ->
                client.get "data/exist/321/", (error, response, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "And the document with id 321 in  database should be equal" +
                    " to the sent document", (done) ->
                client.get "data/321/", (error, response, body) =>    
                    body.should.have.property 'name', @randomValue 
                    body.should.have.property 'docType', "doctype"
                    done() 

     
        describe "Create a new Doctype without an id", ->
            before cleanRequest
            after ->
                delete @randomValue
                delete @_id

            it "When I send a request to create a doc without an id", (done) ->
                @randomValue = randomString()
                data = 
                    "name": @randomValue
                    "docType": "docType" 
                client.post 'doctype/', data, (error, response, body) =>
                    @response = response
                    @body = body
                    @body.should.have.property '_id'
                    @_id = @body._id
                    done()

            it "Then HTTP status 201 should be returned", ->
                @response.statusCode.should.equal 201

            it "And the doc should exist in database", (done) ->
                client.get "data/exist/"+ @_id + "/", (error, response, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "And the document in  database should be equal " +
                    "to the sent document", (done)->
                client.get "data/"+ @_id + "/", (error, response, body) =>    
                    body.should.have.property 'name', @randomValue 
                    body.should.have.property 'docType', "doctype" 
                    done()


        describe "Create a doctype without field 'docType' ", ->
            before cleanRequest
            after ->
                delete @randomValue

            it "When I send a request to create a doc with id 321", (done) ->
                @randomValue = randomString()
                client.post 'doctype/123/', {"name":@randomValue}, \
                            (error, response, body) =>
                    @response = response
                    done()

            it "Then HTTP status 201 should be returned", ->
                @response.statusCode.should.equal 201

            it "And the doc with id 321 should exist in database", (done) ->
                client.get "data/exist/123/", (error, response, body) =>
                    body.exist.should.be.true
                    done()

            it "And the name of the document in  database should be equal to " +
                    "the sent document", (done) ->
                client.get "data/123/", (error, response, body) => 
                    @body = body     
                    @body.should.have.property 'name', @randomValue 
                    done()

            it "And document has a field docType equals to 'docType", ->
                @body.should.have.property 'docType', "doctype"


        describe "Try to create a new Doctype without field name", ->
            before cleanRequest
            after ->
                delete @randomValue
                delete @_id

            it "When I send a request to create a doc without an id", (done) ->
                @randomValue = randomString()
                data = 
                    "docType": "docType" 
                client.post 'doctype/', data, (error, response, body) =>
                    @error = body.error
                    @response = response
                    done()


            it "Then error 409 should be returned", ->
                @response.statusCode.should.equal 409

            it "And error should be about field name", ->
                @error.should.be.equal "docType should be equal to 'docType' " +
                        "and field name are required"


        describe "Try to create a new Doctype with docType different than 'docType'",->
            before cleanRequest
            after ->
                delete @randomValue
                delete @_id

            it "When I send a request to create a doc without an id", (done) ->
                @randomValue = randomString()
                data = 
                    "name": @randomValue
                    "docType": "falseDocType" 
                client.post 'doctype/', data, (error, response, body) =>
                    @error = body.error
                    @response = response
                    done()

            it "Then error 409 should be returned", ->
                @response.statusCode.should.equal 409

            it "And error should be about docType", ->
                @error.should.be.equal "docType should be equal to 'docType' " +
                        "and field name are required"


        describe "Try to create a docType already created",->
            before cleanRequest
            after ->
                delete @randomValue
                delete @_id

            it "When I send a request to create a docType with name " + 
                    "'Application'", (done) ->
                @randomValue = randomString()
                data = 
                    "name": "Application"
                    "docType": "docType" 
                client.post 'doctype/', data, (error, response, body) =>
                    done()

            it "And I send a new request to create a docType with name " + 
                    "application'", (done) ->
                @randomValue = randomString()
                data = 
                    "name": "Application"
                    "docType": "docType" 
                client.post 'doctype/', data, (error, response, body) =>
                    @error = body.error
                    @response = response
                    done()

            it "Then error 409 should be returned", ->
                @response.statusCode.should.equal 409

            it "And error should be about docType", ->
                @error.should.be.equal "docType is already created"



    describe "Delete", ->
        describe "Delete a document that is not in Database", ->
            before cleanRequest

            it "When I send a request to delete Document with id 456", (done) ->
                client.del "doctype/456/", (error, response, body) =>
                    @response = response
                    done()

            it "Then HTTP status 404 should be returned", ->
                @response.statusCode.should.equal 404

        describe "Delete a document that is in Database", ->
            before cleanRequest

            it "When I send a request to delete Document with id 123", (done) ->
                client.del "doctype/123/", (error, response, body) =>
                    @response = response
                    done()

            it "Then HTTP status 204 should be returned", ->
                @response.statusCode.should.equal 204

            it "Then doc with id 123 shouldn't exist in Database", (done) ->
                client.get 'data/exist/123/', (error, response, body) =>
                    @body = body
                    @body.exist.should.be.false
                    done()

