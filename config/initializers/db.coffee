# Create cozy database if it does not exist.
db_create = ->
    db = require('../../helpers/db_connect_helper').db_connect()

    db.exists (err, exists) ->
        if err
            console.log "Error:", err
        else if exists
            railway.logger.write "Database #{db.name} on", \
                    "#{db.connection.host}:#{db.connection.port} found."
        else
            railway.logger.write "Database #{db.name} on", \
                    "#{db.connection.host}:#{db.connection.port} doesn't exist."
            db.create ->
                railway.logger.write console.log "Database #{db.name} on", \
                        "#{db.connection.host}:#{db.connection.port} created."
                return

db_create()
