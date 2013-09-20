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
    before (done) ->
        db.destroy ->
            db.create ->
                data =
                    email: "user@cozycloud.cc"
                    timezone: "Europe/Paris"
                    password: "password"
                    docType: "User"
                db.save '102', data, (err, res, body) ->
                    done()

    before helpers.instantiateApp

    after  helpers.closeApp

    after (done) ->
        db.destroy ->
            db.create (err) ->
                console.log err if err
                done()


    describe "Send an email without an attributes", ->

        describe "Send an email without email: ", ->

            it "When I send a request to send email", (done) ->
                data =
                    from: "Cozy-test <test@cozycloud.cc>"
                    subject: "Wrong test"
                    content: "This mail has a wrong email address"
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
                    content: "This mail has a wrong email address"
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
                    content: "This mail has a wrong email address"
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
