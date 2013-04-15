exec = require('child_process').exec
fs = require 'fs'
S = require 'string'

module.exports = (compound) ->
    app = compound.app

    initLogCouchdb = ->
        data = fs.readFileSync '/usr/local/couchDB/log.txt'
        lines = S(data.toString('utf8')).lines()
        return lines
          
    # Create cozy database if it does not exist.
    db_create = ->
        db = require('../../helpers/db_connect_helper').db_connect()

        db.exists (err, exists) ->
            if err
                console.log "Error:", err
            else if exists
                compound.logger.write "Database #{db.name} on", \
                    "#{db.connection.host}:#{db.connection.port} found."
            else
                compound.logger.write "Database #{db.name} on", \
                    "#{db.connection.host}:#{db.connection.port} doesn't exist."
                db.create ->
                    logCouchdb = initLogCouchdb()
                    command = 'curl -X PUT http://127.0.0.1:5984/cozy/_security 
                        -u ' + logCouchdb[0] + ":" + logCouchdb[1] + ' -d \'{\"
                        admins\":{\"names\":[\"' + logCouchdb[0] + '\"], \"roles
                        \":[]},\"readers\":{\"names\":[\"' + logCouchdb[0] + 
                        '\"],\"roles\":[]}}\''
                    exec command, (err,res, body) ->
                        if err
                            compound.logger.write "Database #{db.name} on", \
                                "#{db.connection.host}:#{db.connection.port} 
                                failed in creation."
                            return
                        else
                            compound.logger.write "Database #{db.name} on", \
                                "#{db.connection.host}:#{db.connection.port} 
                                created."
                            return

    db_create()
