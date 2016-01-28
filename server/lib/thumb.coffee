fs = require 'fs'
gm = require('gm').subClass(imageMagick: true)
mime = require 'mime'
log = require('printit')
    prefix: 'thumbnails'
db = require('../helpers/db_connect_helper').db_connect()
binaryManagement = require '../lib/binary'
downloader = require './downloader'
async = require 'async'
randomString = require('./random').randomString

# Mimetype that requires thumbnail generation. Other types are not supported.
whiteList = [
    'image/jpeg'
    'image/png'
]


queue = async.queue (task, callback) ->
    db.get task.file, (err, file) ->
        if err
            log.info "Cant get File #{file.id} for thumb"
            log.info err
            callback()
        else
            createThumb file, task.force, callback
, 2

# when the download fail, stream should be drained in order to release the
# http connection from the pool. This function put stream in flowing mode
# and discard the data. When this function is called, the short content
# ({error: "not_found"}) is already buffered, so its simpler to read &
# discard than to abort.
releaseStream = (stream) ->
    stream.on 'data', ->
    stream.on 'end', ->
    stream.resume()


# Resize given file/photo and save it as binary attachment to given file.
# Resizing depends on target attachment name. If it's 'thumb', it cropse
# the image to a 300x300 image. If it's a 'scree' preview, it is resize
# as a 1200 x 800 image.
resize = (srcPath, file, name, mimetype, force, callback) ->
    if file.binary[name]? and not force
        return callback()
    data =
        name: name
        "content-type": mimetype
    try
        # Check if srcPath exists and if data-ssytem have access to it
        unless fs.existsSync(srcPath)
            return callback "File doesn't exist"
        try
            fs.open srcPath, 'r+', (err, fd) ->
                fs.close(fd)
                if err
                    return callback 'Data-system has not correct permissions'
        catch e
            return callback 'Data-system has not correct permissions'

        gmRunner = gm(srcPath)

        if name is 'thumb'
            gmRunner
            .background('None')     # Preserve alpha
            .resize(300, 300, '^')  # Fill 300x300
            .gravity('Center')      # Combined with extent -v
            .extent(300, 300)       # Crop to 300x300 centered
            .strip()                # Strip EXIF
            .stream (err, stdout, stderr) ->
                if err
                    # Releases stream if an error occurs
                    releaseStream stdout
                    callback err
                else
                    # Attach resized file in document
                    binaryManagement.addBinary file, data, stdout, (err)->
                        return callback err if err?

                    stdout.on 'end', callback

        else if name is 'screen'
            # Resize file
            gmRunner
            .background('None')  # Preserve alpha
            .resize(1200, 800)   # Fit in 1200x800
            .strip()             # Strip EXIF
            .stream (err, stdout, stderr) ->
                if err
                    # Releases stream if an error occurs
                    releaseStream stdout
                    callback err
                else
                    # Attach resized file in document
                    binaryManagement.addBinary file, data, stdout, (err)->
                        return callback err if err?

                    stdout.on 'end', callback

    catch err
        callback err


module.exports.create = (id, force) ->
    # Add thumb creation in queue
    queue.push {file: id, force: force}

# Create thumb for given file. Check that the thumb doesn't already exist
# and that file is from the right mimetype (see whitelist).
createThumb = (file, force, callback) ->
    addThumb = (stream, mimetype) ->
        rawFile = "/tmp/#{file.name}"
        # Use streaming to avoid high memory consumption.
        if fs.existsSync rawFile
            rawFile = "/tmp/#{randomString(3)}#{file.name}"
        try
            writeStream = fs.createWriteStream rawFile
        catch
            releaseStream stream
            return callback 'Error in thumb creation.'
        stream.pipe writeStream
        stream.on 'error', callback
        writeStream.on 'finish', ->
            # Resize and create if necessary thumb and screen for file
            resize rawFile, file, 'thumb', mimetype, force, (err) ->
                log.error(err) if err?
                resize rawFile, file, 'screen', mimetype, force, (err) ->
                    log.error(err) if err?
                    # Remove original file
                    fs.unlink rawFile, (err) ->
                        if err
                            log.error err
                        else
                            log.info """
                                createThumb #{file.id} /
                                 #{file.name}: Thumbnail created
                            """
                        callback()

    return callback new Error('no binary') unless file.binary?

    # Retrieve file mimetype
    mimetype = mime.lookup file.name

    if file.binary?.thumb? and file.binary?.screen? and not force
        # Thumb and screen already exists
        log.info "createThumb #{file.id}/#{file.name}: already created."
        callback()

    else if mimetype not in whiteList
        log.info """
            createThumb: #{file.id} / #{file.name}:
            No thumb to create for this kind of file.
        """
        callback()

    else
        # Download original file
        log.info """
            createThumb: #{file.id} / #{file.name}: Creation started...
        """
        id = file.binary['file'].id
        # Run the download with Node low level api.
        downloader.download id, 'file', (err, stream) ->
            if err
                callback err
            else
                addThumb stream, mimetype
