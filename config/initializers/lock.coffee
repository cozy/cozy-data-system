# Locker needed because of the asynchronous behaviour of nodejs. The same
# data can be modified by two requests at the same time because node handle
# both requests without waiting the database response. So with this lock
# this system, it a data is accessed next request wait until data get free
# before being executed.
# A lock has time to live of 2s
class DataLock
    
    constructor: ->
        @locks = {}
        
    # True if lock is set.
    isLock: (lock) ->
        @locks[lock]

    # Create a new lock with a 2s TTL
    addLock: (lock) ->
        if not @isLock[lock]
            @locks[lock] = true
            setTimeout =>
                if @isLock lock
                    delete @locks[lock]
            , 2000

    # Remove given lock
    removeLock: (lock) ->
        delete @locks[lock]

    # Wait that lock is bein free before running given function
    runIfUnlock: (lock, callback) ->
        handleCallback = =>
            if @isLock lock
                setTimeout handleCallback, 10
            else
                callback()
        handleCallback()

# Set locker as a global variable
app.locker = new DataLock()
