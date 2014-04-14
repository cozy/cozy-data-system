
db = require('../helpers/db_connect_helper').db_connect()

exports.remove = (doc, callback) =>
    deletedDoc =   
        "_rev": doc.rev
        "_deleted": true
    if doc.docType?        
        deletedDoc.docType = doc.docType
    if doc.binary?.file?
        deletedDoc.binary = doc.binary
    db.save doc._id, deletedDoc, callback

