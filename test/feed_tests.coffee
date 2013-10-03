should = require('chai').Should()
Client = require('request-json').JsonClient
helpers = require('./helpers')
client = new Client("http://localhost:8888/")

axon = require 'axon'
db = require('../helpers/db_connect_helper').db_connect()

describe "Feed tests", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    # Start application before starting tests.
    before helpers.instantiateApp

    before (done) ->
        @subscriber = new helpers.Subscriber()
        @axonSock = axon.socket 'sub-emitter'
        @axonSock.on 'note.*', @subscriber.listener
        @axonSock.connect 9105, done

    # Stop application after finishing tests.

    after ->
        @axonSock.close()
        @axonSock = null

    after helpers.after db

    describe "Install application which can manage note", ->

        it "When I send a request to post an application", (done) ->
            data =
                "name": "test"
                "slug": "test"
                "state": "installed"
                "password": "token"
                "permissions":
                    "Note":
                        "description": "This application needs ..."
                "docType": "Application"
            client.setBasicAuth "home", "token"
            client.post 'data/', data, (err, res, body) =>
                @body = body
                @err = err
                @res = res
                done()

        it "Then no error should be returned", ->
            should.equal  @err, null

        it "And HTTP status 201 should be returned", ->
            @res.statusCode.should.equal 201

    describe "Typed Create", ->

        it "When I send a request to create a Note-typed doc", (done) ->

            note =
                title: "title"
                content: "content"
                docType: "Note"
            client.setBasicAuth "test", "token"
            client.post "data/", note, (error, response, body) =>
                console.log error if error
                @idT = body['_id']

                @subscriber.wait done

        it "Then I receive a note.create on my subscriber", ->
            @subscriber.haveBeenCalled('create', @idT).should.be.ok

    describe "Typed Update", ->

        it "When I send a request to update a typed doc", (done) ->


            note =
                title: "title"
                content: "content Changed"
                docType: "Note"

            client.put "data/#{@idT}/", note, (error, response, body) =>
                console.log error if error

            @subscriber.wait done

        it "Then I receive a note.update on my subscriber", ->
            @subscriber.haveBeenCalled('update', @idT).should.be.ok

    describe "Typed Delete", ->

        it "When I send a request to delete typed document", (done) ->


            client.del "data/#{@idT}/", (error, response, body) =>
                console.log error if error
                response.statusCode.should.equal 204

            @subscriber.wait done

         it "Then I receive a note.delete on my subscriber", ->
            @subscriber.haveBeenCalled('delete', @idT).should.be.ok
