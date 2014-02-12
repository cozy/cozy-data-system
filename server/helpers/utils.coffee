fs = require 'fs'
feed = require '../lib/feed'
checkDocType = require('../lib/token').checkDocType

# Delete files on the file system
module.exports.deleteFiles = (files) ->
    if files? and Object.keys(files).length > 0
        fs.unlinkSync file.path for key, file of files

# Check the application has the permissions to access the route
module.exports.checkPermissions = (permission, auth, res, next) ->
    checkDocType auth, permission, (err, appName, isAuthorized) ->
        if not appName
            err = new Error "Application is not authenticated"
            err.status = 401
            next err
        else if not isAuthorized
            err = new Error "Application is not authorized"
            err.status = 403
            next err
        else
            feed.publish 'usage.application', appName
            next()