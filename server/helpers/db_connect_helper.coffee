cradle = require 'cradle'
S = require 'string'
fs = require 'fs'

initLoginCouch = ->
    try
        data = fs.readFileSync '/etc/cozy/couchdb.login'
    catch err
        console.log "No CouchDB credentials file found: /etc/cozy/couchdb.login"
        process.exit 1
    lines = S(data.toString('utf8')).lines()
    return lines

setup_credentials = (dbName) ->
    #default credentials
    credentials = {
        host : process.env.COUCH_HOST or 'localhost',
        port : process.env.COUCH_PORT or '5984',
        cache : false,
        raw: false
        db: process.env.DB_NAME or dbName
    }

    # credentials retrieved by environment variable
    if process.env.NODE_ENV is 'production'
        loginCouch = initLoginCouch()
        credentials.auth = {
            username: loginCouch[0]
            password: loginCouch[1]
        }

    return credentials

db = null #singleton connection
replicator = null #replicator connection

exports.db_connect = ->
    if not db?
        credentials = setup_credentials 'cozy'
        connection = new cradle.Connection credentials
        db = connection.database credentials.db

    return db

exports.db_replicator_connect = ->
    if not replicator?
        credentials = setup_credentials '_replicator'
        connection = new cradle.Connection credentials
        replicator = connection.database credentials.db

    return replicator
