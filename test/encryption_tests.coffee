should = require('chai').Should()
Client = require('request-json').JsonClient
helpers = require('./helpers')

Crypto = require '../lib/crypto_tools'
User = require '../lib/user'
randomString = require('../lib/random.coffee').randomString
getMasterKey = require('../lib/encryption').get
db = require('../helpers/db_connect_helper').db_connect()
client = new Client "http://localhost:8888/"
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
            docType: "User"
        db.save '102', data, done

    before helpers.instantiateApp
    after helpers.after db

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

            it "And I add a document with password", (done)->
                data =
                    name: "test"
                    password: "password"
                client.post 'data/',data,  (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "Then I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "password"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.not.equal "password"
                    done()

        describe "Update document with password", ->
            before cleanRequest

            it "When I add a document with password", (done) ->
                data =
                    name: "test"
                    password: "password"
                client.post 'data/',data,  (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "And I update the document with a new password", (done) ->
                data =
                    name: "test"
                    password: "new_password"
                client.put "data/#{@id}/",data,  (err, res, body) =>
                    done()

            it "And I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "new_password"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.not.equal "new_password"
                    done()

        describe "Merge document with password", ->
            before cleanRequest

            it "When I add a document with password", (done) ->
                data =
                    name: "test"
                    password: "password"
                client.post 'data/',data,  (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "And I merge the document with a new password", (done) ->
                data =
                    password: "new_password"
                client.put "data/merge/#{@id}/",data,  (err, res, body) =>
                    done()

            it "And I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "new_password"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.not.equal "new_password"
                    done()

        describe "Merge document without password", ->
            before cleanRequest

            it "When I add a document with password", (done) ->
                data =
                    name: "test"
                    password: "password"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "And I merge the document with a new password", (done) ->
                data =
                    new_field: "new_test"
                client.put "data/merge/#{@id}/",data,  (err, res, body) =>
                    done()

            it "And I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "password"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.not.equal "password"
                    done()

    describe "Application handling tests : ", ->
        describe "Create application with password", ->
            before cleanRequest

            it "When I add a document with password", (done)->
                data =
                    name: "test"
                    password: "password"
                    docType: "Application"
                client.post 'data/',data,  (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "Then I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "password"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.equal "password"
                    done()

        describe "Update document with password", ->
            before cleanRequest

            it "When I add a document with password", (done) ->
                data =
                    name: "test"
                    password: "password"
                    docType: "Application"
                client.post 'data/',data,  (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "And I update the document with a new password", (done) ->
                data =
                    name: "test"
                    password: "new_password"
                    docType: "Application"
                client.put "data/#{@id}/",data,  (err, res, body) =>
                    done()

            it "And I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "new_password"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.equal "new_password"
                    done()

        describe "Merge document with password", ->
            before cleanRequest

            it "When I add a document with password", (done) ->
                data =
                    name: "test"
                    password: "password"
                    docType: "Application"
                client.post 'data/',data,  (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "And I merge the document with a new password", (done) ->
                data =
                    password: "new_password"
                client.put "data/merge/#{@id}/",data,  (err, res, body) =>
                    done()

            it "And I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "new_password"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.equal "new_password"
                    done()

        describe "Merge document without password", ->
            before cleanRequest

            it "When I add a document with password", (done) ->
                data =
                    name: "test"
                    password: "password"
                    docType: "Application"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @id = body._id
                    done()

            it "And I merge the document with a new password", (done) ->
                data =
                    new_field: "new_test"
                client.put "data/merge/#{@id}/",data,  (err, res, body) =>
                    done()

            it "And I recover this document", (done) ->
                client.get "data/#{@id}/", (err, res, body) =>
                    body.password.should.equal "password"
                    done()

            it "And password should be encrypted", (done) ->
                db.get "#{@id}", (err, body) =>
                    body.password.should.equal "password"
                    done()