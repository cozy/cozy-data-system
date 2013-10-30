Client = require('request-json').JsonClient
helpers = require('./helpers')

client = new Client("http://localhost:8888/")
db = require('../helpers/db_connect_helper').db_connect()

# helpers
cleanRequest = ->
    delete @body
    delete @res


describe "Mail handling tests", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before (done) ->
        data =
            email: "user@cozycloud.cc"
            timezone: "Europe/Paris"
            password: "password"
            docType: "User"
        db.save '102', data, done

    before helpers.instantiateApp

    after helpers.after db



    describe "Send an email without an attributes", ->

        describe "Install an application which has access to every docs", ->
            before cleanRequest

        it "When I send a request to post an application", (done) ->
            data =
                "name": "test"
                "slug": "test"
                "state": "installed"
                "password": "token"
                "permissions":
                    "All":
                        "description": "This application needs manage notes because ..."
                "docType": "Application"
            client.setBasicAuth "home", "token"
            client.post 'data/', data, (err, res, body) =>
                @body = body
                @err = err
                @res = res
                done()

            it "Then no error should be returned", ->
                should.equal  @err, null

            it "And HTTP status 201 should be returned", ->
                @res.statusCode.should.equal 201


        describe "Send an email without email: ", ->

            it "When I send a request to send email", (done) ->
                data =
                    from: "Cozy-test <test@cozycloud.cc>"
                    subject: "Wrong test"
                    text: "This mail has a wrong email address"
                    html: "<p>This mail has a wrong email address</p>"
                client.setBasicAuth "test", "token"
                client.post 'mail/', data, (err, res, body) =>
                    @err = err
                    @res = res
                    @body = body
                    done()

            it "Then 400 sould be returned as error code", ->
                    @res.statusCode.should.be.equal 400
                    @body.error.should.be.exist
                    @body.error.should.be.equal 'Body has not all necessary ' +
                        'attributes'

        describe "Send an email without from: ", ->

            it "When I send a request to send email", (done) ->
                data =
                    to: "mail@cozycloud.cc"
                    subject: "Wrong test"
                    text: "This mail has a wrong email address"
                    html: "<p>This mail has a wrong email address</p>"
                client.setBasicAuth "test", "token"
                client.post 'mail/', data, (err, res, body) =>
                    @err = err
                    @res = res
                    @body = body
                    done()

            it "Then, 400 sould be returned as error code", ->
                    @res.statusCode.should.be.equal 400
                    @body.error.should.be.exist
                    @body.error.should.be.equal 'Body has not all necessary ' +
                        'attributes'

        describe "Send an email without subject: ", ->

            it "When I send a request to send email", (done) ->
                data =
                    to: "mail@cozycloud.cc"
                    from: "Cozy-test <test@cozycloud.cc>"
                    text: "This mail has a wrong email address"
                    text: "<p>This mail has a wrong email address</p>"
                client.setBasicAuth "test", "token"
                client.post 'mail/', data, (err, res, body) =>
                    @err = err
                    @res = res
                    @body = body
                    done()

            it "Then 400 sould be returned as error code", ->
                    @res.statusCode.should.be.equal 400
                    @body.error.should.be.exist
                    @body.error.should.be.equal 'Body has not all necessary ' +
                        'attributes'

        describe "Send an email without content: ", ->

            it "When I send a request to send email", (done) ->
                data =
                    to: "mail@cozycloud.cc"
                    from: "Cozy-test <test@cozycloud.cc>"
                    subject: "Wrong test"
                client.setBasicAuth "test", "token"
                client.post 'mail/', data, (err, res, body) =>
                    @err = err
                    @res = res
                    @body = body
                    done()

            it "Then 400 sould be returned as error code", ->
                    @res.statusCode.should.be.equal 400
                    @body.error.should.be.exist
                    @body.error.should.be.equal 'Body has not all necessary ' +
                        'attributes'


    ###describe "Send an email with wrong mail: ", ->

        it "When I send a request to send email", (done) ->
            data =
                to: "wrong-email-cozy"
                from: "Cozy-test <test@cozycloud.cc>"
                subject: "Wrong test"
                content: "This mail has a wrong email address"
            client.post 'mail/', data, (err, res, body) =>
                @err = err
                @res = res
                @body = body
                done()

        it "Then 500 sould be returned as error code", ->
                @res.statusCode.should.be.equal 500
                @body.error.should.be.exist
                @body.error.name.should.be.equal 'RecipientError'


    describe "Send an email: ", ->

        it "When I send a request to send email", (done) ->
            data =
                to: "test@cozycloud.cc"
                from: "Cozy-test <test@cozycloud.cc>"
                subject: "Wrong test"
                content: "This mail has a correct email address"
            client.post 'mail/', data, (err, res, body) =>
                console.log body.error
                @err = err
                @res = res
                @body = body
                done()

        it "Then 200 sould be returned as code", ->
            @res.statusCode.should.be.equal 200

    describe "Send an email to several recipients: ", ->

        it "When I send a request to send email", (done) ->
            data =
                to: "test@cozycloud.cc, other-test@cozycloud.cc"
                from: "Cozy-test <test@cozycloud.cc>"
                subject: "Wrong test"
                content: "This mail has a correct email address"
            client.post 'mail/', data, (err, res, body) =>
                @err = err
                @res = res
                @body = body
                done()

        it "Then 200 sould be returned as code", ->
            @res.statusCode.should.be.equal 200

    describe "Send an email to user: ", ->

        it "When I send a request to send email", (done) ->
            data =
                from: "Cozy-test <test@cozycloud.cc>"
                subject: "Wrong test"
                content: "This mail has a correct email address"
            client.post 'mail/to-user', data, (err, res, body) =>
                @err = err
                @res = res
                @body = body
                done()

        it "Then 200 sould be returned as code", ->
            @res.statusCode.should.be.equal 200

    describe "Send an email from user: ", ->

        it "When I send a request to send email", (done) ->
            data =
                to: "test@cozycloud.cc"
                subject: "Wrong test"
                content: "This mail has a correct email address"
            client.post 'mail/from-user', data, (err, res, body) =>
                @err = err
                @res = res
                @body = body
                done()

        it "Then 200 sould be returned as code", ->
            @res.statusCode.should.be.equal 200###
