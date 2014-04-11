should = require('chai').Should()
helpers = require './helpers'

axon = require 'axon'
db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()

client = helpers.getClient()

describe "Feed tests", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    # Start application before starting tests.
    before helpers.startApp

    before (done) ->
        @subscriber = new helpers.Subscriber()
        @axonSock = axon.socket 'sub-emitter'
        @axonSock.on 'note.*', @subscriber.listener
        @axonSock.connect helpers.options.axonPort, done

    # Stop application after finishing tests.

    after ->
        @axonSock.close()
        @axonSock = null

    after helpers.stopApp

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

        describe "Delete data", ->

            it "When I send a request to delete typed document", (done) ->
                client.del "data/#{@idT}/", (error, response, body) =>
                    console.log error if error
                    response.statusCode.should.equal 204

                @subscriber.wait done

             it "Then I receive a note.delete on my subscriber", ->
                @subscriber.haveBeenCalled('delete', @idT).should.be.ok

        describe "Destroy request", ->

            before (done) ->
                map = (doc) ->
                    if (doc.docType? && doc.docType is "Note")
                        emit ["test", doc.num, doc.num], doc
                    return
                view = map: map.toString()

                client.put "request/note/all/", view, done

            it "When I create three notes ", (done) ->
                note1 =
                    title: "note1"
                    content: "content Changed"
                    docType: "Note"
                note2 = note1
                note2.title = "note2"
                note3 = note1
                note3.title = "note3"

                client.post "data/", note1, (error, response, body) =>
                    @id1 = body._id
                    console.log error if error
                    client.post "data/", note2, (error, response, body) =>
                        @id2 = body._id
                        console.log error if error
                        client.post "data/", note3, (error, response, body) =>
                            @id3 = body._id
                            console.log error if error
                            done()

            it "And I send a request to delete all notes (with request)", (done) ->
                client.put "request/note/all/destroy/", "", (error, response, body) =>
                    console.log error if error
                    response.statusCode.should.equal 204
                    done()

            it "Then I receive three note.delete on my subscriber", () ->
                @subscriber.wait () =>
                    @subscriber.haveBeenCalled('delete', @id1).should.be.ok
                    @subscriber.haveBeenCalled('delete', @id2).should.be.ok
                    @subscriber.haveBeenCalled('delete', @id3).should.be.ok
               