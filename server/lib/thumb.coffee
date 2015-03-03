fs = require 'fs'
gm = require 'gm'
mime = require 'mime'
log = require('printit')
    prefix: 'thumbnails'
db = require('../helpers/db_connect_helper').db_connect()
binaryManagement = require '../lib/binary'
downloader = require './downloader'

# Mimetype that requires thumbnail generation. Other types are not supported.
whiteList = [
    'image/jpeg'
    'image/png'
]


module.exports = thumb =

    # Resize given file/photo and save it as binary attachment to given file.
    # Resizing depends on target attachment name. If it's 'thumb', it cropse
    # the image to a 300x300 image. If it's a 'scree' preview, it is resize
    # as a 1200 x 800 image.
    resize: (srcPath, file, name, mimetype, callback) ->
        dstPath = "/tmp/thumb-#{file.name}"
        data =
            name: name
            "content-type": mimetype
        try
            gmRunner = gm(srcPath).options(imageMagick: true)

            if name is 'thumb'
                buildThumb = (width, height) ->
                    gmRunner
                    .resize(width, height)
                    .crop(300, 300, 0, 0)
                    .write dstPath, (err) ->
                        if err
                            callback err
                        else
                            stream = fs.createReadStream(dstPath)
                            binaryManagement.addBinary file, data, stream, (err)->
                                return callback err if err?
                                fs.unlink dstPath, callback

                gmRunner.size (err, data) ->
                    if err
                        callback err
                    else
                        if data.width > data.height
                            buildThumb null, 300
                        else
                            buildThumb 300, null

            else if name is 'screen'
                gmRunner.resize(1200, 800)
                .write dstPath, (err) ->
                    if err
                        callback err
                    else
                        stream = fs.createReadStream(dstPath)
                        binaryManagement.addBinary file, data, stream, (err)->
                            return callback err if err?
                            fs.unlink dstPath, callback

        catch err
            callback err



    # Create thumb for given file. Check that the thumb doesn't already exist
    # and that file is from the right mimetype (see whitelist).
    create: (file, callback) ->
        return callback new Error('no binary') unless file.binary?

        if file.binary?.thumb?
            log.info "createThumb #{file.id}/#{file.name}: already created."
            callback()

        else
            mimetype = mime.lookup file.name

            if mimetype not in whiteList
                log.info """
                    createThumb: #{file.id} / #{file.name}: 
                    No thumb to create for this kind of file.
                """
                callback()

            else

                log.info """
                    createThumb: #{file.id} / #{file.name}: Creation started...
                """
                rawFile = "/tmp/#{file.name}"
                id = file.binary['file'].id

                # Run the download with Node low level api.
                request = downloader.download id, 'file', (err, stream) ->
                    if err
                        log.error err
                    else
                        # Use streaming to avoid high memory consumption.
                        stream.pipe fs.createWriteStream rawFile
                        stream.on 'error', callback
                        stream.on 'end', =>
                            thumb.resize rawFile, file, 'thumb', mimetype, (err) =>
                                fs.unlink rawFile, ->
                                    if err
                                        log.error err
                                    else
                                        log.info """
                                            createThumb #{file.id} /
                                             #{file.name}: Thumbnail created
                                        """
                                    callback err
