if process.NODE_ENV isnt "production"

    Crypto = require '../../lib/crypto'
    User = require '../../lib/user'

    randomString = require('../../lib/random').randomString
    db = require('../../helpers/db_connect_helper').db_connect()

    user = new User()
    cryptoTools = new Crypto()

    app.crypto = {} if not app.crypto?
    user.getUser (err, user) ->

        if user?
            password = "password"
            salt = cryptoTools.genSalt(32 - password.length)
            masterKey = cryptoTools.genHashWithSalt password, salt
            slaveKey = randomString()
            encryptedSlaveKey = cryptoTools.encrypt masterKey, slaveKey

            app.crypto.masterKey = masterKey
            app.crypto.slaveKey  = encryptedSlaveKey

            data = salt: salt, slaveKey: encryptedSlaveKey
            db.merge user._id, data, (err, res) =>
                if process.NODE_ENV isnt "production"
                    console.log "crypto keys initialized."
