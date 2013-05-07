fs = require 'fs'
S = require 'string'
Client = require("request-json").JsonClient
couchUrl = "http://localhost:5984/"
couchClient = new Client couchUrl


module.exports = (compound) ->
    Feed = require('../../helpers/db_feed_helper')
    db = require('../../helpers/db_connect_helper').db_connect()
    
    app = compound.app

    ### Helpers ###

    initLoginCouch = ->
        data = fs.readFileSync '/etc/cozy/couchdb.login'
        lines = S(data.toString('utf8')).lines()
        return lines

    # Add admin to cozy database
    # Result : Unauthorized applications cannot read on cozy
    addCozyAdmin = (callback) ->
        loginCouch = initLoginCouch()
        data =
            "admins":
                "names":[loginCouch[0]]
                "roles":[]
            "readers":
                "names":[loginCouch[0]]
                "roles":[]
        couchClient.setBasicAuth(loginCouch[0],loginCouch[1])
        couchClient.put 'cozy/_security', data, (err, res, body)->
            callback err

    ### Logger ###

    logFound = ->
        console.info "Database #{db.name} on #{db.connection.host}" + 
            ":#{db.connection.port} found."
        feed_start()

    logError = ->
        console.info "Error on database creation : #{err}"
        feed_start()

    logCreated = ->
        console.info "Database #{db.name} on" +
            " #{db.connection.host}:#{db.connection.port} created." 
        feed_start()

    ### Check existence of cozy database or create it ###
          
    app.feed = new Feed(app)

    db_ensure = ->
        db.exists (err, exists) ->
            if err
                compound.logger.write "Error:", err
                feed_start()
            else if exists
                if process.env.NODE_ENV is 'production'
                    loginCouch = initLoginCouch()
                    couchClient.setBasicAuth(loginCouch[0],loginCouch[1])
                    couchClient.get 'cozy/_security', (err, res, body)=>
                        if not body.admins? or 
                                body.admins.names[0] isnt loginCouch[0]
                            addCozyAdmin (err) =>
                                if err
                                    compound.logger.write "Error on database" +
                                    " Add admin : #{err}"
                                    feed_start()
                                else
                                    logFound()
                        else
                            logFound()
                else
                    logFound()
            else
                db_create()

    db_create = ->
        compound.logger.write "Database #{db.name} on" +
                " #{db.connection.host}:#{db.connection.port} doesn't exist."
        db.create (err) ->
            if err
                logError()
            else if (process.env.NODE_ENV is 'production')                     
                addCozyAdmin (err) =>
                    if err
                        logError()
                    else
                        logCreated
            else
                logCreated

    feed_start = ->
        app.feed.startListening(db)
        app.emit 'db ready'
        # this event is used in test to wait for db initialization
        # with compound 1.1.5-21+, we should make this initializer async

    db_ensure()
        
