#!/usr/bin/env coffee

app = module.exports = (params) ->
    params = params || {}
    # specify current dir as default root of server
    params.root = params.root || __dirname
    return require('compound').createServer(params)

if not module.parent
    port = process.env.PORT || 9101
    host = process.env.HOST || "127.0.0.1"
    server = app()
    process.env.ENV_VARIABLE = server.set('env')
    server.listen port, host, ->
        msg = "Compound server listening on #{host}:#{port} within " + 
                "#{server.set('env')} environment"
        console.log msg
