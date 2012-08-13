cradle = require "cradle"

# Create cozy database if it does not exist.
createDb = ->
    connection = new cradle.Connection
        cache: true,
        raw: false
    db = connection.database("cozy")

    db.exists (err, exists) ->
        if err
            console.log "error", err
        else if exists
            console.log "Database Cozy found."
        else
            console.log "database does not exists."
            db.create()
createDb()

