should = require('chai').Should()
async = require('async')
Crypto = require('../lib/crypto.coffee')
Client = require('request-json').JsonClient

app = require('../server')
user = require('../lib/user.coffee')

client = new Client("http://localhost:8888/")
crypto = new Crypto()
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
                done()

    # Init user object
    before (done) ->
        data =
            email: "user@CozyCloud.CC"
            timezone: "Europe/Paris"
            password: "pwd_user"
            docType: "User"

        client.post 'data/102/', data, (error, response, body) =>
            done()

    # Start application before starting tests.
    before (done) ->
        app.listen(8888)
        done()

    # Stop application after finishing tests.
    after (done) ->
        app.close()
        done()


    describe "Master key handling tests : ", ->
        describe "Initialization of the master key", ->
            before cleanRequest

            it "When I send a request to initialize the master key", (done) ->
                @randomValue = randomString 8
                data = pwd: @randomValue
                client.post 'accounts/password/', data, (err, res, body) =>
                    @response = res
                    done()

            it "And I send a request to check the salt", (done)->
                client.get 'data/102/', (error, response, body) =>
                    @body = body
                    done()

            it "Then the object 'User' have an initialized salt", ->
                @body.should.have.property 'salt'
                @salt = @body.salt
                should.not.equal @salt, undefined
                @salt.length.should.equal 24

            it "And master key should be initialized", ->
                @masterKey = app.crypto.genHashWithSalt(@randomValue, @salt)
                @masterKey.length.should.equal 32
                should.not.equal app.crypto.masterKey, null
                app.crypto.masterKey.should.equal @masterKey

            it "And HTTP status 200 should be returned", ->
                @response.statusCode.should.equal 200


        describe "Master key deleting", ->
            before cleanRequest

            it "When I send a request to delete the master key", (done) ->
                client.del "accounts/", (error, response, body) =>
                    @response = response
                    done()
 
            it "Then master key should be null", ->
                should.equal app.crypto.masterKey, null

            it "And HTTP status 204 should be returned", ->
                @response.statusCode.should.equal 204


        describe "Initialize the master key in a second connection", ->
            before cleanRequest

            it "When I send a request to initialize of the master key", \
                    (done) ->
                client.post 'accounts/password/', pwd: @randomValue, \
                        (error, response, body) =>
                    @response = response
                    done()

            it "Then the object 'User' should have the same salt", (done)->
                client.get 'data/102/', (error, response, body) =>
                    body.should.have.property 'salt'
                    body.salt.should.equal @salt
                    done()

            it "Then master key should be initialized", ->
                app.crypto.masterKey.should.equal @masterKey

            it "Then HTTP status 200 should be returned", ->
                @response.statusCode.should.equal 200



    describe "Operation of cryptography : ", ->
        describe "Encryption", ->
            before cleanRequest

            it "Then encrypted data should not be equal to random value", ->
                @randomValue = randomString 32
                @key = randomString 32
                @crypted = app.crypto.encrypt @key, @randomValue
                @crypted.should.not.equal @randomValue


            it "Then decrypted data should be equal to random value", ->
                @decrypted = app.crypto.decrypt @key, @crypted
                @decrypted.should.equal @randomValue

        describe "Salt", ->
            before cleanRequest

            it "Then length of salt should be equal to the parameter", ->
                @salt = app.crypto.genSalt 15
                @salt.length.should.equal 15

            it "Then an other salt should not be equal to the first", ->
                @salt2 = app.crypto.genSalt 15
                @salt.length.should.not.equal @salt


    describe "Slave key handling tests : ", ->
        describe "Initialization of the slave key", ->
            before cleanRequest

            it "Then object 'User' should have a slave key", (done) ->
                client.get 'data/102/', (error, response, body) =>
                    body.should.have.property 'slaveKey'
                    @encryptedSlaveKey = body.slaveKey
                    done()

            it "Then the length of the slave key should be equal to 32", ->
                @slaveKey = app.crypto.decrypt @masterKey, @encryptedSlaveKey
                @slaveKey.length.should.be.equal 32

            it "Then slave key should be encrypted", ->
                @slaveKey.should.not.be.equal app.crypto.slaveKey


    describe "Create", ->
        describe "Creation of a new account", ->
            before cleanRequest
            after ->
                delete @_id
                delete @pwd

            it "When I send a request to post an account", (done) ->
                client.post 'account/', {docType : "Account", login : "log", \
                            pwd : "password", service : "cozyCloud"} , \
                            (error, response, body) =>
                    @body = body
                    @response = response
                    done()

            it "Then the id of the new account should be returned", ->
                @body.should.have.property '_id'
                @_id = @body._id

            it "Then the account should exist in Database", (done) ->
                client.get "data/exist/#{@_id}/", (error, response, body) =>
                    @body = body
                    @body.exist.should.be.true
                    done()

            it "Then the password in DB should be encrypted", (done)->
                client.get "data/#{@_id}/", (error, response, body) =>
                    body.should.have.property 'pwd'
                    @pwd = body.pwd
                    @pwd.should.not.be.equal "password"
                    done()

            it "Then HTTP status 201 should be returned", ->
                @response.statusCode.should.equal 201

        describe "Creation of a new account with a specific id", ->
            before cleanRequest
            after ->
                delete @_id
                delete @pwd

            it "When I send a request to post an account with the id 456", \
                    (done) ->
                client.post 'account/456/', {docType : "Account", login : "log" \
                            , pwd : "password", service : "cozyCloud"} , \
                            (error, response, body) =>
                    @body = body
                    @response = response
                    done()

            it "Then the id 456 should be returned", ->
                @body.should.have.property '_id'
                @_id = @body._id
                @_id.should.be.equal "456"

            it "Then the account with the is 456 should exist in Database",\
                        (done) ->
                client.get "data/exist/456/", (error, response, body) =>
                    body.exist.should.be.true
                    done()

            it "Then the password in DB should be encrypted", (done)->
                client.get "data/456/", (error, response, body) =>
                    body.should.have.property 'pwd'
                    @pwd = body.pwd
                    @pwd.should.not.be.equal "password"
                    done()

            it "Then HTTP status 201 should be returned", ->
                @response.statusCode.should.equal 201

        describe "Creation of an account without password", ->
            before cleanRequest

            it "When I send a request to post the account", (done) ->
                client.post 'account/', {docType : "Account", login : "log" \
                            , service : "cozyCloud"} , \
                            (error, response, body) =>
                    @response = response
                    done()

            it "Then error 409 should be returned", ->
                @response.statusCode.should.equal 409

        
    describe "Get", ->
        describe "Get an account that does not exist in database", ->
            before cleanRequest

            it "When I send a request to get Document with id 345", (done) ->
                client.get "account/345/", (error, response, body) =>
                    @response = response
                    done()

            it "Then error 404 should be returned", ->
                @response.statusCode.should.equal 404

        describe "Get an account that exist in database", ->
            before cleanRequest
            after ->
                delete @pwd

            it "When I send a request to post an account", (done) ->
                client.post 'account/', {docType : "Account", login : "log", \
                            pwd : "password", service : "cozyCloud"} , \
                            (error, response, body) =>
                    @_id = body._id
                    done()

            it "When I send a request to get an account", (done) ->
                client.get "account/#{@_id}/", (error, response, body) =>
                    @body = body
                    @response = response
                    done()

            it "Then the account should have a porperty 'pwd'", ->
                @body.should.have.property 'pwd'
                @pwd = @body.pwd

            it "Then the password should be decrypted", ->
                @pwd.should.be.equal "password"

            it "Then the correct account should be returned", ->
                @body.should.deep. equal {_id : "#{@_id}", \
                        docType : 'Account', login : 'log', \ 
                        pwd : 'password', service : 'cozyCloud'}

            it "Then HTT status 200 should be returned", ->
                @response.statusCode.should.equal 200
