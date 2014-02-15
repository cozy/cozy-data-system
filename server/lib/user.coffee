db = require('../helpers/db_connect_helper').db_connect()


module.exports = class User

    initAllView: (callback) ->
        db.get "_design/user", (err, res) ->
            map = """
            function(doc) {
                if(doc.docType.toLowerCase() === "user") {
                    return emit(doc._id, doc);
                }
            }
            """

            design_doc =
                all:
                    map: map

            if err and err.error is 'not_found'
                db.save "_design/user", design_doc, (err, res) ->
                    if err
                        callback err
                    else
                        callback null

            else if not res.all?
                db.merge "_design/user", design_doc, (err, res) ->
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
                db.view 'user/all', (err, res) =>
                    if err
                        callback err
                    else
                        if res.length > 0
                            callback null, res[0].value
                        else
                            callback null, new Error("No user found")
