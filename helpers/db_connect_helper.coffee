cradle = require 'cradle'
fs = require 'fs'
S = require 'string'

initLogCouchdb = ->
    data = fs.readFileSync '/usr/local/couchDB/log.txt'
    lines = S(data.toString('utf8')).lines()
    return lines

setup_credentials =  ->
    #default credentials
    credentials = {
        host : 'localhost',
        port : '5984',
        cache : false,
        raw: false
        db: 'cozy'
    }

    logCouchdb = initLogCouchdb()

    # credentials retrieved by environment variable
    if process.env.VCAP_SERVICES?
        env = JSON.parse process.env.VCAP_SERVICES
        couch = env['couchdb-1.2'][0]['credentials']
        credentials.hostname = couch.hostname ? 'localhost'
        credentials.host = couch.host ? '127.0.0.1'
        credentials.port = couch.port ? '5984'
        credentials.db = couch.name ? 'cozy'
        if logCouchdb[0]? and logCouchdb[1]?
            credentials.auth = \
                    {username: logCouchdb[0], password: logCouchdb[1]}

    return credentials

#console.log JSON.stringify setup_credentials(), null, 4

exports.db_connect = ->
    credentials = setup_credentials()
    connection = new cradle.Connection credentials

    db = connection.database credentials.db
    return db
