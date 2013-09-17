should = require('chai').Should()
Client = require('request-json').JsonClient
helpers = require('./helpers')
client = new Client("http://localhost:8888/")

axon = require 'axon'
db = require('../helpers/db_connect_helper').db_connect()

describe "Feed tests", ->

    # Clear DB, create a new one, then init data for tests.
    before (done) ->
        db.destroy ->
            db.create done
    # Start application before starting tests.
    before helpers.instantiateApp

    before ->
        @subscriber = new helpers.Subscriber()
        @axonSock = axon.socket 'sub-emitter'
        @axonSock.on 'note.*', @subscriber.listener
        @axonSock.connect 9105

    # Stop application after finishing tests.

    after ->
        @axonSock.close()
        @axonSock = null

    after helpers.closeApp

    after (done)->
        db.destroy ->
            db.create done

    describe "Typed Create", ->

        it "When I send a request to create a Note-typed doc", (done) ->

            note =
                title: "title"
                content: "content"
                docType: "Note"

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