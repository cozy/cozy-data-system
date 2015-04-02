should = require('chai').Should()
fs = require 'fs'
helpers = require './helpers'

# connection to DB for "hand work"
db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()

client = helpers.getClient()
client.setBasicAuth "proxy", "token"

describe "Device", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before (done) ->
        db.save '321', value: "val", done

    before helpers.startApp
    before (done) ->
        data =
            "name": "test"
            "slug": "test"
            "state": "installed"
            "password": "secret"
            "permissions":
                "all":
                    "description": "This application needs ..."
            "docType": "Application"
        client.setBasicAuth "home", "token"
        client.post 'data/', data, done

    after helpers.stopApp

    deviceID = null

    describe "Add a device", ->

        it "When I post a device", (done) ->
            client.setBasicAuth 'test', 'secret'
            setTimeout () =>
                client.post "device/", login: "work", (err, res, body) =>
                    console.log err if err
                    @response = res
                    deviceID = body.id
                    done()
            , 1000

        it "Then I got a 200 response", ->
            @response.statusCode.should.equal 200

        it "An access should be createed", (done) ->
            client.get "data/#{deviceID}/", (err, res, body) ->
                body.access.should.exist
                client.get "data/#{body.access}/", (err, res, body) ->
                    body.should.have.property 'docType'
                    body.docType.should.equal 'Access'
                    body.should.have.property 'login'
                    body.login.should.equal 'work'
                    body.should.have.property 'token'
                    body.should.have.property 'permissions'
                    body.permissions.should.have.property 'file'
                    body.permissions.should.have.property 'folder'
                    body.permissions.should.have.property 'binary'
                    body.permissions.should.have.property 'notification'
                    body.permissions.should.have.property 'contact'
                    done()

    describe "Try to add a similar device", ->

        it "When I post a device", (done) ->
            client.post "device/", login: "work", (err, res, body) =>
                console.log err if err
                @response = res
                @body = body
                done()

        it "Then I got a 400 response", ->
            @response.statusCode.should.equal 400

        it "Add I got a error message correct", ->
            @body.msg = "This default filter doesn't exist"


    describe "Add a desktop device", ->

        it "When I post a device", (done) ->
            client.setBasicAuth 'test', 'secret'
            setTimeout () =>
                client.post "device/", {login: "desktop", type: "desktop"}, (err, res, body) =>
                    console.log err if err
                    @response = res
                    @id = body.id
                    done()
            , 1000

        it "Then I got a 200 response", ->
            @response.statusCode.should.equal 200

        it "An access should be createed", (done) ->
            client.get "data/#{@id}/", (err, res, body) ->
                body.access.should.exist
                client.get "data/#{body.access}/", (err, res, body) ->
                    body.should.have.property 'docType'
                    body.docType.should.equal 'Access'
                    body.should.have.property 'login'
                    body.login.should.equal 'desktop'
                    body.should.have.property 'token'
                    body.should.have.property 'permissions'
                    body.permissions.should.have.property 'file'
                    body.permissions.should.have.property 'folder'
                    body.permissions.should.have.property 'binary'
                    body.permissions.should.not.have.property 'notification'
                    body.permissions.should.not.have.property 'contact'
                    done()

    describe "Remove an existing device", ->

        it "When I post a device", (done) ->
            client.post "device/", login: "phone", (err, res, body) =>
                console.log err if err
                @response = res
                deviceID = body.id
                @access = body.access
                done()

        it "Then I got a 200 response", ->
            @response.statusCode.should.equal 200

        it "And I remove a device", (done) ->
            client.del "device/#{deviceID}/", (err, res, body) =>
                console.log err if err
                @response = res
                done()

        it "And I got a 200 response", ->
            @response.statusCode.should.equal 200

        it 'And device should be removed', (done) ->
            client.get "data/#{deviceID}/", (err, res, body) =>
                console.log err if err
                res.statusCode.should.equal 404
                done()

        it 'And access should be removed', (done) ->
            client.get "data/#{@access}/", (err, res, body) =>
                console.log err if err
                res.statusCode.should.equal 404
                done()

    describe "Try to add a device without name", ->

        it "When I tryy to post a device", (done) ->
            client.post "device/", {}, (err, res, body) =>
                console.log err if err
                @response = res
                done()

        it "Then I got a 400 response", ->
            @response.statusCode.should.equal 400