should = require('chai').Should()
fakeServer = require('./helpers').fakeServer
helpers = require('./helpers')

Client = require('request-json').JsonClient
client = new Client 'http://localhost:8888/'

describe 'Connectors - Bank', ->

    # Start application before starting tests.
    before helpers.instantiateApp

    before ->
        data = [
            { label: 'compte courant', balance: '1000' }
            { label: 'livret A', balance: '2000' }
        ]
        indexer = fakeServer data, 200, (url, body) ->

            if url is '/connectors/bank/bnp/'
                should.exist body.login
                should.exist body.password

        @indexerServer = indexer.listen 9092

    after ->
        @indexerServer.close()

    after helpers.closeApp


    describe 'Bank account data retrieval', ->

        it 'When I send a request for my bank account data', (done) ->
            data =
                login: 'me'
                password: 'secret'
            client.setBasicAuth "home", "token"
            client.post 'connectors/bank/bnp/', data, (err, res, body) =>
                @res = res
                @body = body
                done()

        it 'Then I got my account balances', ->
            @res.statusCode.should.equal 200
            @body.length.should.equal 2
            @body[0].label.should.equal 'compte courant'
            @body[0].balance.should.equal '1000'
            @body[1].label.should.equal 'livret A'
            @body[1].balance.should.equal '2000'
