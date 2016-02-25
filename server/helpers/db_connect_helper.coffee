cradle = require 'cradle-pouchdb-server'
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

setup_credentials = ->
    #default credentials
    credentials = {
        host : process.env.COUCH_HOST or 'localhost',
        port : process.env.COUCH_PORT or '5984',
        cache : false,
        raw: false
        db: process.env.DB_NAME or 'cozy'
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

exports.db_connect = ->
    if not db?
        credentials = setup_credentials()
        connection = new cradle.Connection credentials
        db = connection.database credentials.db

    return db
