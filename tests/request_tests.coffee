should = require('chai').Should()
async = require 'async'
helpers = require './helpers'

# connection to DB for "hand work"
db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()
client = helpers.getClient()

process.env.TOKEN = "token"

# helpers

cleanRequest = ->
    delete @body
    delete @response

randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

createAuthorRequestFunction = (name) ->
    (callback) ->
        map = (doc) -> emit doc._id, doc
        view = map: map.toString()

        client.setBasicAuth "test", "token"
        client.put "request/author/#{name}/", view, callback


describe "Request handling tests", ->

    before helpers.clearDB db
    before (done) ->
        docs = []
        for num in [0..100]
            docs.push
                type: 'dumb_doc'
                num: num
                tags: ('tag'+i for i in [0..num])
        db.save docs, done
    before helpers.startApp
    after helpers.stopApp

    describe "View creation", ->
        describe "Install an application which has access to every docs", ->

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

            it "When I send a request to post a second application", (done) ->
                data =
                    "name": "test2"
                    "slug": "test2"
                    "state": "installed"
                    "password": "token2"
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

        describe "Creation of the first view + design document creation", ->
            before cleanRequest

            it "When I send a request to create view every_docs", (done) ->
                map = (doc) ->
                    emit doc._id, doc
                    return
                @viewAll = {map:map.toString()}

                client.setBasicAuth "test", "token"
                client.put 'request/all/every_docs/', @viewAll, \
                        (error, response, body) =>
                    response.statusCode.should.equal 200
                    done()

            it "Then the design document should exist and contain the view", \
                    (done) ->
                db.get '_design/all', (err, res) ->
                    should.not.exist err
                    should.exist res
                    res.views.should.have.property 'every_docs', @viewAll
                    done()

        describe "Creation of a new view", ->
            before cleanRequest

            it "When I send a request to create view even_num", (done) ->
                map = (doc) ->
                    emit doc.num, doc if (doc.num? && (doc.num % 2) is 0)
                    return
                @viewEven = {map:map.toString()}

                client.put 'request/all/even_num/', @viewEven, \
                        (error, response, body) =>
                    response.statusCode.should.equal 200
                    done()

            it "Then the design document should exist and contain the views", \
                    (done) ->
                db.get '_design/all', (err, res) ->
                    should.not.exist err
                    should.exist res
                    res.views.should.have.property 'every_docs', @viewAll
                    res.views.should.have.property 'even_num', @viewEven
                    done()

            it "When I send a request to create a complex view (with array)", (done) ->
                map = (doc) ->
                    if (doc.num? && (doc.num % 2) is 0)
                        emit ["test", doc.num, doc.num], doc
                    return
                @viewEven = map: map.toString()

                client.put 'request/all/even_num_array/', @viewEven, \
                        (error, response, body) =>
                    response.statusCode.should.equal 200
                    done()

    describe "Access to a view without option", ->
        describe "Access to a non existing view", ->
            before cleanRequest

            it "When I send a request to access view dont-exist", (done) ->
                client.post "request/all/dont-exist/", {}, \
                            (error, response, body) =>
                    @response = response
                    done()

            it "Then error 404 should be returned", ->
                @response.statusCode.should.equal 404

        describe "Access to an existing view : every_docs", (done) ->
            before cleanRequest

            it "When I send a request to access view every_docs", (done) ->
                client.post "request/all/every_docs/", {},\
                            (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 103 documents returned", ->
                @body.should.have.length 103

        describe "Access to an existing view : even_num", (done) ->
            before cleanRequest

            it "When I send a request to access view every_docs", (done) ->
                client.post "request/all/even_num/", {}, \
                            (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 51 documents returned", ->
                @body.should.have.length 51

    describe "Access to a view with option", ->
        describe "Access to a view : even_num, with key param", (done) ->
            before cleanRequest

            it "When I send a request to get doc with num = 10", (done) ->
                client.post "request/all/even_num/", key: 10, \
                            (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 1 documents returned", ->
                @body.should.have.length 1

            it "When I send a request to get doc with complex query", (done) ->
                client.post "request/all/even_num_array/", \
                    {startkey: ["test", 10], endkey: ["test", 10, {}]}, \
                            (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 1 documents returned", ->
                @body.should.have.length 1

        describe "Access to a view : even_num, with wrong key param", (done) ->
            before cleanRequest

            it "When I send a request to get doc with num = 9", (done) ->
                client.post "request/all/even_num/", key: 9, \
                            (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 0 documents returned", ->
                @body.should.have.length 0

        describe "Access to tags", ->
            before cleanRequest

            it "When I send a request to get tags", (done) ->
                @timeout 5000
                client.get "tags", (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 101 docs", ->
                @body.should.have.length 101

    describe "Deletion of docs through requests", ->

        describe "Delete a doc from a view : even_num", (done) ->
            before cleanRequest

            it "When I send a request to delete a doc from even_num", (done) ->
                client.put "request/all/even_num/destroy/", key: 10, \
                        (err, response, body) ->
                    should.not.exist err
                    should.exist response
                    response.statusCode.should.equal 204
                    done()

            it "And I send a request to get doc with num = 10", (done) ->
                client.post "request/all/even_num/", key: 10, \
                            (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 0 documents returned", ->
                @body.should.have.length 0

            it "When I send a request to delete a doc from even_num with complex query", (done) ->
                client.put "request/all/even_num_array/destroy/", \
                            {startkey: ["test", 8], endkey: ["test", 8, {}]}, \
                            (err, response, body) ->
                    response.statusCode.should.equal 204
                    should.not.exist err
                    done()

            it "And I send a request to grab all docs from even_num", (done) ->
                client.post "request/all/even_num/", {}, \
                            (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 49 documents returned", ->
                @body.should.have.length 49


        describe "Delete all doc from a view : even_num", (done) ->

            it "When I delete all docs from every_docs", (done) ->
                @timeout 5000
                client.put "request/all/even_num/destroy/", {}, \
                            (err, response, body) ->
                    response.statusCode.should.equal 204
                    should.not.exist err
                    done()

            it "And I send a request to grab all docs from even_num", (done) ->
                client.post "request/all/even_num/", {}, \
                            (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    done()

            it "Then I should have 0 documents returned", ->
                @body.should.have.length 0

    describe "Update of an existing view", ->
        describe "Redefinition of existing view even_num", ->
            before cleanRequest

            it "When I send a request to create view even_num", (done) ->
                map = (doc) ->
                    emit doc._id, doc if (doc.num? && (doc.num % 2) isnt 0)
                    return
                @viewEven = {map:map.toString()}

                client.put 'request/all/even_num/', @viewEven, \
                        (error, response, body) =>
                    response.statusCode.should.equal 200
                    done()

            it "Then the design document should exist and contain the views", \
                    (done) ->
                db.get '_design/all', (err, res) ->
                    should.not.exist err
                    should.exist res
                    res.views.should.have.property 'every_docs', @viewAll
                    res.views.should.have.property 'even_num', @viewEven
                    done()

            it "And I should retrieve the good values", (done) ->
                client.post "request/all/even_num/", {}, \
                            (error, response, body) =>
                    response.statusCode.should.equal 200
                    @body = body
                    @body.should.have.length 50
                    done()



    describe "Deletion of an existing view with conflict", ->
        before cleanRequest

        it "When I send a request to create view even_num", (done) ->
            map = (doc) ->
                emit 1, doc if (1 && (doc.num % 2) is 0)
                return
            @viewEven = map: map.toString()

            client.setBasicAuth "test2", "token2"
            client.put 'request/all/even_num/', @viewEven, \
                    (error, response, body) =>
                response.statusCode.should.equal 200
                done()

        it "When I send a request to delete view even_num", (done) ->
            client.del "request/all/even_num/", (error, response, body) =>
                response.statusCode.should.equal 204
                done()

    describe "Deletion of an existing view without conflict", ->
        before cleanRequest

        it "When I send a request to delete view even_num", (done) ->
            client.setBasicAuth "test", "token"
            client.del "request/all/every_docs/", (error, response, body) =>
                response.statusCode.should.equal 204
                done()

        it "And I send a request to access view even_num", (done) ->
            client.post "request/all/every_docs/", {},  \
                        (error, response, body) =>
                @response = response
                done()

        it "Then error 200 should be returned", ->
            @response.statusCode.should.equal 200


    describe "Create fastly three requests (concurrency test)", ->
        before cleanRequest


        it "Then I create a doument with docType 'author' ", (done) ->

            data =
                "name": "test"
                "docType": "author"
            client.post 'data/', data, (error, response, body) =>
                should.not.exist error
                done()

    describe "When I call the doctype list", ->
        it "should send me existing doctypes", (done) ->

            client.get 'doctypes', (error, response, body) ->
                should.not.exist error
                should.exist response
                response.should.have.property 'statusCode'
                response.statusCode.should.equal 200

                should.exist body
                body.length.should.eql 2
                body[0].should.eql 'Application'
                body[1].should.eql 'author'
                done()
