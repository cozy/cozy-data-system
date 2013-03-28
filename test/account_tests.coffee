should = require('chai').Should()
Client = require('request-json').JsonClient
helpers = require('./helpers')

Crypto = require '../lib/crypto_tools'
User = require '../lib/user'
randomString = require('../lib/random.coffee').randomString

db = require('../helpers/db_connect_helper').db_connect()
client = new Client "http://localhost:8888/"
crypto = new Crypto()
user = new User()


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
                    password: "password"
                    docType: "User"
                db.save '102', data, (err, res, body) ->
                    done()

    before helpers.instantiateApp

    after  helpers.closeApp

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
                should.not.equal @app.crypto.masterKey, null
                @app.crypto.masterKey.should.equal @masterKey

            it "And object 'User' should have a slave key", ->
                @body.should.have.property 'slaveKey'
                @encryptedSlaveKey = @body.slaveKey

            it "And the length of the slave key should be equal to 32", ->
                @slaveKey = crypto.decrypt @masterKey, @encryptedSlaveKey
                @slaveKey.length.should.be.equal 32

            it "And slave key should be encrypted", ->
                @slaveKey.should.not.be.equal @app.crypto.slaveKey

            it "And HTTP status 200 should be returned", ->
                @res.statusCode.should.equal 200

        #describe "Keys deleting", ->
            #before cleanRequest

            #it "When I send a request to delete the master key", (done) ->
                #client.del "accounts/", (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then master key should be null", ->
                #should.equal app.crypto.masterKey, null

            #it "And HTTP status 204 should be returned", ->
                #@res.statusCode.should.equal 204

        #describe "Initialize keys in a second connection", ->
            #before cleanRequest

            #it "When I send a request to initialize of the master key", \
                    #(done) ->
                #data = password: @cozyPwd
                #client.post 'accounts/password/', data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then the object 'User' should have the same salt", (done)->
                #client.get 'data/102/', (err, res, body) =>
                    #body.should.have.property 'salt'
                    #body.salt.should.equal @salt
                    #done()

            #it "And master key should be initialized", ->
                #app.crypto.masterKey.should.equal @masterKey

            #it "And slave key should be initialized", ->
                #app.crypto.slaveKey.should.equal @encryptedSlaveKey

            #it "And HTTP status 200 should be returned", ->
                #@res.statusCode.should.equal 200


        #describe "Update cozy password", ->
            #before cleanRequest

            #it "When I send a request to modify the cozy password", (done) ->
                #@newPwd = randomString 10
                #data = password: @newPwd
                #client.put 'accounts/password/', data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "And I send a request to have the salt", (done)->
                #client.get 'data/102/', (err, res, body) =>
                    #body.should.have.property 'salt'
                    #@salt = body.salt
                    #@salt.length.should.be.equal 22
                    #done()

            #it "Then the master key should be modified", ->
                #app.crypto.masterKey.should.not.equal @masterKey
                #@masterKey = crypto.genHashWithSalt @newPwd, @salt
                #app.crypto.masterKey.should.equal @masterKey

            #it "And the slave key should not be modify", ->
                #@newSlaveKey = crypto.decrypt @masterKey, app.crypto.slaveKey
                #@newSlaveKey.should.be.equal @slaveKey

            #it "And HTTP status 200 should be returned", ->
                #@res.statusCode.should.equal 200


    #describe "Create", ->
        #describe "Creation of a new account", ->
            #before cleanRequest
            #after ->
                #delete @_id
                #delete @password

            #it "When I send a request to post an account", (done) ->
                #data =
                    #login : "log"
                    #password : "password"
                    #service : "cozyCloud"
                #client.post 'account/', data, (err, res, body) =>
                    #@body = body
                    #@res = res
                    #done()

            #it "Then the id of the new account should be returned", ->
                #@body.should.have.property '_id'
                #@_id = @body._id

            #it "And the account should exist in Database", (done) ->
                #client.get "data/exist/#{@_id}/", (err, res, body) =>
                    #@body = body
                    #@body.exist.should.be.true
                    #done()

            #it "And the password in DB should be encrypted", (done)->
                #client.get "data/#{@_id}/", (err, res, body) =>
                    #body.should.have.property 'password'
                    #body.password.should.not.equal "password"
                    #done()

            #it "And HTTP status 201 should be returned", ->
                #@res.statusCode.should.equal 201


        #describe "Creation of an account without password", ->
            #before cleanRequest

            #it "When I send a request to post the account", (done) ->
                #data =
                    #login: "log"
                    #service: "cozyCloud"
                #client.post 'account/', data , (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then error 401 should be returned", ->
                #@res.statusCode.should.equal 401


    #describe "Get", ->
        #describe "Get an account that does not exist in database", ->
            #before cleanRequest

            #it "When I send a request to get Document with id 345", (done) ->
                #client.get "account/345/", (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then error 404 should be returned", ->
                #@res.statusCode.should.equal 404

        #describe "Get an account that exist in database", ->
            #before cleanRequest
            #after ->
                #delete @password
                #delete @_id

            #it "When I send a request to post an account", (done) ->
                #data =
                    #login: "log"
                    #password: "password"
                    #service: "cozyCloud"
                #client.post 'account/', data, (err, res, body) =>
                    #@_id = body._id
                    #done()

            #it "And I send a request to get an account", (done) ->
                #client.get "account/#{@_id}/", (err, res, body) =>
                    #@body = body
                    #@res = res
                    #done()

            #it "Then the account should have a porperty 'pwd'", ->
                #@body.should.have.property 'password'
                #@password = @body.password

            #it "And the password should be decrypted", ->
                #@password.should.be.equal "password"

            #it "And the correct account should be returned", ->
                #@body._id.should.be.equal "#{@_id}"
                #@body.login.should.be.equal "log"
                #@body.service.should.be.equal "cozyCloud"
                #@body.docType.should.be.equal "Account"
                #@body.should.have.property 'witness'

            #it "And HTT status 200 should be returned", ->
                #@res.statusCode.should.equal 200


    #describe "Update", ->

        #describe "Try to update an account that doesn't exist", ->
            #before cleanRequest

            #it "When I send a request to update", (done) ->
                #data =
                    #login: "newLog"
                    #password: "newPassword"
                    #service: "cozyCloud"
                #client.put 'account/345/', data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then error 404 should be returned", ->
                #@res.statusCode.should.equal 404

        #describe "Update an account that does exist", ->
            #before cleanRequest

            #it "When I send a request to post an account", (done) ->
                #data =
                    #login: "log"
                    #password: "password"
                    #service: "cozyCloud"
                #client.post 'account/', data, (err, res, body) =>
                    #@_id = body._id
                    #done()

            #it "And I send a request to update", (done) ->
                #data =
                    #login: "newLog"
                    #password: "newPassword"
                    #service: "cozyCloud"
                #client.put "account/#{@_id}/", data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then the account exists in the database", (done) ->
                #client.get "account/#{@_id}/", (err, res, body) =>
                    #@body = body
                    #res.statusCode.should.equal 200
                    #done()

            #it "And the old account must have been replaced", ->
                #@body._id.should.be.equal "#{@_id}"
                #@body.login.should.be.equal "newLog"
                #@body.password.should.be.equal "newPassword"
                #@body.service.should.be.equal "cozyCloud"
                #@body.docType.should.be.equal "Account"
                #@body.should.have.property 'witness'

            #it "And the new password should be encrypted", (done) ->
                #client.get "data/#{@_id}/", (err, res, body) =>
                    #body.password.should.not.equal "newPassword"
                    #done()

            #it "And HTTP status 200 should be returned", ->
                #@res.statusCode.should.equal 200

        #describe "Update an account without password", ->
            #cleanRequest

            #it "When I send a request to update", (done) ->
                #data =
                    #login: "log"
                    #service: "cozy"
                #client.put "account/#{@_id}/", data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then the old account doesn't must have been replaced", ->
                #@body._id.should.be.equal "#{@_id}"
                #@body.login.should.be.equal "newLog"
                #@body.service.should.be.equal "cozyCloud"
                #@body.docType.should.be.equal "Account"
                #@body.should.have.property 'witness'

            #it "And error 401 should be returned", ->
                #@res.statusCode.should.equal 401


    #describe "Upsert", ->
        #describe "Upsert an account that doesn't exist", ->
            #before cleanRequest

            #it "When I send a request to upsert an account", (done) ->
                #data =
                    #login: "login"
                    #password: "password"
                    #service: "cozyCloud"
                #client.put 'account/upsert/741/', data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then the HTTP status 201 should be returned", ->
                #@res.statusCode.should.equal 201

            #it "And the account should be in the database", (done) ->
                #client.get 'account/741/', (err, res, body) =>
                    #res.statusCode.should.equal 200
                    #@body = body
                    #done()

            #it "And the account must have been replaced", ->
                #@body._id.should.be.equal "741"
                #@body.login.should.be.equal "login"
                #@body.password.should.be.equal "password"
                #@body.service.should.be.equal "cozyCloud"
                #@body.docType.should.be.equal "Account"
                #@body.should.have.property 'witness'

        #describe "Upsert an account that exist", ->
            #before cleanRequest

            #it "When I send a request to upsert an account", (done) ->
                #data =
                    #login: "login"
                    #password: "password"
                    #service: "cozyCloud"
                #client.put 'account/upsert/456/', data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then the HTTP status 201 should be returned", ->
                #@res.statusCode.should.equal 201

            #it "And the account should be in the database", (done) ->
                #client.get 'account/456/', (err, res, body) =>
                    #res.statusCode.should.equal 200
                    #@body = body
                    #done()

            #it "And the account must have been replaced", ->
                #@body._id.should.be.equal "456"
                #@body.login.should.be.equal "login"
                #@body.password.should.be.equal "password"
                #@body.service.should.be.equal "cozyCloud"
                #@body.docType.should.be.equal "Account"
                #@body.should.have.property 'witness'

        #describe "Upsert an account without password", ->
            #cleanRequest

            #it "When I send a request to upsert an account", (done) ->
                #data =
                    #login: "log"
                    #service: "cozy"
                #client.put 'account/upsert/456/', data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "And the old account doesn't must have been replaced", ->
                #@body._id.should.be.equal "456"
                #@body.login.should.be.equal "login"
                #@body.password.should.be.equal "password"
                #@body.service.should.be.equal "cozyCloud"
                #@body.docType.should.be.equal "Account"
                #@body.should.have.property 'witness'

            #it "And the error 500 should be returned", ->
                #@res.statusCode.should.equal 500


    #describe "Merge", ->
        #describe "Try to merge an account that doesn't exist", ->
            #before cleanRequest

            #it "When I send a request to merge", (done) ->
                #data = login: "newLog"
                #client.put 'account/merge/345/', data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then error 404 should be returned", ->
                #@res.statusCode.should.equal 404

        #describe "Merge a classic field of an account that does exist", ->
            #before cleanRequest

            #it "When I send a request to merge", (done) ->
                #data = login: "newLog"
                #client.put 'account/merge/456/', data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then the account exists in the database", (done) ->
                #client.get 'account/456/', (err, res, body) =>
                    #@body = body
                    #res.statusCode.should.equal 200
                    #done()

            #it "And the old account must have been replaced", ->
                #@body.should.have.property 'login'
                #@body.login.should.equal "newLog"

            #it "And HTTP status 200 should be returned", ->
                #@res.statusCode.should.equal 200

        #describe "Merge the password of an account that does exist", ->
            #before cleanRequest

            #it "When I send a request to merge", (done) ->
                #data = password: "newPwd"
                #client.put 'account/merge/456/', data, (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then the account exists in the database", (done) ->
                #client.get 'account/456/', (err, res, body) =>
                    #@body = body
                    #res.statusCode.should.equal 200
                    #done()

            #it "And the old account must have been replaced", ->
                #@body.should.have.property 'password'
                #@body.password.should.equal "newPwd"

            #it "And the new password should be encrypted", (done) ->
                #client.get 'data/456/', (err, res, body) =>
                    #body.password.should.not.equal "newPwd"
                    #done()

            #it "And HTTP status 200 should be returned", ->
                #@res.statusCode.should.equal 200


    #describe "Existence", ->
        #describe "Existence of an account that doesn't exist", ->
            #before cleanRequest

            #it "When I send a request to check the existence of the account", \
             #(done) ->
                #client.get 'account/exist/123/', (err, res, body) =>
                    #@res = res
                    #@body = body
                    #done()

            #it "Then {exist: false} should be returned", ->
                #should.exist @body.exist
                #@body.exist.should.not.be.ok

            #it "And HTTP status 200 should be returned", ->
                #@res.statusCode.should.equal 200


        #describe "Existence of an account that exists", ->
            #before cleanRequest

            #it "When I send a request to check the existence of the account", \
                    #(done) ->
                #client.get 'account/exist/456/', (err, res, body) =>
                    #@res = res
                    #@body = body
                    #done()

            #it "Then {exist: true} should be returned", ->
                #should.exist @body.exist
                #@body.exist.should.be.ok

            #it "And HTTP status 200 should be returned", ->
                #@res.statusCode.should.equal 200

    #describe "Delete an account", ->
        #describe "Try to delete an account that doesn't exist", ->
            #before cleanRequest

            #it "When I send a request to delete", (done) ->
                #client.del 'account/345/', (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then error 404 should be returned", ->
                #@res.statusCode.should.equal 404

        #describe "Delete an account that exist", ->
            #before cleanRequest

            #it "When I send a request to delete", (done) ->
                #client.del 'account/456/', (err, res, body) =>
                    #@res = res
                    #done()

            #it "Then the account should not exist in the database", (done) ->
                #client.get 'account/456/', (err, res, body) =>
                    #res.statusCode.should.equal 404
                    #done()

            #it "And the document should not exist in the database", (done) ->
                #client.get 'data/456/', (err, res, body) =>
                    #res.statusCode.should.equal 404
                    #done()

            #it "And HTTP status 204 should be returned", ->
                #@res.statusCode.should.equal 204


    #describe "Delete all accounts", ->
        #before cleanRequest

        #it "When I send a request to create an account", (done) ->
            #data =
                #login: "log"
                #password: "password"
                #service: "cozyCloud"
            #client.post 'account/', data, (err, res, body) =>
                #@_id = body._id
                #done()

        #it "And I send a request to delete all accounts", (done) ->
            #client.del 'account/all/', (err, res, body) =>
                #@res = res
                #@err = err
                #done()

        #it "Then no error should be returned", ->
            #should.not.exist @err

        #it "And the account doesn't exist in the database", (done) ->
            #client.get "account/exist/#{@_id}/", (err, res, body) =>
                #should.exist body.exist
                #body.exist.should.not.be.ok
                #done()

    #describe "Reset password", ->
        #before cleanRequest

        #it "When I send a request to create an account", (done) ->
            #data =
                #login: "log"
                #password: "password"
                #service: "cozyCloud"
            #client.post 'account/', data, (err, res, body) =>
                #@_id = body._id
                #done()

        #it "And I send a request to reset the password", (done) ->
            #client.del "accounts/reset/", (err, res, body) =>
                #@res = res
                #@err = err
                #done()

        #it "Then no error should be returned", ->
            #should.not.exist @err

        #it "And app.crypto should be null", ->
            #should.equal app.crypto, null
