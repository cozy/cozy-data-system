// Generated by CoffeeScript 1.7.1
var db;

db = require('../helpers/db_connect_helper').db_connect();

exports.remove = (function(_this) {
  return function(doc, callback) {
    var deletedDoc, _ref;
    deletedDoc = {
      "_rev": doc.rev,
      "_deleted": true
    };
    if (doc.docType != null) {
      deletedDoc.docType = doc.docType;
    }
    if (((_ref = doc.binary) != null ? _ref.file : void 0) != null) {
      deletedDoc.binary = doc.binary;
    }
    return db.save(doc._id, deletedDoc, callback);
  };
})(this);
