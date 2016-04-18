should = require('chai').Should()
helpers = require('./helpers')
sinon = require 'sinon'
_ = require 'lodash'


db = require("#{helpers.prefix}server/helpers/db_connect_helper").db_connect()
sharing = require "#{helpers.prefix}server/controllers/sharing"
Sharing = require "#{helpers.prefix}server/lib/sharing"
libToken = require "#{helpers.prefix}server/lib/token"


client = helpers.getClient()
client.setBasicAuth "home", "token"


describe "Sharing controller tests:", ->

    before helpers.clearDB db
    before (done) ->
        helpers.startApp(done)

    after (done) ->
        helpers.stopApp(done)


    describe "create module", ->

        # Correct sharing structure
        share =
            desc: 'description'
            rules: [ {id: 1, docType: 'event'}, {id: 2, docType: 'Tasky'} ]
            targets: [{recipientUrl: 'url1.com'}, {recipientUrl: 'url2.com'}, \
                {recipientUrl: 'url3.com'}]
            continuous: true


        it 'should return a bad request when the body is empty', (done) ->
            data = {}
            client.post 'services/sharing/', data, (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal 'Body is incomplete'
                done()

        it 'should return a bad request when no target is specified', (done) ->
            data = _.cloneDeep share
            data.targets = []
            client.post 'services/sharing/', data, (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal 'Body is incomplete'
                done()

        it 'should return a bad request when a target does not have an url',
        (done) ->
            data = _.cloneDeep share
            data.targets = [{recipientUrl: 'url1.com'}, \
                            {recipientUrl: 'url2.com'},
                            {recipientUrl : ''}]

            client.post 'services/sharing/', data, (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal 'No url specified'
                done()

        it 'should return a bad request when no rules are specified', (done) ->
            data = _.cloneDeep share
            data.rules = []
            client.post 'services/sharing/', data, (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal 'Body is incomplete'
                done()

        it 'should return a bad request when a rule does not have an id',
        (done) ->
            data = _.cloneDeep share
            data.rules = [{id: 1, docType: 'event'}, \
                          {id: '', docType: 'Tasky'}]
            client.post 'services/sharing/', data, (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal 'Incorrect rule detected'
                done()

        it 'should return a bad request when a rule does not have a docType',
        (done) ->
            data = _.cloneDeep share
            data.rules = [{id: 1, docType: 'event'}, {id: 2}]
            client.post 'services/sharing/', data, (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal 'Incorrect rule detected'
                done()

        it 'should set the shareID, the docType to "sharing" and generate
        preTokens', (done) ->
            req = body: _.cloneDeep share
            res = {}
            sharing.create req, res, ->
                req.share.should.exist
                req.share.shareID.should.exist
                req.share.docType.should.equal "sharing"
                for target in req.share.targets
                    should.exist(target.preToken)
                done()


    describe 'sendSharingRequests module', ->

        # Correct sharing structure normally obtained as a result of `create`
        share =
            desc      : 'description'
            docType   : 'sharing'
            shareID   : '1aqwzsx'
            rules     : [{id: 1, docType: 'event'}, {id: 2, docType: 'Tasky'}]
            targets   : [{recipientUrl: 'url1.com', preToken: 'preToken1'}, \
                         {recipientUrl: 'url2.com', preToken: 'preToken2'}, \
                         {recipientUrl: 'url3.com', preToken: 'preToken3'}]
            continuous: true

        # Spies on the parameters given to the `notifyTarget` module
        spyRoute   = {}
        spyRequest = {}

        # We stub the `notifyTarget` module to avoid calling it (if so it would
        # try to request the url we declare in the share object).
        stubFn = (route, request, callback) ->
            spyRoute   = route
            spyRequest = request
            callback null # to mimick success
        notifyStub = {}

        beforeEach (done) ->
            notifyStub = sinon.stub Sharing, "notifyTarget", stubFn
            done()

        afterEach (done) ->
            notifyStub.restore()
            done()


        it 'should send a request to all targets', (done) ->
            req = share: _.cloneDeep share

            # XXX This is ugly...is there a better way? (or is it not ugly?)
            #
            # The last call issued by the `sendSharingRequests` module is
            # `res.status(200).send success: true` which is Express logic. That
            # means that there is a hidden `next` callback, somewhere. Since
            # for the purpose of the test we don't want said callback to take
            # place we have to stub it. But that's not all: we also have to
            # find a way to mimic the `next` callback. That is why the `done()`
            # is inserted here, preceeded by the test. It is this `done()` that
            # is actually called and not the one in the sendSharingRequests if
            # everything goes well.
            resStub =
                status: (_) ->
                    send: (_) ->
                        notifyStub.callCount.should.equal share.targets.length
                        done()

            sharing.sendSharingRequests req, resStub, ->
                done()

        it 'should define a correct request', (done) ->
            req = share: _.cloneDeep share

            # XXX That's probably is ugly
            # stub `res.status(200).send success:true` call
            resStub =
                status: (_) ->
                    send: (_) ->
                        # XXX I cannot get this to work so...
                        #spyRequest.should.have.all.keys(['url', 'preToken',
                            #'shareID', 'rules', 'desc'])
                        # ... I test everything separatly. Since there are 3
                        # targets spyRequest should only contain the url of the
                        # third target
                        should.exist(spyRequest)
                        spyRequest.recipientUrl.should.equal 'url3.com'
                        spyRequest.preToken.should.equal 'preToken3'
                        spyRequest.shareID.should.equal req.share.shareID
                        spyRequest.rules.should.deep.equal req.share.rules
                        spyRequest.desc.should.equal req.share.desc

                        done()

            sharing.sendSharingRequests req, resStub, ->
                done()

        it 'should send the requests on services/sharing/request', (done) ->
            req = share: _.cloneDeep share
            # we only let one target: spyRoute is set with it
            req.share.targets = [{recipientUrl: 'url1.com', \
                                  preToken: 'preToken1'}]

            # XXX Once again it kinda is ugly...
            # stub `res.status(200).send success:true` call
            #
            # Here not only do we stub the Express logic but we also make a
            # test on a global variable `spyRoute` that was declared at the
            # beginning of the `describe` block. I guess it could be done in a
            # more elegant manner but I don't know how (just yet).
            resStub =
                status: (_) ->
                    send: (_) ->
                        spyRoute.should.equal 'services/sharing/request'
                        done()

            sharing.sendSharingRequests req, resStub, ->
                done()

        it 'should return an error when notifyTarget failed', (done) ->
            # remove previously defined stub...
            notifyStub.restore()
            # ... and generate a new one that mimicks failure
            stubFn = (route, request, callback) ->
                callback "Error" # to mimick failure we return something
            notifyStub = sinon.stub Sharing, "notifyTarget", stubFn

            # We want a correct structure
            req = share: _.cloneDeep share
            res = {} # no need to mimic Express since it should not get called

            sharing.sendSharingRequests req, res, (err) ->
                err.should.equal "Error"
                done()


    describe 'delete module', ->

        # We declare a phony document that we'll return when needed
        doc = targets: [{recipientUrl: 'url1.com', preToken: 'preToken1'}]
        # fake request to mimick call `client.del "services/sharing/103"`
        req = params: { id: 103 }

        # stubs of get/remove methods of database
        dbGetStub    = {}
        dbRemoveStub = {}

        # The use of `(before|after)Each` instead of `(before|after)` might not
        # be efficient but if we want a clean stub before every test...
        beforeEach (done) ->
            dbGetStub    = sinon.stub db, "get", (id, callback) ->
                callback null, _.cloneDeep doc

            dbRemoveStub = sinon.stub db, "remove", (id, callback) ->
                callback null, true

            done()

        afterEach (done) ->
            dbRemoveStub.restore()
            dbGetStub.restore()
            done()


        it 'should return an error when the document does not exist in the db',
        (done) ->
            dbGetStub.restore() # we want the correct behavior, not the stub
            client.del "services/sharing/103", (err, res, body) ->
                res.statusCode.should.equal 404
                # Funny thing: the message CouchDB sends us to inform us about
                # an error is "stringified" twice hence the following check.
                res.body.should.equal '{"error":"not_found: missing"}'
                done()


        it 'should remove the document from the database', (done) ->
            sharing.delete req, {}, ->
                dbRemoveStub.callCount.should.equal 1
                done()

        it 'should transmit the targets and the shareID to the next callback',
        (done) ->
            sharing.delete req, {}, ->
                should.exist req.share
                should.exist req.share.targets
                should.exist req.share.shareID
                req.share.shareID.should.equal req.params.id
                req.share.targets.should.be.deep.equal doc.targets
                done()


    describe 'stopReplications module', ->

        # Phony document
        doc = targets: [{recipientUrl: 'url1.com', preToken: 'preToken1'},\
                        {recipientUrl: 'url2.com', token: 'token2', repID: 2},
                        {recipientUrl: 'url3.com', token: 'token3', repID: 3},
                        {recipientUrl: 'url4.com', token: 'token4', repID: 4},
                        {recipientUrl: 'url5.com', preToken: 'preToken5'}]
        # req to mimick result of preceeding call
        req = share:
            shareID: 103
            targets: doc.targets

        # Stub of Sharing.cancelReplication (lib/sharing.coffee)
        cancelReplicationFn          = (id, callback) -> callback null
        sharingCancelReplicationStub = {}

        before (done) ->
            sharingCancelReplicationStub   = sinon.stub Sharing, \
                "cancelReplication", cancelReplicationFn
            done()

        after (done) ->
            sharingCancelReplicationStub.restore()
            done()

        it 'should cancel the replication for all targets that have a
        replication id', (done) ->
            sharing.stopReplications req, {}, ->
                sharingCancelReplicationStub.callCount.should.equal 3
                done()

        it 'should throw an error when a replication could not be cancelled',
        (done) ->
            sharingCancelReplicationStub.restore() # cancel previous stub
            # create "new" stub that produces an error
            cancelReplicationFn = (id, callback) -> callback "Error"
            sharingCancelReplicationStub = sinon.stub Sharing, \
                "cancelReplication", cancelReplicationFn

            sharing.stopReplications req, {}, (err) ->
                should.exist err
                err.should.equal "Error"
                done()


    describe 'sendDeleteNotifications module', ->

        # Phony document
        targets =
            [{recipientUrl: 'url1.com', preToken:'preToken1'},
             {recipientUrl: 'url2.com', token:'token2', repID: 2},
             {recipientUrl: 'url3.com', preToken:'preToken3'},
             {recipientUrl: 'url4.com', token:'token4', repID: 4},
             {recipientUrl: 'url5.com', preToken:'preToken5'}]
        urls = (target.recipientUrl for target in targets)     # extract urls
        tokens = (target.token for target in targets) # extract tokens and pre
        tokens = tokens.concat (target.preToken for target in targets)
        # req to mimick result of preceeding calls
        req = share:
            shareID: 103
            targets: targets

        # sharing.notifyTarget stub (lib/sharing.coffee).
        # Returning `null` mimicks success.
        notifyTargetFn   = (route, notification, callback) -> callback null
        notifyTargetStub = {}

        beforeEach (done) ->
            notifyTargetStub = sinon.stub Sharing, "notifyTarget",
                notifyTargetFn
            done()

        afterEach (done) ->
            notifyTargetStub.restore()
            done()

        it 'should define the notifications correctly and call the route
        "services/sharing/cancel"', (done) ->
            notifyTargetStub.restore() # cancel stub
            # change to a custom stub that tests the values passed
            testNotifyTargetFn = (route, notification, callback) ->
                route.should.equal "services/sharing/cancel"
                urls.should.contain notification.recipientUrl
                should.exist notification.token
                tokens.should.contain notification.token
                notification.shareID.should.equal req.share.shareID
                notification.desc.should.equal "The sharing
                    #{req.share.shareID} has been deleted"
                callback null

            notifyTargetStub = sinon.stub Sharing, "notifyTarget",
                testNotifyTargetFn

            # mimick Express `res.send`
            resStub =
                status: (_) ->
                    send: (_) ->
                        done()

            # and finally call the test
            sharing.sendDeleteNotifications req, resStub, ->
                done()

        it 'should send notifications to all targets that have a token and a
        repID', (done) ->
            # mimick Express `res.send`
            resStub =
                status: (_) ->
                    send: (_) ->
                        notifyTargetStub.callCount.should.equal targets.length
                        done()

            # and finally call the test
            sharing.sendDeleteNotifications req, resStub, ->
                done()

        it 'should return an error when a notification could not be sent',
        (done) ->
            notifyTargetStub.restore() # cancel stub
            errNotifyTargetFn = (route, notification, callback) ->
                callback "Error"
            notifyTargetStub = sinon.stub Sharing, "notifyTarget",
                errNotifyTargetFn

            sharing.sendDeleteNotifications req, {}, (err) ->
                should.exist err
                err.should.equal "Error"
                done()


    describe 'handleRecipientAnswer module', ->

        # Correct answer structure expected
        answer =
            id          : 'IdOfTheRecipientShareDocument'
            shareID     : 'IdOfTheSharerShareDocument'
            accepted    : true
            preToken    : 'preToken'
            recipientUrl: 'urlOfTheRecipient'
            sharerUrl   : 'urlOfTheSharer'
            rules       : [{id: 1, docType: 'event'}, {id: 2, docType: 'event'}]

        # We stub the addAccess module from lib/token.coffee: we return an
        # error to avoid having our code run entirely if a test fails.
        addAccessStub = {}
        # Same for the remove function
        dbRemoveStub  = {}

        before (done) ->
            addAccessStub = sinon.stub libToken, "addAccess",
                (access, callback) ->
                    callback new Error "libToken.addAccess"

            dbRemoveStub = sinon.stub db, "remove", (id, callback) ->
                callback new Error "db.remove"

            done()

        after (done) ->
            addAccessStub.restore()
            dbRemoveStub.restore()
            done()


        it 'should return an error when the req structure is incorrect: body is
        empty', (done) ->
            data = {}
            client.post 'services/sharing/sendAnswer/', data,
            (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal "Bad request: body is incomplete"
                done()

        it 'should return an error when the req structure is incorrect: id is
        missing or empty', (done) ->
            data = _.cloneDeep answer
            data.id = undefined
            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal "Bad request: body is incomplete"
                done()

        it 'should return an error when the req structure is incorrect: shareID
        is missing or empty', (done) ->
            data = _.cloneDeep answer
            data.shareID = null
            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal "Bad request: body is incomplete"
                done()

        it 'should return an error when the req structure is incorrect: accepted
        is missing or empty', (done) ->
            data = _.cloneDeep answer
            data.accepted = ''
            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal "Bad request: body is incomplete"
                done()

        it 'should return an error when the req structure is incorrect: preToken
        is missing or empty', (done) ->
            data = _.cloneDeep answer
            data.preToken = ''
            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal "Bad request: body is incomplete"
                done()

        it 'should return an error when the req structure is incorrect: url is
        missing or empty', (done) ->
            data = _.cloneDeep answer
            data.recipientUrl = null
            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal "Bad request: body is incomplete"
                done()

        it 'should return an error when the req structure is incorrect:
        sharerUrl is missing or empty', (done) ->
            data = _.cloneDeep answer
            data.sharerUrl = null
            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal "Bad request: body is incomplete"
                done()

        it 'should return an error when the req structure is incorrect: rules is
        missing or empty', (done) ->
            data = _.cloneDeep answer
            data.rules = []
            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal "Bad request: body is incomplete"
                done()

        it 'should return an error when the req structure is incorrect: a rule
        is missing an id', (done) ->
            data = _.cloneDeep answer
            data.rules = [{id: 1, docType: 'event'},{id: '', docType: 'event'}]
            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal "Bad request: incorrect rule
                    detected"
                done()

        it 'should return an error when the req structure is incorrect: a rule
        is missing a docType', (done) ->
            data = _.cloneDeep answer
            data.rules = [{id: 1, docType: 'event'},{id: 2}]
            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.statusCode.should.equal 400
                res.body.error.should.equal "Bad request: incorrect rule
                    detected"
                done()

        it 'should return an error when addAccess failed', (done) ->
            data = _.cloneDeep answer
            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.body.error.should.equal "libToken.addAccess"
                done()

        it 'should remove the sharing document when accepted is false and return
        an error when the document could not be removed', (done) ->
            # set accepted to false
            data = _.cloneDeep answer
            data.accepted = false

            # The dbRemoveStub is called during this test, there is a test
            # inside of it that checks that the correct id is passed

            client.post "services/sharing/sendAnswer/", data,
            (err, res, body) ->
                res.body.error.should.equal "db.remove"
                done()

        it 'should call the next callback when req structure is ok: accepted is
        false', (done) ->
            req = body: _.cloneDeep answer
            req.body.accepted = false # simulate refusal

            # Cancel previous stub of remove for one that doesn't fail
            dbRemoveStub.restore()
            dbRemoveFnOk = (id, callback) ->
                callback null
            dbRemoveStub = sinon.stub db, "remove", dbRemoveFnOk

            sharing.handleRecipientAnswer req, {}, ->
                should.exist req.share
                req.share.should.deep.equal req.body
                done()

        it 'should call the next callback when req structure is ok: accepted is
        true', (done) ->
            req = body: _.cloneDeep answer # copy of correct structure
            addAccessStub.restore() # cancel previous stub
            addAccessFnOk = (access, callback) ->
                callback null # No error is set, addAccess doesn't fail
            addAccessStub = sinon.stub libToken, "addAccess", addAccessFnOk

            sharing.handleRecipientAnswer req, {}, ->
                should.exist req.share
                should.exist req.share.token
                req.share.id.should.equal answer.id
                req.share.shareID.should.equal answer.shareID
                req.share.preToken.should.equal answer.preToken
                req.share.accepted.should.equal answer.accepted
                req.share.recipientUrl.should.equal answer.recipientUrl
                req.share.sharerUrl.should.equal answer.sharerUrl
                req.share.rules.should.deep.equal answer.rules
                done()


    describe 'sendAnswer module', ->

        # Correct answer structure expected
        req = share:
            {
                id          : 'IdOfTheRecipientShareDocument'
                shareID     : 'IdOfTheSharerShareDocument'
                accepted    : true
                preToken    : 'preToken'
                recipientUrl: 'urlOfTheRecipient'
                sharerUrl   : 'urlOfTheSharer'
                rules       : [{id: 1, docType: 'event'}, \
                               {id: 2, docType: 'event'}]
                token       : 'token'
            }

        # Stub of notifyTarget module: we make it fail for now, we'll redefine
        # the stub once we want it to pass
        notifyTargetStub = {}

        beforeEach (done) ->
            notifyTargetStub = sinon.stub Sharing, "notifyTarget",
                (route, data, callback) ->
                    callback new Error "Sharing.notifyTarget"

            done()

        afterEach (done) ->
            notifyTargetStub.restore()
            done()


        it 'should return an error when notifyTarget failed', (done) ->
            sharing.sendAnswer req, {}, (err) ->
                err.should.deep.equal new Error "Sharing.notifyTarget"
                done()

        it 'should notify the target', (done) ->
            sharing.sendAnswer req, {}, ->
                notifyTargetStub.callCount.should.equal 1
                done()

        it 'should send success when notifyTarget succeeded', (done) ->
            # We change the stub for one that succeeds
            notifyTargetStub.restore()
            notifyTargetFnOk = (route, data, callback) ->
                callback null
            notifyTargetStub = sinon.stub Sharing, "notifyTarget",
                notifyTargetFnOk

            res =
                status: (value) ->
                    value.should.equal 200
                    send: (obj) ->
                        obj.should.deep.equal success: true
                        done()

            sharing.sendAnswer req, res, ->
                done()


    describe 'validateTarget module', ->

        # Expected answer structure
        req = body: {
            shareID     : 'IdOfTheSharerShareDocument'
            accepted    : true
            preToken    : 'preToken'
            sharerUrl   : 'urlOfTheSharer'
            recipientUrl: 'urlOfTheRecipient'
            token       : 'token'
        }

        doc_orig =
            _id: 12345
            targets: [{recipientUrl: 'foo', token: 'tok1', repID: 1},\
                      {recipientUrl: 'bar', token: 'tok2', repID: 2},
                      {recipientUrl: 'urlOfTheRecipient', preToken: 'preToken'}]
            rules: [{id: 1, docType: 'event'}, {id: 2, docType: 'event'}]
            continuous: false

        # Stubs of get/merge db methods
        dbGetStub = {}
        dbMergeStub = {}

        beforeEach (done) ->
            dbGetStub = sinon.stub db, "get", (id, callback) ->
                doc_copy = _.cloneDeep doc_orig
                callback null, doc_copy

            dbMergeStub = sinon.stub db, "merge", (id, doc, callback) ->
                callback new Error "db.merge"

            done()

        afterEach (done) ->
            dbGetStub.restore()
            dbMergeStub.restore()
            done()


        it 'should return an error when the body is missing', (done) ->
            data = {}
            client.post 'services/sharing/answer/', data, (err, res, body) ->
                res.body.error.should.equal "Bad request: body is incomplete"
                res.statusCode.should.equal 400
                done()

        it 'should return an error when the body is incomplete: shareID is
        missing/empty', (done) ->
            data = _.cloneDeep req.body
            data.shareID = null
            client.post 'services/sharing/answer/', data, (err, res, body) ->
                res.body.error.should.equal "Bad request: body is incomplete"
                res.statusCode.should.equal 400
                done()

        it 'should return an error when the body is incomplete: recipientUrl is
        missing/empty', (done) ->
            data = _.cloneDeep req.body
            data.recipientUrl = undefined
            client.post 'services/sharing/answer/', data, (err, res, body) ->
                res.body.error.should.equal "Bad request: body is incomplete"
                res.statusCode.should.equal 400
                done()

        it 'should return an error when the body is incomplete: accepted is
        missing/empty', (done) ->
            data = _.cloneDeep req.body
            data.accepted = ''
            client.post 'services/sharing/answer/', data, (err, res, body) ->
                res.body.error.should.equal "Bad request: body is incomplete"
                res.statusCode.should.equal 400
                done()

        it 'should return an error when the body is incomplete: preToken is
        missing/empty', (done) ->
            data = _.cloneDeep req.body
            data.preToken = null
            client.post 'services/sharing/answer/', data, (err, res, body) ->
                res.body.error.should.equal "Bad request: body is incomplete"
                res.statusCode.should.equal 400
                done()

        it 'should return an error when the body is incomplete: token is
        missing/empty', (done) ->
            data = _.cloneDeep req.body
            data.token = ''
            client.post 'services/sharing/answer/', data, (err, res, body) ->
                res.body.error.should.equal "Bad request: body is incomplete"
                res.statusCode.should.equal 400
                done()

        it 'should return an error when db.get failed', (done) ->
            dbGetStub.restore() # cancel default stub
            dbGetStub = sinon.stub db, "get", (id, callback) ->
                callback new Error "db.get"

            sharing.validateTarget req, {}, (err) ->
                err.should.deep.equal new Error "db.get"
                done()

        it 'should return an error when the target was not found for this
        share', (done) ->
            dbGetStub.restore() # cancel default stub that fails
            # define a new stub that does not contain the url of the answer
            # structure
            dbGetStub = sinon.stub db, "get", (id, callback) ->
                doc = targets: [{recipientUrl: 'foo'}, {recipientUrl: 'bar'},\
                                {recipientUrl: 'baz'}]
                callback null, doc

            sharing.validateTarget req, {}, (err) ->
                notFoundErr = new Error "urlOfTheRecipient not found for this
                    sharing"
                notFoundErr.status = 404
                err.should.deep.equal notFoundErr
                done()

        it 'should return an error when the preToken for the target does not
        match the one stored in the database', (done) ->
            dbGetStub.restore() # cancel default stub
            dbGetStub = sinon.stub db, "get", (id, callback) ->
                doc = targets: [{recipientUrl: 'foo', preToken: 'preTokenFoo'},\
                                {recipientUrl: 'urlOfTheRecipient',\
                                 preToken: 'nope'}]
                callback null, doc

            sharing.validateTarget req, {}, (err) ->
                unauthErr = new Error "Unauthorized"
                unauthErr.status = 401
                err.should.deep.equal unauthErr
                done()

        it 'should return an error when the target has already answered',
        (done) ->
            dbGetStub.restore() # cancel default stub
            dbGetStub = sinon.stub db, "get", (id, callback) ->
                doc = targets: [{recipientUrl: 'foo', preToken: 'preTokenFoo'},\
                                {recipientUrl: 'urlOfTheRecipient',\
                                 token: 'token'}]
                callback null, doc

            sharing.validateTarget req, {}, (err) ->
                bisErr = new Error "The answer for this sharing has already
                    been given"
                bisErr.status = 403
                err.should.deep.equal bisErr
                done()

        it 'should return an error when merge failed', (done) ->
            sharing.validateTarget req, {}, (err) ->
                err.should.deep.equal new Error "db.merge"
                done()

        it 'should remove the `preToken` from the `target` structure when the
        share request was accepted', (done) ->
            dbMergeStub.restore() # cancel default stub
            dbMergeFn = (id, doc, callback) ->
                for target in doc.targets
                    if target.recipientUrl is 'urlOfTheRecipient'
                        should.not.exist target.preToken
                        should.exist target.token
                # we don't want the rest of the module to execute so we return
                # an error
                callback new Error "db.merge"

            dbMergeStub = sinon.stub db, "merge", dbMergeFn

            sharing.validateTarget req, {}, (err) ->
                dbMergeStub.callCount.should.equal 1
                done()

        it 'should remove the target from the `share` document when the share
        request was denied', (done) ->
            req_false = _.cloneDeep req
            req_false.body.accepted = false

            dbMergeStub.restore() # cancel default stub
            dbMergeFn = (id, doc, callback) ->
                for target in doc.targets
                    target.recipientUrl.should.not.equal req.body.recipientUrl
                # call with an error to stop execution of module
                callback new Error "db.merge"

            dbMergeStub = sinon.stub db, "merge", dbMergeFn

            sharing.validateTarget req_false, {}, (err) ->
                dbMergeStub.callCount.should.equal 1
                done()

        it 'should transmit the correct structure for the next callback',
        (done) ->
            dbMergeStub.restore() # cancel default stub
            dbMergeStub = sinon.stub db, "merge", (id, doc, callback) ->
                callback null # do nothing and return no error

            sharing.validateTarget req, {}, ->
                should.exist req.replicate
                req.replicate.target.recipientUrl.should.equal \
                    req.body.recipientUrl
                # `preToken` should not exist and `token` should since
                # `accepted` is true
                should.not.exist req.replicate.target.preToken
                should.exist req.replicate.target.token
                req.replicate.id.should.equal doc_orig._id
                req.replicate.docIDs.should.deep.equal (r.id for r in \
                    doc_orig.rules)
                req.replicate.continuous.should.equal doc_orig.continuous
                done()


    describe 'replicate module', ->

        # Correct structures expected
        req = replicate: { id        : 12345,\
                           target    : {recipientUrl: 'urlOfTheRecipient',\
                                        token: 'token'},\
                           docIDS    : [1, 2],
                           continuous: true }
        doc_orig =
            _id       : 12345
            targets   : [{recipientUrl: 'foo', preToken: 'preTokenFoo'},\
                         {recipientUrl: 'bar', preToken: 'preTokenBar'},
                         {recipientUrl: 'urlOfTheRecipient', token: 'token'}]
            rules     : [{id: 1, docType: 'event'}, {id: 2, docType: 'event'}]
            continuous: true

        # stubs
        replicateDocsStub = {}
        dbMergeStub       = {}
        dbGetStub         = {}
        res               = {}

        # Hooks
        beforeEach (done) ->
            replicateDocsStub = sinon.stub Sharing, "replicateDocs", \
                (replicate, callback) ->
                    callback null, 987 # return no error and a `repID`

            dbMergeStub = sinon.stub db, "merge", (id, doc, callback) ->
                callback null # return no error

            dbGetStub = sinon.stub db, "get", (id, callback) ->
                callback null, _.cloneDeep doc_orig # return no error

            done()

        afterEach (done) ->
            replicateDocsStub.restore()
            dbMergeStub.restore()
            dbGetStub.restore()
            done()

        it 'should replicate only when a token exists', (done) ->
            req_no_token = _.cloneDeep req
            delete req_no_token.replicate.target.token

            res =
                status: (value) ->
                    value.should.equal 200
                    send: (obj) ->
                        obj.should.deep.equal success: true
                        # replicateDocs should not be called if there is no
                        # token
                        replicateDocsStub.callCount.should.equal 0
                        done()

            sharing.replicate req_no_token, res, ->
                done()

        it 'should return an error when `Sharing.replicateDocs` failed',
        (done) ->
            replicateDocsStub.restore() # cancel default stub
            replicateDocsStub = sinon.stub Sharing, "replicateDocs", \
                (replicate, callback) ->
                    callback new Error "Sharing.replicateDocs"

            sharing.replicate req, res, (err) ->
                err.should.deep.equal new Error "Sharing.replicateDocs"
                done()

        it 'should return an error when the replication is continuous but no
        `repID` was returned by `Sharing.replicateDocs`', (done) ->
            replicateDocsStub.restore() # cancel default stub
            replicateDocsStub = sinon.stub Sharing, "replicateDocs", \
                (replicate, callback) ->
                    callback null # return no error and no `repID`

            sharing.replicate req, res, (err) ->
                errRep = new Error "Replication error"
                errRep.status = 500

                err.should.deep.equal errRep
                done()

        it 'should return an error when `db.get` failed', (done) ->
            dbGetStub.restore()
            dbGetStub = sinon.stub db, "get", (id, callback) ->
                callback new Error "db.get"

            sharing.replicate req, res, (err) ->
                err.should.deep.equal new Error "db.get"
                done()

        it 'should return an error when the `db.merge` failed', (done) ->
            dbMergeStub.restore() # cancel default stub
            dbMergeStub = sinon.stub db, "merge", (id, doc, callback) ->
                callback new Error "db.merge" # return an error...!

            sharing.replicate req, res, (err) ->
                err.should.deep.equal new Error "db.merge"
                done()

        it 'should update the `target` structure when the replication is
        continuous', (done) ->
            dbMergeStub.restore() # cancel default stub
            dbMergeStub = sinon.stub db, "merge", (id, doc, callback) ->
                for target in doc.targets
                    if target.recipientUrl is req.replicate.target.recipientUrl
                        # `987` is the repID in the default stub
                        target.repID.should.equal 987
                    else
                        should.not.exist target.repID
                # return an error to prevent the rest of the code from
                # executing
                callback new Error "db.merge"

            sharing.replicate req, res, ->
                done()

        it 'should return success when the replication is continuous and the
        `Sharing.replicateDocs` as well as the `db.merge` succeeded', (done) ->
            res =
                status: (value) ->
                    value.should.equal 200
                    send: (obj) ->
                        obj.should.deep.equal success: true
                        done()

            sharing.replicate req, res, ->
                done()

        it 'should return success when the replication is not continuous and the
        `Sharing.replicateDocs` succeeded', (done) ->
            req_no_continuous = _.cloneDeep req
            req_no_continuous.replicate.continuous = false

            res =
                status: (value) ->
                    value.should.equal 200
                    send: (obj) ->
                        obj.should.deep.equal success: true
                        dbGetStub.callCount.should.equal 0
                        done()

            sharing.replicate req_no_continuous, res, ->
                done()
