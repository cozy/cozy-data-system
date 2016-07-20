fs = require 'fs'
mm = require 'musicmetadata'
mime = require 'mime'
log = require('printit')
    prefix: 'audio'
db = require('../helpers/db_connect_helper').db_connect()
downloader = require './downloader'
async = require 'async'

# Mimetype that requires id3 tag generation. Other types are not supported.
whiteList = [
    'audio/mpeg'
    'audio/vorbis'
    'audio/ogg'
]


queue = async.queue (task, callback) ->
    db.get task.file, (err, file) ->
        if err
            log.info "Cant get File #{task.file} for id3 tag"
            log.info err
            callback()
        else
            addMeta file, task.force, callback
, 2


module.exports.create = (id, force) ->
    # Add thumb creation in queue
    queue.push {file: id, force: force}

# Create thumb for given file. Check that the thumb doesn't already exist
# and that file is from the right mimetype (see whitelist).
addMeta = (file, force, callback) ->
    addMetaToDoc = (stream) ->
        log.info "addMeta #{file.id}/#{file.name}: Adding Metadata..."
        mm stream, {duration: true, fileSize: file.size}, (err, metadata) ->
            log.info "addMeta #{file.id}/#{file.name}: Metadata Found."
            return callback(err) if err?

            for picture, index in metadata.picture
                buffer = picture.data.toString('base64')
                metadata.picture[index].data = "data:image/jpeg;base64,"+ buffer

            db.merge file.id, audio_metadata: metadata, (err, res) ->
                if err
                    callback err
                else
                    log.info "addMeta #{file.id}/#{file.name}: Added Metadata."
                    callback()

    return callback new Error('no binary') unless file.binary?

    # Retrieve file mimetype
    mimetype = mime.lookup file.name

    if file.audio_metadata and not force
        # id3 tag already exists
        log.info "addMeta #{file.id}/#{file.name}: already created."
        callback()

    else if mimetype not in whiteList
        log.info """
            addMeta: #{file.id} / #{file.name}:
            No id3tag to add for this kind of file.
        """
        callback()

    else
        # Download original file
        log.info """
            addMeta: #{file.id} / #{file.name}: Creation started...
        """
        id = file.binary['file'].id
        # Run the download with Node low level api.
        downloader.download id, 'file', (err, stream) ->
            if err
                log.error """
                    addMeta: #{file.id} / #{file.name}:
                    Error Downloading file
                """
                callback err
            else
                addMetaToDoc stream
