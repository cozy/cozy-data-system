locker = require '../lib/locker'
logger = require('printit')
    date: true
    prefix: 'app:error'

module.exports = (err, req, res, next) ->
    statusCode = err.status or err.headers?.status or 500
    message = if err instanceof Error then err.message else err.error

    # @TODO : also send err.stack ?
    if err.code
        message =
            message: message
            code: err.code
    res.send statusCode, error: message

    if err instanceof Error
        logger.error err.message
        logger.error err.stack

    # if error occurs the unlock middleware isn't called
    if req.lock?
        locker.removeLock req.lock


module.exports.http = httpError = (code, msg) ->
    err = new Error msg
    err.status = code
    return err

module.exports.notFound = ->
    return httpError 404, 'Not Found'

module.exports.notAuthorized = ->
    return httpError 403, 'Application is not authorized'

module.exports.noPassword = ->
    return httpError 400, 'No password field in request\'s body'