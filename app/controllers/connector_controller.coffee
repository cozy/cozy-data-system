load 'application'

Client = require("request-json").JsonClient
if process.env.NODE_ENV is "test"
    client = new Client("http://localhost:9092/")
else
    client = new Client("http://localhost:9102/")
client = new Client("http://localhost:9102/")

# POST /connectors/bank/:name
# Returns data extracted with connector name. Credentials are required.
action 'bank', ->
    if body.login? and body.password?
        path = "connectors/bank/#{params.name}/"
        client.post path, body, (err, res, resBody) ->
            if err
                send 500
            else if not res?
                send 500
            else if res.statusCode != 200
                send resBody, res.statusCode
            else
                send resBody
    else
        send "Credentials are not sent.", 400
