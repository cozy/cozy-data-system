Client = require("request-json").JsonClient

if process.env.INDEXER_PORT
    port = process.env.INDEXER_PORT
else if process.env.NODE_ENV is "test"
    port = 9092
else
    port = 9102

indexerHost = process.env.INDEXER_HOST or 'localhost'

module.exports = new Client "http://#{indexerHost}:#{port}/"