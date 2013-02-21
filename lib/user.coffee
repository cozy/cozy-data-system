db = require('../helpers/db_connect_helper').db_connect()
async = require('async')


class User

    
    initUserAllView: (callback) =>
        db.get "_design/users", (err, res) =>
            if err && err.error is 'not_found'
                map = (doc) ->
                    emit doc._id, doc if (doc.docType == "User")
                design_doc = {}
                design_doc['all'] = {map:map.toString()}

                db.save "_design/users", design_doc, (err, res) =>
                    if err
                        callback err
                    else
                        callback null
            else
                callback null

    getUser: (callback) =>
        @initUserAllView (err) ->
            if err  
                callback err
            else 
                db.view 'users/all', (err, res) =>
                    if err && err.error is "not_found"
                        callback err
           	        else if err
                        callback err
                    else
                        callback null, res[0].value


app.user = new User()