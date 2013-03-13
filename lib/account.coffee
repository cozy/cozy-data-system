db = require('../helpers/db_connect_helper').db_connect()


module.exports = class Account

    initAllView: (callback) ->
        db.get "_design/accounts", (err, res) =>
            if err and err.error is 'not_found'
                map = (doc) ->
                    emit doc._id, doc if doc.docType is "Account"
                design_doc = {}
                design_doc.all= map: map.toString()

                db.save "_design/accounts", design_doc, (err, res) =>
                    if err
                        callback err
                    else
                        callback null
            else
                callback null


    getAccounts: (callback) ->
        @initAllView (err) ->
            if err
                callback err
            else
                db.view 'accounts/all', (err, res) =>
                    if err
                        callback err
                    else
                        if res.length > 0
                            callback null, res
                        else
                            callback null, new Error("No user found")