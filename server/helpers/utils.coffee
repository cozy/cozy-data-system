fs = require 'fs'
feed = require '../helpers/db_feed_helper'
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
            res.send 401, error: err.message
        else if not isAuthorized
            err = new Error "Application is not authorized"
            res.send 403, error: err.message
        else
            feed.publish 'usage.application', appName
            next()