db = require('../helpers/db_connect_helper').db_connect()

filter = (id) ->
    return "function (doc, req) {\n" +
        "    if(doc._deleted) {\n" +
        "        return true; \n" +
        "    }\n" +
        "    if ((doc.docType && doc.docType === \"File\") " + 
        "|| (doc.docType && doc.docType === \"Folder\"))  {\n" +
        "        return true; \n"+
        "    } else if (doc._id === '_design/#{id}') {\n" +
        "        return true;\n"+ 
        "    } else { \n" +
        "        return false; \n" +
        "    }\n" +
        "}"

module.exports.get = (id) =>
    console.log id
    return filter(id)