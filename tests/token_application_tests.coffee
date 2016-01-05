should = require('chai').Should()
helpers = require './helpers'

db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()
client = helpers.getClient()

# helpers
cleanRequest = ->
    delete @body
    delete @res


describe "Token of applications handling tests", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before helpers.startApp
    after helpers.stopApp

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

            before (done) ->
                data =
                    "name": "test-app"
                    "slug": "test-app"
                    "state": "installed"
                    "password": "secret"
                    "permissions":
                        "all":
                            "description": "This application needs ..."
                    "docType": "Application"
                client.setBasicAuth "home", "token"
                client.post 'access/', data, done

            it "When I send a request to post an application", (done) ->
                data =
                    "name": "test"
                    "slug": "test"
                    "state": "installed"
                    "docType": "Application"
                client.setBasicAuth "home", "token"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @err = err
                    @res = res
                    access =
                        'slug': data.slug
                        'app': body._id
                        "password": "token"
                        "permissions":
                            "Authorized":
                                "description": "This application needs ..."
                    client.post 'access/', access, (err, res, body) ->
                        done()

            it "Then no error should be returned", ->
                should.equal @err, null

            it "And HTTP status 201 should be returned", ->
                @res.statusCode.should.equal 201

            it "And Access is created", (done)->
                client.setBasicAuth "test-app", 'secret'
                client.post "request/access/byApp/", key: @body._id, (err, res, body) ->
                    access = body[0].value
                    access.docType.should.equal 'Access'
                    access.token.should.equal 'token'
                    access.login.should.equal 'test'
                    access.permissions.Authorized.description.should.equal "This application needs ..."
                    done()

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

            it "When application try to request DS", (done) ->
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

    describe "Modify application", ->

        describe "Access update", ->

            it "When I send a request to modify an application", (done) ->
                data =
                    "name": "test-2"
                    "slug": "test-2"
                    "state": "installed"
                    "docType": "Application"
                client.setBasicAuth "home", "token"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    access =
                        app: body._id
                        slug: 'test-2'
                        password: "token-2"
                        permissions:
                            "Authorized":
                                "description": "This application needs ..."
                    client.post 'access/', access, (err, res, access) =>
                        access =
                            name: 'test-3'
                            slug: 'test-3'
                            password: 'token-3'
                            permissions:
                                "Authorized-2":
                                    "description": "This application needs ..."
                        client.put "access/#{body._id}/", access, (err, res, body) =>
                            @err = err
                            @res = res
                            done()

            it "Then no error should be returned", ->
                should.equal @err, null

            it "And HTTP status 200 should be returned", ->
                @res.statusCode.should.equal 200

            it "And Access is created", (done)->
                client.setBasicAuth "test-app", 'secret'
                console.log @body._id
                client.post "request/access/byApp/", key:@body._id, (err, res, body) ->
                    access = body[0].value
                    access.docType.should.equal 'Access'
                    access.token.should.equal 'token-3'
                    access.login.should.equal 'test-3'
                    access.permissions['Authorized-2'].description.should.equal "This application needs ..."
                    done()


        describe "Requests with old token", ->

            it "When application try to request DS", (done) ->
                data =
                    test: "test"
                client.setBasicAuth "test-2", "token-2"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @err = err
                    @res = res
                    done()

            it "Then HTTP status 401 should be returned", ->
                @res.statusCode.should.equal 401

        describe "Requests with new token", ->

            it "When application try to request DS", (done) ->
                data =
                    test: "test"
                client.setBasicAuth "test-3", "token-3"
                client.post 'data/', data, (err, res, body) =>
                    @body = body
                    @err = err
                    @res = res
                    done()

            it "Then HTTP status 201 should be returned", ->
                @res.statusCode.should.equal 201
