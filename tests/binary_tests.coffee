should = require('chai').Should()
fs = require 'fs'
Client = require('request-json').JsonClient
helpers = require './helpers'
getLostBinaries = require('../server/lib/init').getLostBinaries

# connection to DB for "hand work"
db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()

serverUrl = "http://#{helpers.options.serverHost}:#{helpers.options.serverPort}/"

describe "Binaries", ->

    # Clear DB, create a new one, then init data for tests.
    before helpers.clearDB db
    before (done) ->
        db.save '321', value: "val", done

    before helpers.startApp

    # Start application before starting tests.
    before (done) ->
        @client = new Client serverUrl
        @client.setBasicAuth "home", "token"
        files = fs.readdirSync '/tmp'
        @nbOfFileInTmpFolder = files.length
        done()

    after helpers.stopApp

    describe "Add a binary", ->

        it "When I post an attachment to an unexisting document", (done) ->
            @client.sendFile "data/123/binaries/", "./tests/fixtures/test.png", \
                            (err, res, body) =>
                console.log err if err
                @response = res
                done()

        it "Then I got a 404 response", ->
            @response.statusCode.should.equal 404

        it "When I post an attachment", (done) ->
            @client.sendFile "data/321/binaries/", "./tests/fixtures/test.png", \
                            (err, res, body) =>
                console.log err if err?
                @response = res
                done()

        it "Then I got a success response", ->
            @response.statusCode.should.equal 201

        it "And the file doesn't stay in the ./tmp folder", ->
            files = fs.readdirSync '/tmp'
            @nbOfFileInTmpFolder.should.equal files.length

        it "And id and revision of binary should be updated", (done)->
            @client.get "data/321/", (err, res, body) =>
                console.log err if err
                id = body.binary["test.png"].id
                rev = body.binary["test.png"].rev
                db.get id, (err, body) ->
                    body._rev.should.be.equal rev
                    done()

        it "When I post an attachment with a complex name", (done) ->
            path = "data/321/binaries/"
            file = "./tests/fixtures/test.png"
            name = name: "Drôle de fichier ひらが envoyé.png"
            @client.sendFile path, file, name, (err, res, body) =>
                console.log err if err?
                @response = res
                done()

        it "Then I got a success response", ->
            @response.statusCode.should.equal 201

        it "And the file doesn't stay in the ./tmp folder", ->
            files = fs.readdirSync '/tmp'
            @nbOfFileInTmpFolder.should.equal files.length

        it "And id and revision of binary should be updated", (done)->
            @client.get "data/321/", (err, res, body) =>
                console.log err if err
                id = body.binary["Drôle de fichier ひらが envoyé.png"].id
                rev = body.binary["Drôle de fichier ひらが envoyé.png"].rev
                db.get id, (err, body) ->
                    body._rev.should.be.equal rev
                    done()

    describe "Retrieve a binary", ->

        it "When I claim this binary", (done) ->
            @client = new Client serverUrl
            @client.setBasicAuth "home", "token"
            @client.saveFile "data/321/binaries/test.png", \
                             './tests/fixtures/test-get.png', -> done()

        it "I got the same file I attached before", (done) ->
            @timeout 5000
            setTimeout ->
                fileStats = fs.statSync './tests/fixtures/test.png'
                resultStats = fs.statSync './tests/fixtures/test-get.png'
                resultStats.size.should.equal fileStats.size
                done()
            , 2000

        it "When I claim the weird binary", (done) ->
            @client = new Client serverUrl
            @client.setBasicAuth "home", "token"
            name = encodeURIComponent "Drôle de fichier ひらが envoyé.png"
            file = './tests/fixtures/test-get2.png'
            @client.saveFile "data/321/binaries/#{name}", file, -> done()

        it "I got the same file I attached before", (done) ->
            @timeout 5000
            setTimeout ->
                fileStats = fs.statSync './tests/fixtures/test.png'
                resultStats = fs.statSync './tests/fixtures/test-get2.png'
                resultStats.size.should.equal fileStats.size
                done()
            , 2000

    describe "Remove an attachment", ->

        it "When I remove this binary", (done) ->
            delete @response
            @client.del 'data/321/binaries/test.png', (err, res, body) =>
                @response = res
                done()

        it "Then I have a success response", ->
            @response.statusCode.should.equal 204

        it "When I claim this attachment", (done) ->
            delete @response
            @client.get 'data/321/binaries/test.png', (err, res, body) =>
                @response = res
                done()

        it "And I got a 404 response", ->
            @response.statusCode.should.equal 404

        it "And binary of data should be deleted", (done) ->
            @client.get 'data/321/', (err, res, body) =>
                should.not.exist body.binary["test.png"]
                done()

    describe "Convert attachment to binary", ->
        it "When I create a document with two attachments", (done) ->
            db.save '321', value: "val", (err, res, body) =>
                path = "data/321/attachments/"
                file = "./tests/fixtures/test.png"
                @client.sendFile path, file, (err, res, body) =>
                    file = "./tests/fixtures/test-get.png"
                    @client.sendFile path, file, (err, res, body) =>
                        done()

        it "And I convert document", (done) ->
            @client.get 'data/321/binaries/convert', (err, res, body) ->
                @err = err
                done()

        it "Then document should have only binary", (done) ->
            @client.get 'data/321/', (err, res, doc) =>
                should.exist doc.binary
                should.not.exist doc._attachment
                should.exist doc.binary['test.png']
                should.exist doc.binary['test-get.png']
                @binary1 = doc.binary['test.png'].id
                @binary2 = doc.binary['test-get.png'].id
                done()

        it "And add an application to access to binary", (done) ->
            app =
                "name": "test"
                "slug": "test"
                "state": "installed"
                "password": "secret"
                "permissions":
                    "All":
                        "description": "This application needs manage binary because ..."
                "docType": "Application"
            @client.post 'data/', app, (err, res, doc) =>
                @client.setBasicAuth 'test', 'secret'
                done()

        it "And document wich contain first binary should exist", (done) ->
            @client.setBasicAuth 'test', 'secret'
            @client.get "data/#{@binary1}/", (err, res, doc) =>
                should.exist doc._attachments
                should.exist doc._attachments['test.png']
                should.exist doc.docType
                doc.docType.should.equal 'Binary'
                done()

        it "And document wich contain second binary should exist", (done) ->
            @client.get "data/#{@binary2}/", (err, res, doc) ->
                should.exist doc._attachments
                should.exist doc._attachments['test-get.png']
                should.exist doc.docType
                doc.docType.should.equal 'Binary'
                done()

    describe "Binary shared between two documents (manual deletion)", ->
        it "When I create a file document and a photo with same binary", (done) ->
            file =
                docType: "File"
                name: "test"
                path : ""
            @client.post 'data/333/',file, (err, res, body) =>
                @client.sendFile "data/333/binaries/", "./tests/fixtures/test.png", \
                            (err, res, body) =>
                    @client.get 'data/333/', (err, res, file) =>
                        photo =
                            docType: "photo"
                            title: "test"
                            binary: file.binary
                        @bin_id = file.binary['test.png'].id
                        @client.post 'data/444/', photo, (err, res, body) =>
                            done()

        it "Then I delete binary from file document", (done) ->
            @client.del 'data/333/binaries/test.png', (err, res, body) ->
                done()

        it "And binary should not be deleted and file hasn't binary", (done)->
            @client.get 'data/333/', (err, res, file) =>
                should.not.exist file.binary['test.png']
                @client.get "data/#{@bin_id}/", (err, res, bin) =>
                    should.not.exist err
                    should.exist bin._attachments
                    done()

        it "And I remove binary from photo", (done) ->
            @client.del 'data/444/binaries/test.png', (err, res, body) ->
                done()

        it "And binary should be deleted and photo hasn't binary", (done)->
            @client.get 'data/444/', (err, res, photo) =>
                should.not.exist photo.binary['test.png']
                @client.get "data/#{@bin_id}/", (err, res, bin) =>
                    should.exist bin.error
                    bin.error.should.equal 'not_found: deleted'
                    done()


    describe "Binary shared between two documents (automatic deletion)", ->
        it "When I create a file document and a photo with same binary", (done) ->
            file =
                docType: "File"
                name: "test"
                path : ""
            @client.post 'data/111/',file, (err, res, body) =>
                @client.sendFile "data/111/binaries/", "./tests/fixtures/test.png", \
                            (err, res, body) =>
                    @client.get 'data/111/', (err, res, file) =>
                        photo =
                            docType: "photo"
                            title: "test"
                            binary: file.binary
                        @bin_id = file.binary['test.png'].id
                        @client.post 'data/222/', photo, (err, res, body) =>
                            done()

        it "Then I delete file document", (done) ->
            @client.del 'data/111/', (err, res, body) ->
                done()

        it "And binary should not be deleted", (done)->
            setTimeout () =>
                @client.get "data/#{@bin_id}/", (err, res, bin) =>
                    should.not.exist err
                    should.exist bin._attachments
                    done()
            , 1000

        it "And I remove photo", (done) ->
            @client.del 'data/222/', (err, res, body) ->
                done()

        it "And binary should be deleted", (done)->
            setTimeout () =>
                @client.get "data/#{@bin_id}/", (err, res, bin) =>
                    should.exist bin.error
                    bin.error.should.equal 'not_found: deleted'
                    done()
            , 1000

    describe 'Test module which get all lost binaries', ->

        describe 'Binary not linked to a document', ->

            it 'When I add binary in database', (done) ->
                binary =
                    docType: "Binary"
                @client.post 'data/123/',binary, (err, res, body) =>
                    should.not.exist err
                    done()

            it 'Then I get all binaries lost', (done) ->
                getLostBinaries (binaries) =>
                    @binaries = binaries
                    done()

            it 'And binary should be in list', ->
                test = '123' in @binaries
                test.should.equal true


        describe 'Binary linked to a document', ->

            it 'When I add binary in database', (done) ->
                file =
                    docType: "File"
                    name: "test"
                    path : ""
                @client.post 'data/444/',file, (err, res, body) =>
                    @client.sendFile "data/444/binaries/", "./tests/fixtures/test.png", \
                                (err, res, body) =>
                        done()

            it 'Then I get all binaries lost', (done) ->
                getLostBinaries (binaries) =>
                    @binaries = binaries
                    done()

            it 'And binary should not be in list', (done) ->
                @client.get 'data/444/', (err, res, body) =>
                    binaryId = body.binary['test.png'].id
                    test = binaryId in @binaries
                    test.should.equal false
                    done()


        describe 'Binary linked to a document without docType', ->

            it 'When I add binary in database', (done) ->
                file =
                    name: "test"
                    path : ""
                @client.post 'data/456/',file, (err, res, body) =>
                    @client.sendFile "data/456/binaries/", "./tests/fixtures/test.png", \
                                (err, res, body) =>
                        done()

            it 'Then I get all binaries lost', (done) ->
                getLostBinaries (binaries) =>
                    @binaries = binaries
                    done()

            it 'And binary should not be in list', (done) ->
                @client.get 'data/456/', (err, res, body) =>
                    binaryId = body.binary['test.png'].id
                    test = binaryId in @binaries
                    test.should.equal false
                    done()


        describe 'Binary linked to a document with random docType', ->

            it 'When I add binary in database', (done) ->
                file =
                    docType: "Random-test"
                    name: "test"
                    path : ""
                @client.post 'data/789/',file, (err, res, body) =>
                    @client.sendFile "data/789/binaries/", "./tests/fixtures/test.png", \
                                (err, res, body) =>
                        done()

            it 'Then I get all binaries lost', (done) ->
                getLostBinaries (binaries) =>
                    @binaries = binaries
                    done()

            it 'And binary should not be in list', (done) ->
                @client.get 'data/789/', (err, res, body) =>
                    binaryId = body.binary['test.png'].id
                    test = binaryId in @binaries
                    test.should.equal false
                    done()

        describe 'Binary linked to two documents', ->

            it 'When I add binary in database', (done) ->
                @client.get 'data/444/', (err, res, body) =>
                    file =
                        docType: "File"
                        name: "test2"
                        path : ""
                        binary : body.binary
                    @client.post 'data/555/', file, (err, res, body) =>
                        done()

            it 'Then I get all binaries lost', (done) ->
                getLostBinaries (binaries) =>
                    @binaries = binaries
                    done()

            it 'And binary should not be in list', (done) ->
                @client.get 'data/444/', (err, res, body) =>
                    binaryId = body.binary['test.png'].id
                    test = binaryId in @binaries
                    test.should.equal false
                    done()

        describe 'Document linked to two binaries', ->

            it 'When I add binary in database', (done) ->
                file =
                    docType: "File"
                    name: "test"
                    path : ""
                @client.post 'data/666/',file, (err, res, body) =>
                    @client.sendFile "data/666/binaries/", "./tests/fixtures/test.png", \
                                (err, res, body) =>
                        @client.sendFile "data/666/binaries/", "./tests/fixtures/test-get.png", \
                                    (err, res, body) =>
                            done()

            it 'Then I get all binaries lost', (done) ->
                getLostBinaries (binaries) =>
                    @binaries = binaries
                    done()

            it 'And two binaries should not be in list', (done) ->
                @client.get 'data/666/', (err, res, body) =>
                    # Check first binary
                    binaryId = body.binary['test.png'].id
                    test = binaryId in @binaries
                    test.should.equal false
                    # Check second binary
                    binaryId = body.binary['test-get.png'].id
                    test = binaryId in @binaries
                    test.should.equal false
                    done()

