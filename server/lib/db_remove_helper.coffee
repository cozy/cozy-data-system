
db = require('../helpers/db_connect_helper').db_connect()


# Prepare the deletion doc. It's required to make couch raised the required
# events.
getDeletedDoc = (doc) ->
    deletedDoc =
        "_id": doc._id
        "_rev": doc._rev
        "_deleted": true
    if doc.docType?
        deletedDoc.docType = doc.docType
    if doc.binary?
        deletedDoc.binary = doc.binary

    deletedDoc


# Remove givend document.
exports.remove = (doc, callback) =>
    deletedDoc = getDeletedDoc doc
    db.save doc._id, deletedDoc, callback


# Take advantage of bulk update to delete a batch of docs.
exports.removeAll = (docs, callback) =>
    deletedDocs = []
    deletedDocs.push getDeletedDoc doc.value for doc in docs

    db.save deletedDocs, callback
