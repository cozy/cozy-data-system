load 'application'

Client = require("request-json").JsonClient
client = new Client("http://localhost:9102/")
db = require('../../helpers/db_connect_helper').db_connect()
crypto = require('../../lib/crypto.coffee')


# POST /accounts/password/
action 'initializeMasterKey', ->
    delete body._attachments

    # define design document of the object 'User'
    db.get "_design/users", (err, res) ->
        if err && err.error is 'not_found'
            map = (doc) ->
                emit doc._id, doc if (doc.docType == "User")
            design_doc = {}
            design_doc['all'] = {map:map.toString()}
            db.save "_design/users", design_doc, (err, res) ->
                if err
                    console.log "[Definition] err: " + JSON.stringify err
                    send 500
                else

                    # recover the object 'User'
                    db.view 'users/all', (err, res) =>
                        if err
                            if err.error is "not_found"
                                send 404
                            else
                                console.log "[Results] err: " + JSON.stringify err
                                send 500
                        else
                            res.forEach  (row) ->
                                @user = row
                                if @user.salt?
                                    @salt = @user.salt
                                else

                                    # generate the salt and save it in the database
                                    @salt = app.crypto.genSalt 32-body.pwd.length
                                    db.merge @user._id, {salt: @salt}, (err, res) =>
                                        if err
                                            console.log "[Merge] err: " + 
                                                    JSON.stringify err
                                            send 500

                                # generate the master key
                                app.crypto.masterKey = 
                                    app.crypto.genHashWithSalt body.pwd, @salt
                                send 200



#DELETE /accounts/
action 'deleteMasterKey', ->
    app.crypto.masterKey = null
    send 204