describe "Binary not linked to a document (automatic deletion)", ->
    before (done) ->
        helpers.startApp () =>
            @client = new Client serverUrl
            @client.setBasicAuth "home", "token"
            done()

    it "When I create a binary without document", (done) ->
        app =
            "name": "test"
            "slug": "test"
            "state": "installed"
            "password": "secret"
            "permissions":
                "All":
                    "description": "This application needs manage binary because ..."
            "docType": "Application"
        @client.post 'data/', app, (err, res, doc) =>
            @client.setBasicAuth 'test', 'secret'
            binary =
                docType: "Binary"
            @client.post 'data/100/',binary, (err, res, body) =>
                file =
                    docType: "File"
                    name: "test"
                    path : ""
                @client.post 'data/111/',file, (err, res, body) =>
                    @client.sendFile "data/111/binaries/", "./tests/fixtures/test.png", \
                                (err, res, body) =>
                        res.statusCode.should.equal 201
                        done()

    it "When I restart data-system", (done)->
        helpers.stopApp () =>
            helpers.startApp () ->
                done()


    it "And binary not linked should be deleted", (done) ->
        setTimeout () =>
            @client = new Client serverUrl
            @client.setBasicAuth 'test', 'secret'
            @client.get "data/100/", (err, res, bin) =>
                should.exist bin.error
                bin.error.should.equal 'not_found: deleted'
                done()
        , 1000

    it "And binary linked should not be deleted", (done) ->
        setTimeout () =>
            @client = new Client serverUrl
            @client.setBasicAuth 'test', 'secret'
            @client.get "data/111/", (err, res, bin) =>
                should.exist bin
                should.not.exist err
                should.not.exist bin.error
                helpers.stopApp () ->
                    done()
        , 1000