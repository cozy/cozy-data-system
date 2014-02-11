Client = require("request-json").JsonClient
checkPermissions = require('../lib/token').checkDocType

if process.env.NODE_ENV is "test"
    client = new Client "http://localhost:9092/"
else
    client = new Client "http://localhost:9102/"

## Actions

# POST /connectors/bank/:name
# Returns data extracted with connector name. Credentials are required.
module.exports.bank = (req, res) ->
    if req.body.login? and req.body.password?
        path = "connectors/bank/#{req.params.name}/"
        client.post path, req.body, (err, response, body) ->
            if err?
                res.send 500, error: err
            else if not response?
                res.send 500, error: "Response not found"
            else if response.statusCode isnt 200
                res.send response.statusCode, body
            else
                res.send 200, body
    else
        res.send 400, error: "Credentials are not sent."

module.exports.bankHistory = (req, res) ->
    if req.body.login? and req.body.password?
        path = "connectors/bank/#{req.params.name}/history/"
        client.post path, req.body, (err, response, body) ->
            if err?
                res.send 500, error: err
            else if not response?
                res.send 500, error: "Res not found"
            else if response.statusCode isnt 200
                res.send response.statusCode, body
            else
                res.send 200, body
    else
        res.send 400, error: "Credentials are not sent."
