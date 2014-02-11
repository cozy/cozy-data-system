db = require('../helpers/db_connect_helper').db_connect()


module.exports = class DocType

    initAllView: (callback) ->
        db.get "_design/docType", (err, res) =>
            if err and err.error is 'not_found'
                map = (doc) ->
                    emit doc._id, doc if doc.docType is "doctype"
                design_doc = {}
                design_doc.all= map: map.toString()

                db.save "_design/docType", design_doc, (err, res) =>
                    if err
                        callback err
                    else
                        callback null
            else
                callback null


    getDocTypes: (callback) ->
        @initAllView (err) ->
            if err
                callback err
            else
                db.view 'docType/all', (err, res) =>
                    if err
                        callback err
                    else
                        if res.length > 0
                            callback null, res
                        else
                            callback null, new Error("No docType found")