path = require 'path'

# set env for cozy-indexer
# if we have APPLICATION_PERSISTENT_DIRECTORY, we have the new controller
# and we use the provided directory
# if we dont have it, let cozy-indexer use its default, which
# create the indexes inside node_modules/cozy-indexer
persistentDirectory = process.env.APPLICATION_PERSISTENT_DIRECTORY
if persistentDirectory
    process.env.INDEXES_PATH ?= path.join persistentDirectory, 'indexes'

indexer = require 'cozy-indexer'
async = require 'async'
log =  require('printit')
    date: true
    prefix: 'indexer'

locker = require '../lib/locker'
db = require('../helpers/db_connect_helper').db_connect()

indexQueue = {}
batchInProgress = false
BATCH_SIZE = 10
batchCounter = 1
indexdefinitions = {}
indexdefinitionsID = {}

FETCH_AT_ONCE_FOR_REINDEX = BATCH_SIZE


# indexfield added to all documents
# @TODO: figure out a way to add a common date field
commonIndexFields =
    "docType": filter: true, searchable: false
    "tags":    filter: true


# prevent from adding or removing doc while
# a cleanup is in progress (cause fatal exception)
forgetDoc = locker.wrap 'indexfile', indexer.forget
addBatch  = locker.wrap 'indexfile', indexer.addBatch
cleanup   = locker.wrap 'indexfile', indexer.cleanup


###*
# Initialize the indexer
#
# @return (callback) when initialization is complete
###
exports.initialize = (callback) ->

    async.waterfall [
        (callback) ->
            indexer.store.open callback

        (callback) -> # FETCH INDEX DEFINITIONS
            query = include_docs: true
            db.view "indexdefinition/all", query, (err, rows) ->
                return callback err if err
                for row in rows
                    docType = row.doc.targetDocType
                    definitionDocument = row.doc
                    for k, v of commonIndexFields
                        definitionDocument.ftsIndexedFields[k] = v
                    indexdefinitions[docType] = definitionDocument
                    indexdefinitionsID[row.id] = docType

                registerDefaultIndexes callback

        (callback) -> # REINDEX DOCTYPE IF INDEX DEFINITION NEWER
            docTypes = Object.keys indexdefinitions
            async.eachSeries docTypes, maybeReindexDocType, callback

        (callback) -> # REINDEX CHANGES SINCE LAST
            indexer.store.get 'indexedseq', (err, seqno) ->
                if err
                    if err.type is 'NotFoundError'
                        log.warn """
Last index sequence was not found. If no document is indexed yet, it's ok. In other cases, there is probably an error with your indexes.
"""
                        callback()
                    else
                        callback err
                else
                    reindexChanges seqno, callback

    ], callback


###*
# Get a batch from the queue and index it
#
###
dequeue = ->
    # do nothing if there is already a batch in progress
    return null if batchInProgress

    # try to find a docType with some docs to be indexed
    for docType, docs of indexQueue when docs.length > 0
        # Take BATCH_SIZE docs, leave the rest
        docs = docs[0...BATCH_SIZE]
        indexQueue[docType] = docs[BATCH_SIZE..]
        batchInProgress = true
        break # stop when we find one

    # if there is nothing to do, we stop now
    return null unless batchInProgress

    options = indexdefinitions[docType].ftsIndexedFields
    maxseqno = docs[docs.length-1]._seqno
    batchName = "batch #{batchCounter++}"
    log.info "add #{batchName} of #{docs.length} #{docType}"
    addBatch docs, options, (err) ->
        log.info "#{batchName} done #{err?.stack or 'success'}"
        checkpointSeqNumber maxseqno, (err) ->
            log.error "checkpoint error", err if err
            batchInProgress = false
            setImmediate dequeue

###*
# Destroy the index completely (used for tests)
#
###
exports.cleanup = (callback) ->
    cleanup callback

###*
# To be called every time a document is updated
# used in lib/feed
#
###
exports.onDocumentUpdate = (doc, seqno) ->
    docType = doc.docType?.toLowerCase?()
    if docType of indexdefinitions
        doc._seqno = seqno
        indexQueue[docType] ?= []
        indexQueue[docType].push doc
        setImmediate dequeue

###*
# To be called every time a document is deleted
# used in lib/feed
#
###
exports.onDocumentDelete = (doc, seqno) ->
    if doc.docType is 'indexdefinition'
        docType = indexdefinitionsID[doc._id]
        delete indexdefinitions[docType]

    else if doc.docType of indexdefinitions
        forgetDoc doc._id, ->
            log.info "doc#{doc._id} unindexed"

