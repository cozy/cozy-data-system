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

allFolder = (doc) ->
    emit doc._id, doc if doc.docType && doc.docType is "Folder"
allDevice = (doc) ->
    emit doc._id, doc if doc.docType && doc.docType is "Device"
allFile = (doc) ->
    emit doc._id, doc if doc.docType && doc.docType is "File"

byLogin = (doc) ->
    emit doc.login, doc if doc.docType && doc.docType is "Device"

byFullPathFolder = (doc) ->
    emit doc.path + doc.name, doc if doc.docType && doc.docType is "Folder"
byFullPathFile = (doc) ->
    emit doc.path + doc.name, doc if doc.docType && doc.docType is "File"



module.exports = (compound) ->  
    views = {}
    views.all = map: allDevice.toString()
    views.byLogin = map: byLogin.toString()
    init 'device', views, (err) =>
        console.log err if err
        views = {}
        views.all = map: allFile.toString()
        views.byFullPath = map: byFullPathFile.toString()
        init 'file', views, (err) =>
            console.log err if err
            views = {}
            views.all = map: allFolder.toString()
            views.byFullPath = map: byFullPathFolder.toString()
            init 'folder', views, (err) =>
                console.log err if err