should = require('chai').Should()
helpers = require './helpers'

prefix = helpers.prefix
Crypto = require "#{prefix}server/lib/crypto_tools"
User = require "#{prefix}server/lib/user"
randomString = require("#{prefix}server/lib/random").randomString
db = require("#{prefix}server/helpers/db_connect_helper").db_connect()
client = helpers.getClient()
crypto = new Crypto()
user = new User()

# helpers
cleanRequest = ->
    delete @body
    delete @res


describe "Account handling tests", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before (done) ->
        data =
            email: "user@CozyCloud.CC"
            timezone: "Europe/Paris"
            password: "password"
            docType: "User"
        db.save '102', data, done

    before helpers.startApp
    after helpers.stopApp

    describe "Operation of cryptography : ", ->
        describe "Encryption", ->
            before cleanRequest

            it "When I encrypt a random value", ->
                @randomValue = randomString 32
                @key = randomString 32
                @crypted = crypto.encrypt @key, @randomValue

            it "Then encrypted data should not be equal to random value", ->
                @crypted.should.not.equal @randomValue
                encrypted = crypto.encrypt @key, @randomValue

            it "And decrypted data should be equal to random value", ->
                @decrypted = crypto.decrypt @key, @crypted
                @decrypted.should.equal @randomValue

        describe "Salt", ->
            before cleanRequest

            it "When I generate a salt", ->
                @salt = crypto.genSalt 15

            it "Then length of salt should be equal to the parameter", ->
                @salt.length.should.equal 15

            it "And an other salt should not be equal to the first", ->
                @salt2 = crypto.genSalt 15
                @salt2.should.not.equal @salt


    describe "Keys handling tests : ", ->
        describe "Initialization of the keys and the salt (register/first login)", ->
            before cleanRequest

            it "When I send a request to initialize the keys and the salt", \
                    (done) ->
                @cozyPwd = "password"
                data = password: @cozyPwd
                client.setBasicAuth "proxy", "token"
                client.post 'accounts/password/', data, (err, res, body) =>
                    @res = res
                    done()

            it "And I send a request to check the salt", (done)->
                client.get 'data/102/', (err, res, body) =>
                    @body = body
                    done()

            it "Then the object 'User' have an initialized salt", ->
                @body.should.have.property 'salt'
                @salt = @body.salt
                should.not.equal @salt, undefined
                @salt.length.should.equal 24

            it "And object 'User' should have a slave key", ->
                @body.should.have.property 'slaveKey'
                @encryptedSlaveKey = @body.slaveKey

            it "And the length of the slave key should be equal to 32", ->
                @masterKey = crypto.genHashWithSalt @cozyPwd, @salt
                @slaveKey = crypto.decrypt @masterKey, @encryptedSlaveKey
                @slaveKey.length.should.be.equal 32

        describe "Keys reloading (the user already has master/slave keys)" \
        , ->
            before cleanRequest

            it "When a request is sent to reload the keys", (done) ->
                @cozyPwd = "password"
                data = password: @cozyPwd
                client.setBasicAuth "proxy", "token"
                client.post 'accounts/password/', data, (err, res, body) =>
                    @res = res
                    done()

            it "And I send a request to check the salt", (done)->
                client.get 'data/102/', (err, res, body) =>
                    @body = body
                    done()

            it "Then the object 'User' have an initialized salt", ->
                @body.should.have.property 'salt'
                @salt = @body.salt
                should.not.equal @salt, undefined
                @salt.length.should.equal 24

            it "And object 'User' should have a slave key", ->
                @body.should.have.property 'slaveKey'
                @encryptedSlaveKey = @body.slaveKey

            it "And the length of the slave key should be equal to 32", ->
                @masterKey = crypto.genHashWithSalt @cozyPwd, @salt
                @slaveKey = crypto.decrypt @masterKey, @encryptedSlaveKey
                @slaveKey.length.should.be.equal 32

        describe "If there is no password field", ->
            before cleanRequest

            it "When a request is sent without the password field", (done) ->
                @cozyPwd = "password"
                data = {}
                client.setBasicAuth "proxy", "token"
                client.post 'accounts/password/', data, (err, res, body) =>
                    @res = res
                    done()
            it "It should fail with a 400 bad request error", ->
                @res.statusCode.should.equal 400

    describe "Unauthorized request", ->
        before cleanRequest
        it "When I try to initialize the keys without the right token", \
        (done) ->
            @cozyPwd = "password"
            data = password: @cozyPwd
            client.setBasicAuth "proxy", ''
            client.post 'accounts/password/', data, (err, res, body) =>
                @res = res
                done()
        it "There should be a 403 not authorized error", ->
            @res.statusCode.should.equal 403


