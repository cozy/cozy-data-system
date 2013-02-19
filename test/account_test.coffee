should = require('chai').Should()
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



    describe "Initialize database with the object User : ", ->
        it "When I send the request", (done) -> 
            client.post 'data/102/', {email: "user@CozyCloud.CC", \
                    timezone: "Europe/Paris", password: "pwd_user", \
                    docType: "User"}, (error, response, body) =>
                done()



    describe "Master key handling tests : ", ->
        describe "master key initialization", ->
            before cleanRequest

        it "When I send a request to initialize of the master key", \
                (done) ->
            @randomValue = randomString()
            client.post 'accounts/password/', {pwd: @randomValue}, \
                    (error, response, body) =>
                @response = response
                done()

        it "Then the object 'User' have an initialized salt", (done)->
            client.get 'data/102/', (error, response, body) =>
                body.should.have.property 'salt'
                @salt = body.salt
                should.not.equal @salt, undefined
                @salt.length.should.equal 24
                done()

        it "Then master key should be initialized", ->
            @masterKey = app.crypto.genHashWithSalt(@randomValue, @salt)
            @masterKey.length.should.equal 32
            should.not.equal app.crypto.masterKey, null
            app.crypto.masterKey.should.equal @masterKey

        it "Then HTTP status 200 should be returned", ->
            @response.statusCode.should.equal 200


        describe "master key deleting", ->
            before cleanRequest

        it "When I send a request to delete the master key", (done) ->
            client.del "accounts/", (error, response, body) => 
                @response = response
                done()
 
        it "Then master key should be null", ->
            should.equal app.crypto.masterKey, null

        it "Then HTTP status 204 should be returned", ->
            @response.statusCode.should.equal 204 



    describe "Operation of cryptography : ", ->
        describe "When I encrypt a random value", ->

        it "Then encrypted data should not be equal to random value", ->
            @randomValue = randomString()
            @key = randomString 32
            @crypted = app.crypto.encrypt @key, @randomValue
            @crypted.should.not.equal @randomValue


        it "Then decrypted data should be equal to random value", ->
            @decrypted = app.crypto.decrypt @key, @crypted
            @decrypted.should.equal @randomValue

        describe "When I generate a salt", ->

        it "Then length of salt should be equal to the parameter", ->
            @salt = app.crypto.genSalt 15
            @salt.length.should.equal 15

        it "Then an other salt should not be equal to the first", ->
            @salt2 = app.crypto.genSalt 15
            @salt.length.should.not.equal @salt