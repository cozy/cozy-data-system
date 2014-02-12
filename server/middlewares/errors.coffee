locker = require '../lib/locker'

module.exports = (err, req, res, next) ->

    statusCode = err.status or 500
    message = if err instanceof Error then err.message else err.error

    res.send statusCode, error: message

    # if error occurs the unlock middleware isn't called
    if req.lock?
        locker.removeLock req.lock
