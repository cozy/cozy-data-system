exec = require('child_process').exec
fs = require 'fs'
S = require 'string'

module.exports = (compound) ->
    Feed = require('../../helpers/db_feed_helper')
    db = require('../../helpers/db_connect_helper').db_connect()
    
    app = compound.app

    initLogCouchdb = ->
        data = fs.readFileSync '/etc/cozy/couchdb.login'
        lines = S(data.toString('utf8')).lines()
        return lines
          
    app.feed = new Feed(app)

    db_ensure = ->
        db.exists (err, exists) ->
            if err
                compound.logger.write "Error:", err
                feed_start()
            else if exists
                compound.logger.write "Database #{db.name} on", \
                    "#{db.connection.host}:#{db.connection.port} found."
                feed_start()
            else
                db_create()

    db_create = ->
        compound.logger.write "Database #{db.name} on", \
                "#{db.connection.host}:#{db.connection.port} doesn't exist."
        logCouchdb = initLogCouchdb()
        db.create (err) ->
            if err
                compound.logger.write console.log "Error on ", \
                    "database creation : #{err}"
            else
                command = 'curl -X PUT http://127.0.0.1:5984/cozy/_security 
                    -u ' + logCouchdb[0] + ":" + logCouchdb[1] + ' -d \'{\"
                    admins\":{\"names\":[\"' + logCouchdb[0] + '\"], \"roles
                    \":[]},\"readers\":{\"names\":[\"' + logCouchdb[0] + 
                    '\"],\"roles\":[]}}\''
                exec command, (err,res, body) ->
                    if err
                        compound.logger.write console.log "Error on ", \
                            "database creation : #{err}"
                    else
                        compound.logger.write console.log "Database #{db.name} on", \
                            "#{db.connection.host}:#{db.connection.port} created."
            feed_start()

    feed_start = ->
        app.feed.startListening(db)
        app.emit 'db ready'
        # this event is used in test to wait for db initialization
        # with compound 1.1.5-21+, we should make this initializer async

    db_ensure()
        
