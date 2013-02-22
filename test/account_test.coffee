should = require('chai').Should()
async = require('async')
Client = require('request-json').JsonClient

app = require '../server'
Crypto = require '../lib/crypto'
User = require '../lib/user'
randomString = require('../lib/random.coffee').randomString

client = new Client("http://localhost:8888/")
crypto = new Crypto()
user = new User()
db = require('../helpers/db_connect_helper').db_connect()


# helpers
cleanRequest = ->
    delete @body
    delete @res


describe "Data handling tests", ->

    # Clear DB, create a new one, then init data for tests.
    before (done) ->
        db.destroy ->
            db.create ->
                data =
                    email: "user@CozyCloud.CC"
                    timezone: "Europe/Paris"
                    password: "pwd_user"
                    docType: "User"
                db.save '102', data, (err, res, body) =>
                    done()

    # Start application before starting tests.
    before (done) ->
        app.listen(8888)
        done()

    # Stop application after finishing tests.
    after (done) ->
        app.close()
        done()

    before

    describe "Operation of cryptography : ", ->
        describe "Encryption", ->
            before cleanRequest

            it "When I encrypt a random value", (done)->
                @randomValue = randomString 32
                @key = randomString 32
                @crypted = crypto.encrypt @key, @randomValue
                done()

            it "Then encrypted data should not be equal to random value", ->
                @crypted.should.not.equal @randomValue

            it "And decrypted data should be equal to random value", ->
                @decrypted = crypto.decrypt @key, @crypted
                @decrypted.should.equal @randomValue

        describe "Salt", ->
            before cleanRequest

            it "When I generate a salt", (done) ->
                @salt = crypto.genSalt 15
                done()

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
                @randomValue = randomString 8
                data = pwd: @randomValue
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
                @masterKey = crypto.genHashWithSalt(@randomValue, @salt)
                @masterKey.length.should.equal 32
                should.not.equal app.crypto.masterKey, null
                app.crypto.masterKey.should.equal @masterKey

            it "And object 'User' should have a slave key", ->
                @body.should.have.property 'slaveKey'
                @encryptedSlaveKey = @body.slaveKey

            it "And the length of the slave key should be equal to 32", ->
                @slaveKey = crypto.decrypt @masterKey, @encryptedSlaveKey
                @slaveKey.length.should.be.equal 32

            it "And slave key should be encrypted", ->
                @slaveKey.should.not.be.equal app.crypto.slaveKey

            it "And HTTP status 200 should be returned", ->
                @res.statusCode.should.equal 200

        describe "Keys deleting", ->
            before cleanRequest

            it "When I send a request to delete the master key", (done) ->
                client.del "accounts/", (err, res, body) =>
                    @res = res
                    done()

            it "Then master key should be null", ->
                should.equal app.crypto.masterKey, null

            it "And HTTP status 204 should be returned", ->
                @res.statusCode.should.equal 204

        describe "Initialize the keys in a second connection", ->
            before cleanRequest

            it "When I send a request to initialize of the master key", \
                    (done) ->
                data = pwd: @randomValue
                client.post 'accounts/password/', data, (err, res, body) =>
                    @res = res
                    done()

            it "Then the object 'User' should have the same salt", (done)->
                client.get 'data/102/', (err, res, body) =>
                    body.should.have.property 'salt'
                    body.salt.should.equal @salt
                    done()

            it "And master key should be initialized", ->
                app.crypto.masterKey.should.equal @masterKey

            it "And slave key should be initialized", ->
                app.crypto.slaveKey.should.equal @encryptedSlaveKey

            it "And HTTP status 200 should be returned", ->
                @res.statusCode.should.equal 200


    describe "Create", ->
        describe "Creation of a new account", ->
            before cleanRequest
            after ->
                delete @_id
                delete @pwd

            it "When I send a request to post an account", (done) ->
                data =
                    login : "log"
                    pwd : "password"
                    service : "cozyCloud"
                client.post 'account/', data, (err, res, body) =>
                    @body = body
                    @res = res
                    done()

            it "Then the id of the new account should be returned", ->
                @body.should.have.property '_id'
                @_id = @body._id

            it "And the account should exist in Database", (done) ->
                client.get "data/exist/#{@_id}/", (err, res, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "And the password in DB should be encrypted", (done)->
                client.get "data/#{@_id}/", (err, res, body) =>
                    body.should.have.property 'pwd'
                    encryptedPwd = crypto.encrypt @slaveKey, "password"
                    body.pwd.should.equal encryptedPwd
                    done()

            it "And HTTP status 201 should be returned", ->
                @res.statusCode.should.equal 201

        describe "Creation of a new account with a specific id", ->
            before cleanRequest
            after ->
                delete @_id
                delete @pwd

            it "When I send a request to post an account with the id 456", \
                    (done) ->
                data =
                    login: "log"
                    pwd: "password"
                    service: "cozyCloud"
                client.post 'account/456/', data , (err, res, body) =>
                    @body = body
                    @res = res
                    done()

            it "Then the id 456 should be returned", ->
                @body.should.have.property '_id'
                @_id = @body._id
                @_id.should.be.equal "456"

            it "And the account with the id 456 should exist in Database",\
                        (done) ->
                client.get "data/exist/456/", (err, res, body) =>
                    body.exist.should.be.true
                    done()

            it "And the password in DB should be encrypted", (done)->
                client.get "data/456/", (err, res, body) =>
                    body.should.have.property 'pwd'
                    encryptedPwd = crypto.encrypt @slaveKey, "password"
                    body.pwd.should.equal encryptedPwd
                    done()

            it "And HTTP status 201 should be returned", ->
                @res.statusCode.should.equal 201

        describe "Creation of an account without password", ->
            before cleanRequest

            it "When I send a request to post the account", (done) ->
                data =
                    login: "log"
                    service: "cozyCloud"
                client.post 'account/', data , (err, res, body) =>
                    @res = res
                    done()

            it "Then error 409 should be returned", ->
                @res.statusCode.should.equal 409


    describe "Get", ->
        describe "Get an account that does not exist in database", ->
            before cleanRequest

            it "When I send a request to get Document with id 345", (done) ->
                client.get "account/345/", (err, res, body) =>
                    @res = res
                    done()

            it "Then error 404 should be returned", ->
                @res.statusCode.should.equal 404

        describe "Get an account that exist in database", ->
            before cleanRequest
            after ->
                delete @pwd

            it "When I send a request to post an account", (done) ->
                data =
                    login: "log"
                    pwd: "password"
                    service: "cozyCloud"
                client.post 'account/', data, (err, res, body) =>
                    @_id = body._id
                    done()

            it "And I send a request to get an account", (done) ->
                client.get "account/#{@_id}/", (err, res, body) =>
                    @body = body
                    @res = res
                    done()

            it "Then the account should have a porperty 'pwd'", ->
                @body.should.have.property 'pwd'
                @pwd = @body.pwd

            it "And the password should be decrypted", ->
                @pwd.should.be.equal "password"

            it "And the correct account should be returned", ->
                data =
                    _id: "#{@_id}"
                    login: "log"
                    pwd: "password"
                    service: "cozyCloud"
                    docType: "Account"
                @body.should.deep. equal data

            it "And HTT status 200 should be returned", ->
                @res.statusCode.should.equal 200


    describe "Update", ->
        describe "Try to update an account that doesn't exist", ->
            before cleanRequest

            it "When I send a request to update", (done) ->
                data =
                    login: "newLog"
                    pwd: "newPassword"
                    service: "cozyCloud"
                client.put 'account/345/', data, (err, res, body) =>
                    @res = res
                    done()

            it "Then error 404 should be returned", ->
                @res.statusCode.should.equal 404

        describe "Update an account that does exist", ->
            before cleanRequest

            it "When I send a request to update", (done) ->
                data =
                    login: "newLog"
                    pwd: "newPassword"
                    service: "cozyCloud"
                client.put 'account/456/', data, (err, res, body) =>
                    @res = res
                    done()

            it "Then the account exists in the database", (done) ->
                client.get 'account/456/', (err, res, body) =>
                    @body = body
                    res.statusCode.should.equal 200
                    done()

            it "And the old account must have been replaced", ->
                data =
                    _id: "456"
                    login: "newLog"
                    pwd: "newPassword"
                    service: "cozyCloud"
                    docType: "Account"
                @body.should.deep.equal data

            it "And the new password should be encrypted", (done) ->
                client.get 'data/456/', (err, res, body) =>
                    encryptedPwd = crypto.encrypt @slaveKey, "newPassword"
                    body.pwd.should.equal encryptedPwd
                    done()

            it "And HTTP status 200 should be returned", ->
                @res.statusCode.should.equal 200


    describe "Merge", ->
        describe "Try to merge an account that doesn't exist", ->
            before cleanRequest

            it "When I send a request to merge", (done) ->
                data = login: "newLog"
                client.put 'account/merge/345/', data, (err, res, body) =>
                    @res = res
                    console.log(res.statusCode)
                    done()

            it "Then error 404 should be returned", ->
                @res.statusCode.should.equal 404

        describe "Merge a classic field of an account that does exist", ->
            before cleanRequest

            it "When I send a request to merge", (done) ->
                data = login: "newLog"
                client.put 'account/merge/456/', data, (err, res, body) =>
                    @res = res
                    done()

            it "Then the account exists in the database", (done) ->
                client.get 'account/456/', (err, res, body) =>
                    @body = body
                    res.statusCode.should.equal 200
                    done()

            it "And the old account must have been replaced", ->
                @body.should.have.property 'login'
                @body.login.should.equal "newLog"

            it "And HTTP status 200 should be returned", ->
                @res.statusCode.should.equal 200

        describe "Merge the password of an account that does exist", ->
            before cleanRequest

            it "When I send a request to merge", (done) ->
                data = pwd: "newPwd"
                client.put 'account/merge/456/', data, (err, res, body) =>
                    @res = res
                    done()

            it "Then the account exists in the database", (done) ->
                client.get 'account/456/', (err, res, body) =>
                    @body = body
                    res.statusCode.should.equal 200
                    done()

            it "And the old account must have been replaced", ->
                @body.should.have.property 'pwd'
                @body.pwd.should.equal "newPwd"

            it "And the new password should be encrypted", (done) ->
                client.get 'data/456/', (err, res, body) =>
                    encryptedPwd = crypto.encrypt @slaveKey, "newPwd"
                    body.pwd.should.equal encryptedPwd
                    done()

            it "And HTTP status 200 should be returned", ->
                @res.statusCode.should.equal 200


    describe "Delete an account", ->
        describe "Try to delete an account that doesn't exist", ->
            before cleanRequest

            it "When I send a request to delete", (done) ->
                client.del 'account/345/', (err, res, body) =>
                    @res = res
                    done()

            it "Then error 404 should be returned", ->
                @res.statusCode.should.equal 404

        describe "Delete an account that exist", ->
            before cleanRequest

            it "When I send a request to delete", (done) ->
                client.del 'account/456/', (err, res, body) =>
                    @res = res
                    done()

            it "Then the account should not exist in the database", (done) ->
                client.get 'account/456/', (err, res, body) =>
                    res.statusCode.should.equal 404
                    done()

            it "And the document should not exist in the database", (done) ->
                client.get 'data/456/', (err, res, body) =>
                    res.statusCode.should.equal 404
                    done()

            it "And HTTP status 204 should be returned", ->
                @res.statusCode.should.equal 204
