cradle = require 'cradle'
S = require 'string'
fs = require 'fs'

initLoginCouch = ->
    data = fs.readFileSync '/etc/cozy/couchdb.login'
    lines = S(data.toString('utf8')).lines()
    return lines

setup_credentials = ->
    #default credentials
    credentials = {
        host : 'localhost',
        port : '5984',
        cache : false,
        raw: false
        db: 'cozy'
    }


    # credentials retrieved by environment variable
    if process.env.VCAP_SERVICES?
        env = JSON.parse process.env.VCAP_SERVICES
        couch = env['couchdb-1.2'][0]['credentials']
        credentials.hostname = couch.hostname ? 'localhost'
        credentials.host = couch.host ? '127.0.0.1'
        credentials.port = couch.port ? '5984'
        credentials.db = couch.name ? 'cozy'

    if process.env.ENV_VARIABLE is 'production'
        loginCouch = initLoginCouch()
        credentials.auth = {
            username: loginCouch[0]
            password: loginCouch[1]
        }

        # credentials retrieved by environment variable
        if process.env.VCAP_SERVICES?
            credentials.auth = {}
            credentials.auth.username = couch.username ? loginCouch[0]
            credentials.auth.password = couch.password ? loginCouch[1]

    return credentials

#console.log JSON.stringify setup_credentials(), null, 4

db = null #singleton connection

exports.db_connect = ->
    if not db?
        credentials = setup_credentials()
        connection = new cradle.Connection credentials
        db = connection.database credentials.db

    return db