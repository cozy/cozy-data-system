db = require('../helpers/db_connect_helper').db_connect()


module.exports = class User

    initAllView: (callback) ->
        db.get "_design/users", (err, res) =>
            if err and err.error is 'not_found'
                map = (doc) ->
                    emit doc._id, doc if doc.docType is "User"
                design_doc = {}
                design_doc.all= map: map.toString()

                db.save "_design/users", design_doc, (err, res) =>
                    if err
                        callback err
                    else
                        callback null
            else
                callback null


    getUser: (callback) ->
        @initAllView (err) ->
            if err
                callback err
            else
                db.view 'users/all', (err, res) =>
                    if err
                        callback err
                    else
                        if res.length > 0
                            callback null, res[0].value
                        else
                            callback null, new Error("No user found")
