should = require('chai').Should()
async = require('async')
helpers = require('./helpers')

db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()
client = helpers.getClient()

randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

describe "Filter handling tests: ", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before (done) ->
        data =
            email: "test@cozycloud.cc"
            timezone: "Europe/Paris"
            password: "password"
            docType: "User"
        db.save '102', data, done

    before (done) ->
        client.setBasicAuth "home", "token"
        done()

    before helpers.startApp
    after helpers.stopApp


    before ->
        @filterName = "home-my_device"
        @filterBody =
            "#{@filterName}": Object.toString.apply (doc) ->
                doc.type == 'marsupial'
            password: "password"
        @url = "/filters/#{@filterName}"
        @id = "_design/filter-home-#{@filterName}"
    after ->
        delete @filterName
        delete @url
        delete @id
        delete @filterBody

    describe "[Create]", ->

        describe "Can't create a filter if authentication is invalid", ->

            it "When I send a request to create a filter with invalid token", \
                    (done) ->
                client.setBasicAuth "home", "token-invalid"
                client.post @url, {"filters": @filterBody}, \
                    (error, response, body) =>
                        @response = response
                        @body = body
                        done()

            it "Then HTTP status 403 should be returned", ->
                @response.statusCode.should.equal 403

            it "The error message is explicit", ->
                @body.should.have.property "error", \
                    "Application is not authorized"
                client.setBasicAuth "home", "token"

        describe "Create a new filter", ->

            it "When I send a request to create a filter", (done) ->
                client.post @url, {"filters": @filterBody}, \
                        (error, response, body) =>
                    @response = response
                    @body = body
                    done()

            it "Then HTTP status 201 should be returned", ->
                @response.statusCode.should.equal 201

            it "Then _id should be returned", ->
                @body.should.have.property "_id", @id

        describe "Can't create same filter", ->
            it "When I resend a request to create a filter", (done) ->
                client.post @url, @filterBody, (error, response, body) =>
                    @response = response
                    @body = body
                    done()

            it "Then HTTP status 409 should be returned", ->
                @response.statusCode.should.equal 409

            it "The error message is explicit", ->
                @body.should.have.property "error", \
                        "The document already exists."


    describe "[Find]", ->

        describe "Can't find a filter if authentication is invalid", ->

            it "When I send a request to find a filter with invalid token", \
                    (done) ->
                client.setBasicAuth "home", "token-invalid"
                client.get @url, (error, response, body) =>
                    @response = response
                    @body = body
                    done()

            it "Then HTTP status 403 should be returned", ->
                @response.statusCode.should.equal 403

            it "The error message is explicit", ->
                @body.should.have.property "error", \
                    "Application is not authorized"
                client.setBasicAuth "home", "token"

        describe "Find an existence filter", ->

            it "Then the doc with this _id should exist in Database", (done) ->
                client.get @url, (error, response, body) =>
                    @response = response
                    @body = body
                    body._id.should.be.equal @id
                    done()

            it "Then HTTP status 200 should be returned", ->
                @response.statusCode.should.equal 200

            it "Then the doc in DB should equal the sent Document", ->
                @body.should.have.property "filters", @filterBody["filters"]

        describe "Find an non existence filter", ->

            it "The doc with this _id shouldn't exist in Database", (done) ->
                client.get "#{@url}-error", (error, response, body) =>
                    @response = response
                    @body = body
                    done()

            it "Then HTTP status 404 should be returned", ->
                @response.statusCode.should.equal 404

            it "The error message is explicit", ->
                @body.should.have.property "error", "not_found: missing"


    describe "[Update]", ->

        describe "Can't update a filter if authentication is invalid", ->

            it "When I send a request to update a filter with invalid token", \
                    (done) ->
                client.setBasicAuth "home", "token-invalid"
                client.put @url, {"filters":"created_value"}, \
                        (error, response, body) =>
                    @response = response
                    @body = body
                    done()

            it "Then HTTP status 403 should be returned", ->
                @response.statusCode.should.equal 403

            it "The error message is explicit", ->
                @body.should.have.property "error", \
                    "Application is not authorized"
                client.setBasicAuth "home", "token"

        describe "Try to Update a filter", ->

            it "When I send a request to update a filter", (done) ->
                client.put @url, {"filters":"created_value"}, \
                        (error, response, body) =>
                    @body = body
                    @response = response
                    done()

            it "Then HTTP status 200 should be returned", ->
                @response.statusCode.should.equal 200

            it "The body message is explicit",  ->
                @body.success.should.be.true

            it "The doc in DB shouldn't equal to original filter", (done) ->
                client.get @url, (error, response, body) =>
                    body.should.have.property "filters"
                    body.filters.should.not.equal @filterBody["filters"]
                    done()


    describe "[Delete]", ->

        describe "Can't delete a filter if authentication is invalid", ->

            it "When I send a request to delete  a filter with invalid token", \
                    (done) ->
                client.setBasicAuth "home", "token-invalid"
                client.put @url, {"filters":"created_value"}, \
                        (error, response, body) =>
                    @response = response
                    @body = body
                    done()

            it "Then HTTP status 403 should be returned", ->
                @response.statusCode.should.equal 403

            it "The error message is explicit", ->
                @body.should.have.property "error", \
                    "Application is not authorized"
                client.setBasicAuth "home", "token"

        describe "Delete a filter that is not in Database", ->

            it "When I send a request to delete a non existing filter", \
                    (done) ->
                client.del "#{@url}-error", (error, response, body) =>
                    @response = response
                    @body = body
                    done()

            it "Then HTTP status 404 should be returned", ->
                @response.statusCode.should.equal 404

            it "The error message is explicit", ->
                @body.should.have.property "error", "not_found: missing"

        describe "Delete a filter that is in Database", ->

            it "When I send a request to delete a filter", (done) ->
                client.del @url, (error, response, body) =>
                    @response = response
                    @body = body
                    done()

            it "Then HTTP status 200 should be returned", ->
                @response.statusCode.should.equal 200

            it "The body message is explicit", ->
                @body.success.should.be.true
