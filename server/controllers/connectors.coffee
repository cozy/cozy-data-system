client = require '../lib/indexer'

## Actions

# POST /connectors/bank/:name
# Returns data extracted with connector name. Credentials are required.
module.exports.bank = (req, res, next) ->
    if req.body.login? and req.body.password?
        path = "connectors/bank/#{req.params.name}/"
        client.post path, req.body, (err, response, body) ->
            if err?
                next new Error err
            else if not response?
                next new Error "Response not found"
            else if response.statusCode isnt 200
                res.send response.statusCode, body
            else
                res.send 200, body
    else
        err = new Error "Login and password fields missing in request's body."
        err.status = 400
        next err

module.exports.bankHistory = (req, res, next) ->
    if req.body.login? and req.body.password?
        path = "connectors/bank/#{req.params.name}/history/"
        client.post path, req.body, (err, response, body) ->
            if err?
                next new Error err
            else if not response?
                next new Error "Response not found"
            else if response.statusCode isnt 200
                res.send response.statusCode, body
            else
                res.send 200, body
    else
        err = new Error "Login and password fields missing in request's body."
        err.status = 400
        next err
