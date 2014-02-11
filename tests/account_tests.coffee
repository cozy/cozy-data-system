should = require('chai').Should()
Client = require('request-json').JsonClient
helpers = require('./helpers')

Crypto = require '../server/lib/crypto_tools'
User = require '../server/lib/user'
randomString = require('../server/lib/random.coffee').randomString
getMasterKey = require('../server/lib/encryption').get
db = require('../server/helpers/db_connect_helper').db_connect()
helpers.options =
    serverHost: 'localhost'
    serverPort: '8888'
client = new Client "http://#{helpers.options.serverHost}:#{helpers.options.serverPort}/"

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
        describe "Initialization of the keys and the salt", ->
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

            it "And master key should be initialized", ->
                @masterKey = crypto.genHashWithSalt @cozyPwd, @salt
                key = getMasterKey()
                should.not.equal key, null
                key.should.equal @masterKey

            it "And object 'User' should have a slave key", ->
                @body.should.have.property 'slaveKey'
                @encryptedSlaveKey = @body.slaveKey

            it "And the length of the slave key should be equal to 32", ->
                @slaveKey = crypto.decrypt @masterKey, @encryptedSlaveKey
                @slaveKey.length.should.be.equal 32
