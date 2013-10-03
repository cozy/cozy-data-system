should = require('chai').Should()
Client = require('request-json').JsonClient
helpers = require('./helpers')

Crypto = require '../lib/crypto_tools'
User = require '../lib/user'
randomString = require('../lib/random.coffee').randomString

crypto = new Crypto()
user = new User()
db = require('../helpers/db_connect_helper').db_connect()
client = new Client "http://localhost:8888/"

process.env.TOKEN = "token"


# helpers
cleanRequest = ->
    delete @body
    delete @res


describe "Token of applications handling tests", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db

    before helpers.instantiateApp

    after helpers.closeApp
    after helpers.clearDB db

    describe "Authentification", ->
        before cleanRequest

        describe "Requests without authentification", ->

            it "When application requests it without authentification", (done)->
                data =
                    test: "test"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @err = err
                    @res = res
                    done()

        describe "Installation of application", ->

            it "When I send a request to post an application", (done) ->
                data =
                    "name": "test"
                    "slug": "test"
                    "state": "installed"
                    "password": "token"
                    "permissions":
                        "Authorized":
                            "description": "This application needs ..."
                    "docType": "Application"
                client.setBasicAuth "home", "token"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @err = err
                    @res = res
                    done()

            it "Then no error should be returned", ->
                should.equal @err, null

            it "And HTTP status 201 should be returned", ->
                @res.statusCode.should.equal 201

        describe "Requests with a wrong token", ->

            it "When application try to request DS", (done) ->
                data =
                    test: "test"
                client.setBasicAuth "test", "wrong-token"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @err = err
                    @res = res
                    done()

            it "Then HTTP status 401 should be returned", ->
                @res.statusCode.should.equal 401

        describe "Requests with a wrong name", ->

            it "When application  try to request DS", (done) ->
                data =
                    test: "test"
                client.setBasicAuth "wrong-test", "token"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @err = err
                    @res = res
                    done()

            it "Then HTTP status 401 should be returned", ->
                @res.statusCode.should.equal 401


    describe "Authorization", ->

        describe "Requests with authentification but without authorization", ->

            it "When I try to create a document with docType " +
                    "UnauthorizedDocType' ", (done) ->
                data =
                    test: "test"
                    docType: "UnauthorizedDocType"
                client.setBasicAuth "test", "token"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @err = err
                    @res = res
                    done()

            it "Then HTTP status 403 should be returned", ->
                @res.statusCode.should.equal 403

        describe "Requests with authentification and authorization", ->

            it "When I try to create a document with docType " +
                    "UnauthorizedDocType' ", (done) ->
                data =
                    test: "test"
                    docType: "Authorized"
                client.setBasicAuth "test", "token"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @err = err
                    @res = res
                    done()

            it "Then HTTP status 201 should be returned", ->
                @res.statusCode.should.equal 201