cradle = require 'cradle'

setup_credentials = ->
    #default credentials
    credentials = {
        host : 'localhost',
        port : '5984',
        cache : true,
        raw: false
        db: 'cozy'
    }


    # credentials retrieved by environment variable
    if process.env.VCAP_SERVICES?
        env = JSON.parse process.env.VCAP_SERVICES
        couch = env['couchdb-1.2.0'][0]['credentials']
        credentials.hostname = couch.hostname ? 'localhost'
        credentials.host = couch.host ? '127.0.0.1'
        credentials.port = couch.port ? '5984'
        credentials.db = couch.db ? 'cozy'
        if couch.username? and couch.password?
            credentials.auth = \
                    {username: couch.username, password: couch.password}

    return credentials

#console.log JSON.stringify setup_credentials(), null, 4

exports.db_connect = ->
    credentials = setup_credentials()
    connection = new cradle.Connection credentials
    db = connection.database credentials.db
    return db
