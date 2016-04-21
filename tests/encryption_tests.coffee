should = require('chai').Should()
helpers = require './helpers'

Crypto = require "#{helpers.prefix}server/lib/crypto_tools"
User = require "#{helpers.prefix}server/lib/user"

# connection to DB for "hand work"
db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()

client = helpers.getClient()
crypto = new Crypto()
user = new User()

# helpers
cleanRequest = ->
    delete @body
    delete @res


describe "Encryption handling tests", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before (done) ->
        data =
            email: "user@CozyCloud.CC"
            timezone: "Europe/Paris"
            password: "password"
            encryptedField: "encrypted"
            docType: "User"
        db.save '102', data, done

    before helpers.startApp
    after helpers.stopApp

    describe "Data with password handling tests : ", ->
        describe "Create document with password", ->
            before cleanRequest

            it "When I send a request to initialize the keys and the salt", \
                    (done) ->
                @cozyPwd = "password"
                data = password: @cozyPwd
                client.setBasicAuth "proxy", "token"
                client.post 'accounts/password/', data, (err, res, body) =>
                    @res = res
                    done()

            it "And I add a document with password and encrypted field", \
                    (done)->
                data =
                    name: "test"
                    password: "password"
                    encryptedField: "encrypted"
                client.post 'data/',data,  (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "Then I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "password"
                    body.encryptedField.should.equal "encrypted"
                    done()

            it "And both password and encrypted field should be encrypted", \
                    (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.not.equal "password"
                    body.encryptedField.should.not.equal "encrypted"
                    done()

        describe "Update document with password", ->
            before cleanRequest

            it "When I add a document with password and encrypted field", \
                    (done) ->
                data =
                    name: "test"
                    password: "password"
                    encryptedField: "encrypted"
                client.post 'data/',data,  (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "And I update document with new password and encrypted field", \
                    (done) ->
                data =
                    name: "test"
                    password: "new_password"
                    encryptedField: "new_encrypted"
                client.put "data/#{@id}/",data,  (err, res, body) =>
                    done()

            it "And I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "new_password"
                    body.encryptedField.should.equal "new_encrypted"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.not.equal "new_password"
                    body.encryptedField.should.not.equal "new_encrypted"
                    done()

        describe "Merge document with password", ->
            before cleanRequest

            it "When I add a document with password and encrypted field", \
                    (done) ->
                data =
                    name: "test"
                    password: "password"
                    encryptedField: "encrypted"
                client.post 'data/',data,  (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "And I merge document with new password and encrypted field", \
                    (done) ->
                data =
                    password: "new_password"
                    encryptedField: "new_encrypted"
                client.put "data/merge/#{@id}/",data,  (err, res, body) =>
                    done()

            it "And I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "new_password"
                    body.encryptedField.should.equal "new_encrypted"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.not.equal "new_password"
                    body.encryptedField.should.not.equal "new_encrypted"
                    done()

        describe "Merge document without password", ->
            before cleanRequest

            it "When I add a document with password and encrypted field", \
                    (done) ->
                data =
                    name: "test"
                    password: "password"
                    encryptedField: "encrypted"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "And I merge the document with a new field", (done) ->
                data =
                    new_field: "new_test"
                client.put "data/merge/#{@id}/",data,  (err, res, body) =>
                    done()

            it "And I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "password"
                    body.encryptedField.should.equal "encrypted"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.not.equal "password"
                    body.encryptedField.should.not.equal "encrypted"
                    done()

       describe "Request document with password", ->
            before cleanRequest

            it "When I request a document with password and encrypted field", \
                    (done) ->
                client.post '/request/user/all/', {}, (err, res, body) =>
                    body[0].value.password.should.equal "password"
                    body[0].value.encryptedField.should.equal "encrypted"
                    done()
