checkToken = require('../lib/token').checkToken
errors = require '../middlewares/errors'

module.exports.checkDevice = (req, res, next) ->
    auth = req.header('authorization')
    [err, isAuthenticated, name] = checkToken auth
    # Device authorization is not necessary because filter name ensure
    # permissions for this device.
    if err or not isAuthenticated or not name
        next errors.notAuthorized()
    else
        req.params.id = "_design/filter-#{name}-#{req.params.id}"
        next()

module.exports.fixBody = (req, res, next) ->
    req.body.views = {} if "views" not in req.body
    next()
