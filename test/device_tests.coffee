should = require('chai').Should()
fs = require 'fs'
helpers = require('./helpers')
Client = require("request-json").JsonClient
db = require('../helpers/db_connect_helper').db_connect()

describe "Device", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before (done) ->
        db.save '321', value: "val", done

    before helpers.instantiateApp

    # Start application before starting tests.
    before (done) ->
        @client = new Client "http://localhost:8888/"
        @client.setBasicAuth "proxy", "token"
        done()

    after helpers.after db

    describe "Add a device", ->

        it "When I post a device", (done) ->
            @client.post "device/", login: "work", (err, res, body) =>
                console.log err if err
                @response = res
                @id = body.id
                done()

        it "Then I got a 200 response", ->
            @response.statusCode.should.equal 200

    describe "Try to add a similar device", ->

        it "When I post a device", (done) ->
            @client.post "device/", login: "work", (err, res, body) =>
                console.log err if err
                @response = res
                @body = body
                done()

        it "Then I got a 400 response", ->
            @response.statusCode.should.equal 400

        it "Add I got a error message correct", ->
            @body.msg = "This default filter doesn't exist"

    describe "Remove an existing device", ->

        it "When I post a device", (done) ->
            @client.post "device/", login: "phone", (err, res, body) =>
                console.log err if err
                @response = res
                @id = body.id
                done()

        it "And I remove a device", (done) ->
            console.log @id
            @client.del "device/#{@id}/", (err, res, body) =>
                console.log err if err
                @response = res
                done()

        it "Then I got a 204 response", ->
            @response.statusCode.should.equal 204    

        it "And I remove a device", (done) ->
            @client.del "device/#{@id}/", (err, res, body) =>
                console.log err if err
                @response = res
                done()

        it "And I got a 404 response", ->
            @response.statusCode.should.equal 404
