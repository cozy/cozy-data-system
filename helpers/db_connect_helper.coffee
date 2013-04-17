cradle = require 'cradle'
fs = require 'fs'
S = require 'string'

initLogCouchdb = ->
    data = fs.readFileSync '/etc/cozy/couchdb.login'
    lines = S(data.toString('utf8')).lines()
    return lines

setup_credentials =  ->
    #default credentials

    logCouchdb = initLogCouchdb()
    credentials = {
        host : 'localhost',
        port : '5984',
        cache : false,
        raw: false
        db: 'cozy'
        auth:
            username: logCouchdb[0]
            password: logCouchdb[1]
    }

    # credentials retrieved by environment variable
    if process.env.VCAP_SERVICES?
        console.log("blabla")
        env = JSON.parse process.env.VCAP_SERVICES
        couch = env['couchdb-1.2'][0]['credentials']
        credentials.hostname = couch.hostname ? 'localhost'
        credentials.host = couch.host ? '127.0.0.1'
        credentials.port = couch.port ? '5984'
        credentials.db = couch.name ? 'cozy'
        credentials.auth = {}
        credentials.username = couch.username ? logCouchdb[0]
        credentials.password = couch.password ? logCouchdb[1]

    return credentials

#console.log JSON.stringify setup_credentials(), null, 4

db = null #singleton connection

exports.db_connect = ->
    if not db?
        credentials = setup_credentials()
        connection = new cradle.Connection credentials
        db = connection.database credentials.db

    return db
