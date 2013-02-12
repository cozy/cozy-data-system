hould = require('chai').Should()
async = require('async')
Client = require('request-json').JsonClient
app = require('../server')
crypto = require('../lib/crypto.coffee')


client = new Client("http://localhost:8888/")

# connection to DB for "hand work"
db = require('../helpers/db_connect_helper').db_connect()

# helpers

cleanRequest = ->
    delete @body
    delete @response

randomString = (length=8) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

describe "Account handling tests", ->

    # Clear DB, create a new one, then init data for tests.
    before (done) ->
        db.destroy ->
            db.create ->
                    done()

    # Start application before starting tests.
    before (done) ->
        app.listen(8888)
        done()

    # Stop application after finishing tests.
    after (done) ->
        app.close()
        done()



    describe "Master key handling tests", ->
        describe "master key initialization", ->
            before cleanRequest

        it "When I send a request to check initialization of the master key", \
                (done) ->
            @randomValue = randomString()
            client.post '/accounts/password/', {"value":@randomValue}, \
                        (error, response, body) =>
                @response = response
                done()

        it "Then HTTP status 201 should be returned", ->
                @response.statusCode.should.equal(201)

        it "Then the object 'User' have an initialized salt", (done) ->
            map = (doc) ->
                emit doc.salt, doc if doc.docType == 'User'
                return
            @salt = ""
            @salt.length.should.equal(24) #masterKey.length - @randomValue.length

        it "Then master key should be initialized", (done) ->
            masterKey = app.crypto.genHashWithSalt(@randomValue, @salt)
            app.crypto.masterKey.should.equal(masterKey)


        describe "master key deleting", ->
            before cleanRequest

        it "When I send a request to delete the master key", (done) ->
            client.delete '/accounts/', (error, response, body) =>
            done()

        it "Then HTTP status 204 should be returned", ->
        	@response.statusCOde.should.equal(204)

        it "Then master key should be undefined", ->
            app.crypto.masterKey.should.equal("") # 'should.equal undefined' n'existe pas

    describe "Operation of cryptography", ->
        describe "When I encrypt a random value", ->

        it "Then encrypted data should not be equal to random value", ->
            @randomValue = randomString()
            @key = randomString(32)
            @crypted = app.crypto.encrypt(@key, @randomValue)
            @crypted.should.not.equal(@randomValue)


        it "Then decrypted data should be equal to random value", ->
            @decrypted = app.crypto.decrypt(@key, @crypted)
            @decrypted.should.equal(@randomValue)