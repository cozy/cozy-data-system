db = require('../../helpers/db_connect_helper').db_connect()

init = (docType, views, callback) ->	
    db.get "_design/#{docType}", (err, res) =>
        if err and err.error is 'not_found'
            db.save "_design/#{docType}", views, (err, res) =>
                if err
                    callback err
                else
                    callback null
        else
            callback null
allDevice = (doc) ->
    emit doc._id, doc if doc.docType && doc.docType is "Device"

byLogin = (doc) ->
    emit doc.login, doc if doc.docType && doc.docType is "Device"


module.exports = (compound) ->  
    views = {}
    views.all = map: allDevice.toString()
    views.byLogin = map: byLogin.toString()
    init 'device', views, (err) =>
        console.log err if err
        