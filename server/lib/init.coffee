db = require('../helpers/db_connect_helper').db_connect()
encryption = require('./encryption')

## Patch for automatic encryption
# We must think about removing this (12/02/2014)

errorMsg = "[lib/init] Error, no master/slave keys"
exports.initPassword = (callback) ->
    if process.env isnt 'development'
        db.view "bankaccess/all", {}, (err, res) =>
            if not err
                res.forEach (value) ->
                    if value.password?
                        try
                            password = encryption.decrypt value.password
                        catch error
                            console.log errorMsg

                        if password is value.password
                            try
                                password = encryption.encrypt req.doc.password
                            catch error
                                console.log errorMsg

                            value.password = password
                            db.save value.id, value, (err, res, body) ->
    callback()