###*
# Perform a search in the index
#
# @params docType {array} docTypes to search in, empty for all
# @params options {object} query options
# @params options.query {mixed} the search terms
# @params options.numPage {number} page number
# @params options.pageSize {number} number of result by page
# @params options.facets {object} see cozy-indexer doc
# @params options.filter {object} see cozy-indexer doc
#
# @return (callback) {object} see cozy-indexer doc
#
###
exports.search = (docTypes, options, callback) ->
    params =
        offset        : options.numPage or 0
        pageSize      : options.numByPage or 10

    if typeof options.query is 'string'
        params.search = "*": [options.query]
    else if Array.isArray(options.query)
        params.search = "*": options.query
    else
        params.search = options.query

    if options.facets
        params.facets = options.facets

    if options.filter
        params.filter = options.filter

    if docTypes.length > 0
        params.filter ?= {}
        params.filter.docType = docTypes.map (t) -> [t, t]

    indexer.search params, callback

###*
# Register the indexdefintion for a docType
#
# @params docType {string} docType to register for
# @params indexdefinition {object} a map of field to index rules
#
# @return (callback) after reindexing or 10s, whichever comes first
#
###
exports.registerIndexDefinition = (docType, indexdefinition, callback) ->

    callbackOnce = (cause) ->
        callback.apply this, arguments if callback
        callback = null

    docType = docType.toLowerCase()
    existing = indexdefinitions[docType]
    changed = false

    if existing
        mergedFields = {}
        for k, v of existing.ftsIndexedFields when not commonIndexFields[k]
            mergedFields[k] = v

        for field, fieldDef of indexdefinition
            oldFieldDef = existing.ftsIndexedFields[field]
            mergedFields[field] = indexer.mergeFieldDef oldFieldDef, fieldDef
            changed = true if mergedFields[field] isnt oldFieldDef
        definitionDocument = existing
        definitionDocument.ftsIndexedFields = mergedFields
    else
        definitionDocument =
            docType: "indexdefinition"
            ftsIndexedFields: indexdefinition
            targetDocType: docType
        changed = true

    if changed
        db.save definitionDocument, (err, savedDoc) ->
            return callback err if err
            definitionDocument._id = savedDoc.id
            definitionDocument._rev = savedDoc.rev
            for k, v of commonIndexFields
                definitionDocument.ftsIndexedFields[k] = v

            indexdefinitions[docType] = definitionDocument
            indexdefinitionsID[savedDoc.id] = docType


            setTimeout callbackOnce.bind(null, new Error('timeout')), 10000

            initializeReindexing docType, (err) ->

                return callbackOnce err if err
                checkpointDocTypeRev docType, savedDoc.rev, callbackOnce

    else
        log.info "rev is different, but definition not changed"
        checkpointDocTypeRev docType, definitionDocument.rev, callbackOnce

###*
# Store the indexdefintion rev within the index file
#
# @params docType {string} docType to register for
# @params rev {string} value to store
#
# @return (callback) when done
#
###
checkpointDocTypeRev = (docType, rev, callback) ->
    getStatus docType, (err, status) ->
        return callback err if err
        status.rev = rev
        saveStatus docType, status, callback

###*
# Store the last indexed sequence number within the index file
#
# @params seqno {string} value to store
#
# @return (callback) when done
#
###
checkpointSeqNumber = (seqno, callback) ->
    indexer.store.set 'indexedseq', seqno, callback


groupChangesByDoctypes = (changes) ->
    byDoctype = {}
    out = []
    for change in changes
        docType = change.doc.docType
        definition = indexdefinitions[docType]
        if definition and not change.deleted

            unless byDoctype[docType]
                docs = byDoctype[docType] = []
                out.push {docType, docs, definition}

            byDoctype[docType].push change.doc

    return out

###
# Recursive function to reindex all docs which have changed since
# the given seqno
#
# @params seqno {number} sequence number to start from
#
# @return (callback) when done
#
###
reindexChanges = (seqno, callback) ->

    options =
        include_docs: true
        since: seqno
        limit: FETCH_AT_ONCE_FOR_REINDEX

    db.changes options, (err, changes) ->
        return callback err if err
        return callback null if changes.length < FETCH_AT_ONCE_FOR_REINDEX

        batches = groupChangesByDoctypes changes
        maxSeqNo = changes[changes.length-1].seq

        async.eachSeries batches, ({docs, docType, definition}, next) ->
            indexer.addBatch docs, definition.ftsIndexedFields, next

        , (err) ->
            return callback err if err
            checkpointSeqNumber maxSeqNo, (err) ->
                return callback err if err
                reindexChanges maxSeqNo, callback


getDocs = (docType, skip, limit, callback) ->
    docType = docType.toLowerCase()
    db.view "doctypes/all",
        key: docType
        limit: FETCH_AT_ONCE_FOR_REINDEX
        skip: skip
        include_docs: true
        reduce: false
    , callback

