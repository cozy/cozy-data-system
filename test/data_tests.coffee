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

describe "Data handling tests", ->

    # Clear DB, create a new one, then init data for tests.
    before (done) ->
        db.destroy ->
            db.create ->
                db.save '321', value:"val", done

    before helpers.instantiateApp

    after helpers.closeApp

    after (done) ->
        db.destroy ->
            db.create (err) ->
                console.log err if err
                done()


    describe "Existence", ->
        describe "Check Existence of a doc that does not exist in database", ->
            before cleanRequest

        it "When I send a request to check existence of Document with id 123", \
                (done) ->
            client.get "data/exist/123/", (error, response, body) =>
                response.statusCode.should.equal 200
                @body = body
                done()

        it "Then {exist: false} should be returned", ->
            should.exist @body.exist
            @body.exist.should.not.be.ok

    describe "Check Existence of a Document that does exist in database", ->
        before cleanRequest

        it "When I send a request to check existence of Document with id 321", \
                (done) ->
            client.get "data/exist/321/", (error, response, body) =>
                response.statusCode.should.equal 200
                @body = body
                done()

        it "Then {exist: true} should be returned", ->
            should.exist @body.exist
            @body.exist.should.be.ok



    describe "Find", ->
        describe "Find a Document that does not exist in database", ->
            before cleanRequest

            it "When I send a request to get Document with id 123", (done) ->
                client.get "data/123/", (error, response, body) =>
                    @response = response
                    done()

            it "Then error 404 should be returned", ->
                @response.statusCode.should.equal 404

        describe "Find a Document that does exist in database", ->
            before cleanRequest

            it "When I send a request to get Document with id 321", (done) ->
                client.get 'data/321/', (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then { _id: '321', value: 'val'} should be returned", ->
                @body.should.deep.equal {"_id": '321', "value":"val"}



    describe "Create", ->
        describe "Try to Create a Document existing in Database", ->
            before cleanRequest
            after ->
                delete @randomValue

            it "When I send a request to create a doc with id 321", (done) ->
                @randomValue = randomString()
                client.post 'data/321/', {"value":@randomValue}, \
                            (error, response, body) =>
                    @response = response
                    done()

            it "Then error 409 should be returned", ->
                @response.statusCode.should.equal 409

        describe "Create a new Document with a given id", ->
            before cleanRequest
            after ->
                delete @randomValue

            it "When I send a request to create a doc with id 987", (done) ->
                @randomValue = randomString()
                client.post 'data/987/', {"value":@randomValue}, \
                            (error, response, body) =>
                    response.statusCode.should.equal 201
                    @body = body
                    done()

            it "Then { _id: '987' } should be returned", ->
                @body.should.have.property '_id', '987'

            it "Then the doc with id 987 should exist in Database", (done) ->
                client.get "data/exist/987/", (error, response, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "Then the doc in DB should equal the sent Document", (done) ->
                client.get "data/987/", (error, response, body) =>
                    @body = body
                    @body.should.have.property 'value', @randomValue
                    done()

        describe "Create a new Document without an id", ->
            before cleanRequest
            after ->
                delete @randomValue
                delete @_id

            it "When I send a request to create a doc without an id", (done) ->
                @randomValue = randomString()
                client.post 'data/', {"value":@randomValue}, \
                            (error, response, body) =>
                    response.statusCode.should.equal 201
                    @body = body
                    done()

            it "Then the id of the new Document should be returned", ->
                @body.should.have.property '_id'
                @_id = @body._id

            it "Then the Document should exist in Database", (done) ->
                client.get "data/exist/#{@_id}/", (error, response, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "Then the Document in DB should equal the sent doc", (done) ->
                client.get "data/" + @_id + "/", (error, response, body) =>
                    @body = body
                    @body.should.have.property 'value', @randomValue
                    done()



    describe "Update", ->
        describe "Try to Update a Document that doesn't exist", ->
            before cleanRequest

            it "When I send a request to update a doc with id 123", (done) ->
                client.put 'data/123/', {"value":"created_value"}, \
                            (error, response, body) =>
                    @response = response
                    done()

            it "Then error 404 should be returned", ->
                @response.statusCode.should.equal 404

        describe "Update a modified Document in DB (concurrent access)", ->
            before cleanRequest

        describe "Update a Document (no concurrent access)", ->
            before cleanRequest
            after ->
                delete @randomValue

            it "When I send a request to update Document with id 987", (done) ->
                @randomValue = randomString()
                client.put 'data/987/', {"new_value":@randomValue}, \
                            (error, response, body) =>
                    @response = response
                    done()

            it "Then HTTP status 200 should be returned", ->
                @response.statusCode.should.equal 200

            it "Then the Document should exist in DataBase", (done) ->
                client.get "data/exist/987/", (error, response, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "Then the old Document must have been replaced", (done) ->
                client.get "data/987/", (error, response, body) =>
                    @body = body
                    @body.should.not.have.property 'value'
                    @body.should.have.property 'new_value', @randomValue
                    done()



    describe "Upsert", ->
        describe "Upsert a Document that is not in the Database", ->
            before cleanRequest
            after ->
                delete @randomValue

            it "When I send a request to upsert Document with id 654", (done) ->
                @randomValue = randomString()
                client.put 'data/upsert/654/', {"value":@randomValue}, \
                            (error, response, body) =>
                    response.statusCode.should.equal 201
                    @body = body
                    done()

            it "Then { _id: '654' } should be returned", ->
                @body.should.have.property '_id', '654'

            it "Then the doc with id 654 should exist in Database", (done) ->
                client.get "data/exist/654/", (error, response, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "Then the doc in DB should equal the sent Document", (done) ->
                client.get "data/654/", (error, response, body) =>
                    @body = body
                    @body.should.have.property 'value', @randomValue
                    done()

        describe "Upsert an existing Document", ->
            before cleanRequest
            after ->
                delete @randomValue

            it "When I send a request to upsert Document with id 654", (done) ->
                @randomValue = randomString()
                client.put 'data/upsert/654/', {"new_value":@randomValue}, \
                            (error, response, body) =>
                    @response = response
                    done()

            it "Then HTTP status 200 should be returned", ->
                @response.statusCode.should.equal 200

            it "Then the Document should exist in DataBase", (done) ->
                client.get "data/exist/654/", (error, response, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "Then the old Document must have been replaced", (done) ->
                client.get "data/654/", (error, response, body) =>
                    @body = body
                    @body.should.not.have.property 'value'
                    @body.should.have.property 'new_value', @randomValue
                    done()



    describe "Delete", ->
        describe "Delete a document that is not in Database", ->
            before cleanRequest

            it "When I send a request to delete Document with id 123", (done) ->
                client.del "data/123/", (error, response, body) =>
                    @response = response
                    done()

            it "Then HTTP status 404 should be returned", ->
                @response.statusCode.should.equal 404

        describe "Delete a document that is in Database", ->
            before cleanRequest

            it "When I send a request to delete Document with id 654", (done) ->
                client.del "data/654/", (error, response, body) =>
                    @response = response
                    done()

            it "Then HTTP status 204 should be returned", ->
                @response.statusCode.should.equal 204

            it "Then doc with id 654 shouldn't exist in Database", (done) ->
                client.get 'data/exist/654/', (error, response, body) =>
                    @body = body
                    @body.exist.should.be.false
                    done()



    describe "Merge", ->
        describe "Try to Merge a field of a non-existing Document", ->
            before cleanRequest

            it "When I send a request to merge with doc with id 123", (done) ->
                client.put 'data/merge/123/', {"new_field":"created_value"}, \
                            (error, response, body) =>
                    @response = response
                    done()

            it "Then HTTP status 404 should be returned", ->
                @response.statusCode.should.equal 404

        describe "Try to Merge a new field of an existing Document", ->
            before cleanRequest
            after ->
                delete @randomValue

            it "When I send a request to merge with doc with id 987", (done) ->
                @randomValue = randomString()
                client.put 'data/merge/987/', {"new_field":@randomValue}, \
                            (error, response, body) =>
                    @response = response
                    done()

            it "Then HTTP status 200 should be returned", ->
                @response.statusCode.should.equal 200

            it "Then the Document should exist in DataBase", (done) ->
                client.get "data/exist/987/", (error, response, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "Then the old/new field should be in the Document", (done) ->
                client.get "data/987/", (error, response, body) =>
                    @body = body
                    @body.should.have.property 'new_value'
                    @body.should.have.property 'new_field', @randomValue
                    done()

        describe "Try to Merge an existing field of an existing Document", ->
            before cleanRequest
            after ->
                delete @randomValue

            it "When I send a request to merge with doc with id 987", (done) ->
                @randomValue = randomString()
                client.put 'data/merge/987/', {"new_value":@randomValue}, \
                            (error, response, body) =>
                    @response = response
                    done()

            it "Then HTTP status 200 should be returned", ->
                @response.statusCode.should.equal 200

            it "Then the Document should exist in DataBase", (done) ->
                client.get "data/exist/987/", (error, response, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "Then the old field has been changed in the doc", (done) ->
                client.get "data/987/", (error, response, body) =>
                    @body = body
                    @body.should.have.property 'new_value', @randomValue
                    @body.should.have.property 'new_field'
                    done()

                it "When I send a request to create a doc with no id", (done) ->
                    @randomValue = randomString()
                    client.post 'data/', {"value":@randomValue}, \
                                (error, response, body) =>
                        response.statusCode.should.equal 201
                        @body = body
                        done()

                it "Then the id of the new Document should be returned", ->
                    @body.should.have.property '_id'
                    @_id = @body._id

                it "Then the Document should exist in Database", (done) ->
                    client.get "data/exist/#{@_id}/", (error, response, body) =>
                        @body = body
                        @body.exist.should.be.true
                        done()

                it "Then the doc in DB should equal the sent doc", (done) ->
                    client.get "data/#{@_id}/", (error, response, body) =>
                        @body = body
                        @body.should.have.property 'value', @randomValue
                        done()



        describe "Update", ->
            describe "Try to Update a Document that doesn't exist", ->
                before cleanRequest

                it "When I send a req to update a doc with id 123", (done) ->
                    client.put 'data/123/', {"value":"created_value"}, \
                                (error, response, body) =>
                        @response = response
                        done()

                it "Then error 404 should be returned", ->
                    @response.statusCode.should.equal 404

            describe "Update a modified Document in DB (concurrent access)", ->
                before cleanRequest

            describe "Update a Document (no concurrent access)", ->
                before cleanRequest
                after ->
                    delete @randomValue

                it "When I send a request to update doc with id 987", (done) ->
                    @randomValue = randomString()
                    client.put 'data/987/', {"new_value":@randomValue}, \
                                (error, response, body) =>
                        @response = response
                        done()

                it "Then HTTP status 200 should be returned", ->
                    @response.statusCode.should.equal 200

                it "Then the Document should exist in DataBase", (done) ->
                    client.get "data/exist/987/", (error, response, body) =>
                        @body = body
                        @body.exist.should.be.true
                        done()

                it "Then the old Document must have been replaced", (done) ->
                    client.get "data/987/", (error, response, body) =>
                        @body = body
                        @body.should.not.have.property 'value'
                        @body.should.have.property 'new_value', @randomValue
                        done()



        describe "Upsert", ->
            describe "Upsert a Document that is not in the Database", ->
                before cleanRequest
                after ->
                    delete @randomValue

                it "When I send a request to upsert doc with id 654", (done) ->
                    @randomValue = randomString()
                    client.put 'data/upsert/654/', {"value":@randomValue}, \
                                (error, response, body) =>
                        response.statusCode.should.equal 201
                        @body = body
                        done()

                it "Then { _id: '654' } should be returned", ->
                    @body.should.have.property '_id', '654'

                it "Then the doc with id 654 should exist in db", (done) ->
                    client.get "data/exist/654/", (error, response, body) =>
                        @body = body
                        @body.exist.should.be.true
                        done()

                it "Then the doc in DB should equal the sent doc", (done) ->
                    client.get "data/654/", (error, response, body) =>
                        @body = body
                        @body.should.have.property 'value', @randomValue
                        done()

            describe "Upsert an existing Document", ->
                before cleanRequest
                after ->
                    delete @randomValue

                it "When I send a request to upsert doc with id 654", (done) ->
                    @randomValue = randomString()
                    client.put 'data/upsert/654/', {"new_value":@randomValue}, \
                                (error, response, body) =>
                        @response = response
                        done()

                it "Then HTTP status 200 should be returned", ->
                    @response.statusCode.should.equal 200

                it "Then the Document should exist in DataBase", (done) ->
                    client.get "data/exist/654/", (error, response, body) =>
                        @body = body
                        @body.exist.should.be.true
                        done()

                it "Then the old Document must have been replaced", (done) ->
                    client.get "data/654/", (error, response, body) =>
                        @body = body
                        @body.should.not.have.property 'value'
                        @body.should.have.property 'new_value', @randomValue
                        done()



        describe "Delete", ->
            describe "Delete a document that is not in Database", ->
                before cleanRequest

                it "When I send a request to delete doc with id 123", (done) ->
                    client.del "data/123/", (error, response, body) =>
                        @response = response
                        done()

                it "Then HTTP status 404 should be returned", ->
                    @response.statusCode.should.equal 404

            describe "Delete a document that is in Database", ->
                before cleanRequest

                it "When I send a request to delete doc with id 654", (done) ->
                    client.del "data/654/", (error, response, body) =>
                        @response = response
                        done()

                it "Then HTTP status 204 should be returned", ->
                    @response.statusCode.should.equal 204

                it "Then doc with id 654 shouldn't exist in Database", (done) ->
                    client.get 'data/exist/654/', (error, response, body) =>
                        @body = body
                        @body.exist.should.be.false
                        done()



        describe "Merge", ->
            describe "Try to Merge a field of a non-existing Document", ->
                before cleanRequest

                it "When I send a req to merge with doc with id 123", (done) ->
                    data = "new_field":"created_value"
                    client.put 'data/merge/123/', data, \
                                (error, response, body) =>
                        @response = response
                        done()

                it "Then HTTP status 404 should be returned", ->
                    @response.statusCode.should.equal 404

            describe "Try to Merge a new field of an existing Document", ->
                before cleanRequest
                after ->
                    delete @randomValue

                it "When I send a req to merge with doc with id 987", (done) ->
                    @randomValue = randomString()
                    client.put 'data/merge/987/', {"new_field":@randomValue}, \
                                (error, response, body) =>
                        @response = response
                        done()

                it "Then HTTP status 200 should be returned", ->
                    @response.statusCode.should.equal 200

                it "Then the Document should exist in DataBase", (done) ->
                    client.get "data/exist/987/", (error, response, body) =>
                        @body = body
                        @body.exist.should.be.true
                        done()

                it "Then the old/new field should be in the Document", (done) ->
                    client.get "data/987/", (error, response, body) =>
                        @body = body
                        @body.should.have.property 'new_value'
                        @body.should.have.property 'new_field', @randomValue
                        done()

            describe "Try to Merge an existing field of an existing doc", ->
                before cleanRequest
                after ->
                    delete @randomValue

                it "When I send a req to merge with doc with id 987", (done) ->
                    @randomValue = randomString()
                    client.put 'data/merge/987/', {"new_value":@randomValue}, \
                                (error, response, body) =>
                        @response = response
                        done()

                it "Then HTTP status 200 should be returned", ->
                    @response.statusCode.should.equal 200

                it "Then the Document should exist in DataBase", (done) ->
                    client.get "data/exist/987/", (error, response, body) =>
                        @body = body
                        @body.exist.should.be.true
                        done()

                it "Then the old field has been changed in the doc", (done) ->
                    client.get "data/987/", (error, response, body) =>
                        @body = body
                        @body.should.have.property 'new_value', @randomValue
                        @body.should.have.property 'new_field'
                        done()
