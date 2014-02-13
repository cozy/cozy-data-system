locker = require '../lib/locker'
logger = require('printit')
    date: true
    prefix: 'app:error'

module.exports = (err, req, res, next) ->

    statusCode = err.status or 500
    message = if err instanceof Error then err.message else err.error

    res.send statusCode, error: message

    if err instanceof Error
        logger.error err.message
        logger.error err.stack

    # if error occurs the unlock middleware isn't called
    if req.lock?
        locker.removeLock req.lock
