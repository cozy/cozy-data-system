should = require('chai').Should()
Client = require('request-json').JsonClient
helpers = require('./helpers')
client = new Client("http://localhost:8888/")

redis = require('redis').createClient()


describe "Feed tests", ->

    # Start application before starting tests.
    before helpers.instantiateApp

    before ->
        @subscriber = new helpers.Subscriber()
        redis.on 'pmessage', @subscriber.listener
        redis.psubscribe '*'

    # Stop application after finishing tests.
    
    after helpers.closeApp

    after ->
        redis.removeAllListeners 'pmessage'
        redis.unsubscribe()

    describe "Create", ->
            
        it "When I send a request to create a doc", (done) ->
                
            @subscriber.wait done

            doc = value : helpers.randomString()

            client.post 'data/', doc, (error, response, body) =>
                console.log error if error
                response.statusCode.should.equal 201
                @id = body['_id']

        it "Then I receive a null.create on my subscriber", ->
            @subscriber.haveBeenCalled('null.create', @id).should.be.ok
                

    describe "Update", ->

        it "When I send a request to update Document", (done) ->
            
            @subscriber.wait done

            doc = new_value : helpers.randomString()
            
            client.put "data/#{@id}/", doc, (error, response, body) =>
                console.log error if error
                response.statusCode.should.equal 200

         it "Then I receive a null.update on my subscriber", ->
            @subscriber.haveBeenCalled('null.update', @id).should.be.ok


    describe "Delete", ->
        
        it "When I send a request to delete Document", (done) ->
            
            @subscriber.wait done
            
            client.del "data/#{@id}/", (error, response, body) =>
                console.log error if error
                response.statusCode.should.equal 204

            
         it "Then I receive a delete on my subscriber", ->
            @subscriber.haveBeenCalled('delete', @id).should.be.ok

    describe "Typed Create", ->
            
        it "When I send a request to create a Note-typed doc", (done) ->
            
            @subscriber.wait done

            note =
                title: "title"
                content: "content"
                docType: "Note"

            client.post "data/", note, (error, response, body) =>
                console.log error if error
                @idT = body['_id']

        it "Then I receive a note.create on my subscriber", ->
            @subscriber.haveBeenCalled('note.create', @idT).should.be.ok

    describe "Typed Update", ->
            
        it "When I send a request to update a typed doc", (done) ->

            @subscriber.wait done

            note =
                title: "title"
                content: "content Changed"
                docType: "Note"

            client.put "data/#{@idT}/", note, (error, response, body) =>
                console.log error if error

        it "Then I receive a note.update on my subscriber", ->
            @subscriber.haveBeenCalled('note.update', @idT).should.be.ok

    describe "Typed Delete", ->
        
        it "When I send a request to delete typed document", (done) ->
            
            @subscriber.wait done
            
            client.del "data/#{@idT}/", (error, response, body) =>
                console.log error if error
                response.statusCode.should.equal 204

            
         it "Then I receive a delete and a note.delete on my subscriber", ->
            @subscriber.haveBeenCalled('delete', @idT).should.be.ok
            @subscriber.haveBeenCalled('note.delete', @idT).should.be.ok