getStatus = (docType, callback) ->
    indexer.store.get "indexingstatus/#{docType}", (err, status) ->
        if err or not status
            status =
                skip: 0
                state: "indexing-by-doctype"
                rev: 'no-revision'

        else if status
            status = JSON.parse status

        callback null, status

saveStatus = (docType, status, callback) ->
    status = JSON.stringify status
    indexer.store.set "indexingstatus/#{docType}", status, callback

###*
# Reindex a given docType from the beginning
#
# @params docType {string} docType to reindex
#
# @return (callback) when done
#
###
initializeReindexing = (docType, callback) ->

    definition = indexdefinitions[docType]

    db.info (err, infos) ->
        return callback err if err
        status =
            state: "indexing-by-doctype"
            rev: definition._rev
            skip: 0
            checkpointedSeqNumber: infos.update_seq

        saveStatus docType, status, (err) ->
            return callback err if err
            resumeReindexing docType, status, callback

###*
# Recursive function to reindex all docs for a given docType
# get doc in batch of FETCH_AT_ONCE_FOR_REINDEX and add them immediately
#
# Note, this function doesn't use the indexQueue used for realtime events
#
# @params docType {string} value to store
# @params definition {object} definition of fields to store
#
# @return (callback) when done
#
###
resumeReindexing = (docType, status, callback) ->
    definition = indexdefinitions[docType]

    # if the definition changed while we are still reindexing
    # we need to abort.
    # A new indexing as been triggered in registerIndexDefinition
    if status.rev isnt definition._rev
        log.info "aborting reindex"
        return callback new Error('abort')

    getDocs docType, status.skip, FETCH_AT_ONCE_FOR_REINDEX, (err, rows) ->
        return callback err if err

        # end recursion if getDocs returns nothing
        if rows.length is 0
            return finishReindexing docType, status, callback

        docs = rows.toArray()
        indexer.addBatch docs, definition.ftsIndexedFields, (err) ->
            return callback err if err

            status.skip = status.skip + FETCH_AT_ONCE_FOR_REINDEX
            saveStatus docType, status, (err) ->
                return callback err if err
                next = resumeReindexing.bind null, docType, status, callback
                setTimeout next, 500 # let leveldb breath


finishReindexing = (docType, status, callback) ->
    status.state = 'indexing-by-changes'
    status.skip = 0
    saveStatus docType, status, callback


###*
# Check if given docType definition is the same we used to index it
# if not, fire up a reindexing using initializeReindexing
#
# @params docType {string} docType to test
#
# @return (callback) when done
#
###
maybeReindexDocType = (docType, callback) ->

    definition = indexdefinitions[docType]

    getStatus docType, (err, status) ->
        log.info """
            Check index status for #{docType}:
                in indexer:#{status.rev} #{status.state} #{status.skip},
                in data-system:#{definition._rev}
        """

        if status.rev is definition._rev
            if status.state is 'indexing-by-doctype'
                # the DS probably crashed, but the definition hasnt changed
                # state should be 'indexing', we want to start again
                # at checkpointed skip
                resumeReindexing docType, status, callback
            else
                # nothing to do
                setImmediate callback

        else
            # the definition has changed, it doesnt matter if we already
            # had some indexing done, we need to start fresh
            initializeReindexing docType, callback

###*
# [TMP] Register default indexes used by most cozy on October 2015,
# ie. Folder, File and Note indexes.
#
# @return (callback) when done
#
###
registerDefaultIndexes = (callback) ->


    registerNote = (done) ->
        exports.registerIndexDefinition 'note',
            title:
                nGramLength: {gte: 1, lte: 2},
                stemming: true, weight: 5, fieldedSearch: false
            content:
                nGramLength: {gte: 1, lte: 2},
                stemming: true, weight: 1, fieldedSearch: false

        , done

    registerFile = (done) ->
        exports.registerIndexDefinition 'file',
            name:
                nGramLength: 1,
                stemming: true, weight: 1, fieldedSearch: false

        , done

    registerFolder = (done) ->
        exports.registerIndexDefinition 'folder',
            name:
                nGramLength: 1,
                stemming: true, weight: 1, fieldedSearch: false

        , done

    actions = []
    actions.push registerNote unless indexdefinitions.note
    actions.push registerFile unless indexdefinitions.file
    actions.push registerFolder unless indexdefinitions.folder
    async.series actions, (err) -> callback err


###*
# [TMP] Wait for a given document to be indexed
#
# Used in the former /data/index route
# so apps tests wont break
#
###
exports.waitIndexing = (id, callback) ->
    foundWaiting = false
    for type, docs of indexQueue
        for doc in docs when doc._id is id
            foundWaiting = true

    if foundWaiting
        tryAgain = exports.waitIndexing.bind null, id, callback
        setTimeout tryAgain, 100
    else
        callback null

