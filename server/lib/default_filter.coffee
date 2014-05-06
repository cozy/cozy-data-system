db = require('../helpers/db_connect_helper').db_connect()

filter = (id) ->
    return "function (doc, req) {\n" +
        "    if(doc._deleted) {\n" +
        "        return true; \n" +
        "    }\n" +
        "    if ((doc.docType && doc.docType === \"File\") " +
        "|| (doc.docType && doc.docType === \"Folder\"))  {\n" +
        "        return true; \n"+
        "    } else if (doc._id === '#{id}') {\n" +
        "        return true;\n"+
        "    } else { \n" +
        "        return false; \n" +
        "    }\n" +
        "}"

filterDocType = (id) ->
    return "function (doc, req) {\n" +
        "    if ((doc.docType && doc.docType === \"File\") " +
        "|| (doc.docType && doc.docType === \"Folder\"))  {\n" +
        "        return true; \n"+
        "    } else if (doc._id === '#{id}') {\n" +
        "        return true;\n"+
        "    } else { \n" +
        "        return false; \n" +
        "    }\n" +
        "}"

filterAsView = (id) ->
    return """
        function (doc) {
            if (doc._id === '#{id}' || (doc.docType && doc.docType === "File")
        || (doc.docType && doc.docType === "Folder"))  {
                emit(doc._id, null);
            }
        }
    """


module.exports.get = (id) ->
    return filter id

module.exports.getDocType = (id) ->
    return filterDocType id

module.exports.asView = (id) ->
    return filterAsView id
