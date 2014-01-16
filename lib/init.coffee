db = require('../helpers/db_connect_helper').db_connect()
encryption = require('./encryption')

## Patch for automatic encryption
exports.initPassword = (callback) ->
    if process.env isnt 'development'
        db.view "bankaccess/all", {}, (err, res) =>
            if not err
                res.forEach (value) ->
                    if value.password?
                        encryption.decrypt value.password, (err, password) =>
                            if password is value.password
                                encryption.encrypt value.password, (err, password) =>
                                    value.password = password
                                    db.save value.id, value, (err, res, body) =>
    callback()

