module.exports = (compound) ->
    return if process.env.NODE_ENV is 'test'
    process.on 'uncaughtException', (err) ->
        console.error err
        console.error err.stack
