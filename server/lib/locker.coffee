# Locker needed because of the asynchronous behaviour of nodejs. The same
# data can be modified by two requests at the same time because node handle
# both requests without waiting the database response. So with this lock
# this system, if a data is accessed next request wait until data gets free
# before being executed.
# A lock has a time to live of 2s
class DataLock

    constructor: ->
        @locks = {}

    # True if lock is set.
    isLock: (lock) -> return @locks[lock]?

    # Create a new lock with a 2s TTL
    addLock: (lock) ->
        if not @isLock[lock]
            @locks[lock] = setTimeout =>
                if @isLock lock
                    delete @locks[lock]
            , 2000

    # Remove given lock
    removeLock: (lock) ->
        if @isLock lock
            clearTimeout @locks[lock]
            delete @locks[lock]

    # Wait that lock is being free before running given function
    runIfUnlock: (lock, callback) ->
        handleCallback = =>
            if @isLock lock
                setTimeout handleCallback, 10
            else
                callback()
        handleCallback()


module.exports = new DataLock()
