fs = require 'fs'
feed = require '../lib/feed'
checkDocType = require('../lib/token').checkDocType
checkDocTypeSync = require('../lib/token').checkDocTypeSync
checkSharingRule = require('../lib/token').checkSharingRule
checkSharingRuleSync = require('../lib/token').checkSharingRuleSync

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
            
# Check the permissions for a couchDB replication
# @permission {Object} : contains the permission linked to the request
module.exports.checkReplicationPermissions = (req, permission, next) ->
    auth = req.header('authorization')

    checkDocType auth, permission?.docType, (err, login, isAuthorized) ->
        # Not authenticated
        if not login
            checkSharingRule auth, permission, (err, sharing, isAuthorized) ->
                # Request not authenticated
                if not sharing
                    err = new Error "Requester is not authenticated"
                    err.status = 401
                    next err
                # Request authenticated as a sharing but not authorized
                else if not isAuthorized
                    err = new Error "#{sharing} is not authorized"
                    err.status = 403
                    next err
                # Legitimate sharing request
                else
                    feed.publish 'usage.sharing', sharing
                    req.sharing = sharing
                    next()
        # Authentication successul but not authorized
        else if not isAuthorized
            err = new Error "Device #{login} is not authorized"
            err.status = 403
            next err
        # Permissions are correct
        else
            feed.publish 'usage.application', login
            req.login = login
            next()

# Check the permissions for a couchDB replication
# @permission {Object} contains the permission linked to the request
module.exports.checkReplicationPermissionsSync = (req, permission) ->
    auth = req.header('authorization')

    [err, login, isAuthorized] = checkDocTypeSync auth, permission?.docType
    # Not authenticated
    if not login
        [err, sharing, isAuthorized] = checkSharingRuleSync auth, permission
        # Request not authenticated
        if not sharing
            err = new Error "Requester is not authenticated"
            err.status = 401
            return err
        # Request authenticated as a sharing but not authorized
        else if not isAuthorized
            err = new Error "#{sharing} is not authorized"
            err.status = 403
            return err
        # Legitimate sharing request
        else
            feed.publish 'usage.sharing', sharing
            req.sharing = sharing
            return
    # Authentication successul but not authorized
    else if not isAuthorized
        err = new Error "Device #{login} is not authorized"
        err.status = 403
        return err
    # Permissions are correct
    else
        feed.publish 'usage.application', login
        req.login = login
        return
