should = require('chai').Should()
fakeServer = require('./helpers').fakeServer
helpers = require('./helpers')

Client = require('request-json').JsonClient
client = new Client 'http://localhost:8888/'
db = require('../helpers/db_connect_helper').db_connect()

describe 'Connectors - Bank / Accounts', ->

    before helpers.clearDB db
    before helpers.instantiateApp

    before (done) ->
        accounts = [
            { label: 'compte courant', balance: '1000' }
            { label: 'livret A', balance: '2000' }
        ]
        operations = [
            account: 'livret A'
            label: 'remise cheque'
            amount: '50.00'
            date: '2012-12-31T00:00:00Z'
        ,
            account: 'livret A'
            label: 'achat supermarche'
            amount: '-100.00'
            date: '2012-12-31T00:00:00Z'
        ]
        indexer = fakeServer null, 200, (url, body) ->

            if url is '/connectors/bank/bnp/'
                should.exist body.login
                should.exist body.password
                return accounts
            if url is '/connectors/bank/bnp/history/'
                should.exist body.login
                should.exist body.password
                return operations

        @indexerServer = indexer.listen 9092, done

    after ->
        @indexerServer.close()

    after helpers.closeApp
    after helpers.clearDB db


    describe 'Bank accounts data retrieval', ->

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


    describe 'Bank operations data retrieval', ->

        it 'When I send a request for my bank account data', (done) ->
            data =
                login: 'me'
                password: 'secret'
            client.post 'connectors/bank/bnp/history/', data, (err, res, body) =>
                @res = res
                @body = body
                done()

        it 'Then I got my account balances', ->
            @res.statusCode.should.equal 200
            @body.length.should.equal 2
            @body[0].label.should.equal 'remise cheque'
            @body[0].amount.should.equal '50.00'
            @body[0].date.should.equal '2012-12-31T00:00:00Z'
            @body[0].account.should.equal 'livret A'
            @body[1].label.should.equal 'achat supermarche'
            @body[1].amount.should.equal '-100.00'
            @body[1].date.should.equal '2012-12-31T00:00:00Z'
            @body[1].account.should.equal 'livret A'
