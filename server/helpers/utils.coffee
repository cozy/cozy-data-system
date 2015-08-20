fs = require 'fs'
feed = require '../lib/feed'
checkDocType = require('../lib/token').checkDocType
checkDocTypeSync = require('../lib/token').checkDocTypeSync

# Delete files on the file system
module.exports.deleteFiles = (files) ->
    if files? and Object.keys(files).length > 0
        fs.unlinkSync file.path for key, file of files

# Check the application has the permissions to access the route
module.exports.checkPermissions = (req, permission, next) ->
    authHeader = req.header('authorization')
    checkDocType authHeader, permission, (err, appName, isAuthorized) ->
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
            req.appName = appName
            next()


module.exports.checkPermissionsSync = (req, permission) ->
    authHeader = req.header('authorization')
    [err, appName, isAuthorized] = checkDocTypeSync authHeader, permission
    if not appName
        err = new Error "Application is not authenticated"
        err.status = 401
        return err
    else if not isAuthorized
        err = new Error "Application is not authorized"
        err.status = 403
        return err
    else
        feed.publish 'usage.application', appName
        req.appName = appName
        return
