db = require('../helpers/db_connect_helper').db_connect()
# lib/default_filter
# provide the default filters for a newly created Device
# the device can overwrite these filters by editing & syncing _design/[deviceID]
# default filter = Files & Folders  + the Device itself


# .get(id) # filter for continous replication, include deleted docs
module.exports.get = (id) ->
    return """
        function(doc, req){
            if(doc._deleted) {
                return true;
            }
            if ((doc.docType && doc.docType === \"File\")
              || (doc.docType && doc.docType === \"Folder\")) {
                return true;
            } else if (doc._id === '#{id}') {
                return true;
            } else {
                return false;
            }
        }
    """

# .getDocType() # filter for initial replication, doesn't include deleted docs
module.exports.getDocType = (id) ->
    return """
        function (doc, req) {
            if ((doc.docType && doc.docType === \"File\")
              || (doc.docType && doc.docType === \"Folder\")) {
                return true;
            } else if (doc._id === '#{id}') {
                return true;
            } else {
                return false;
            }
        }
    """

# .asView() # similar to filterDocType but as a view (use Btree)
module.exports.asView = (id) ->
    return """
        function (doc) {
            if (doc._id === '#{id}' || (doc.docType && doc.docType === "File")
        || (doc.docType && doc.docType === "Folder"))  {
                emit(doc._id, null);
            }
        }
    """