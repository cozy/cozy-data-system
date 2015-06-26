// Generated by CoffeeScript 1.9.3
var client, db, feed;

feed = require('../lib/feed');

client = require('../lib/indexer');

db = require('../helpers/db_connect_helper').db_connect();

module.exports.index = function(req, res, next) {
  var data, field, mappedValue, ref;
  req.doc.id = req.doc._id;
  if (req.body.mappedValues != null) {
    ref = req.body.mappedValues;
    for (field in ref) {
      mappedValue = ref[field];
      req.doc[field] = mappedValue;
    }
  }
  data = {
    doc: req.doc,
    fields: req.body.fields,
    fieldsType: req.body.fieldsType
  };
  return client.post("index/", data, function(err, response, body) {
    if (err || response.statusCode !== 200) {
      return next(err);
    } else {
      res.send(200, {
        success: true
      });
      return next();
    }
  }, false);
};

module.exports.search = function(req, res, next) {
  var data, doctypes, showNumResults;
  doctypes = req.params.type || req.body.doctypes || [];
  showNumResults = req.body.showNumResults;
  data = {
    docType: doctypes,
    query: req.body.query,
    numPage: req.body.numPage,
    numByPage: req.body.numByPage,
    showNumResults: showNumResults
  };
  return client.post("search/", data, function(err, response, body) {
    if (err) {
      return next(err);
    } else if (response == null) {
      return next(new Error("Response not found"));
    } else if (response.statusCode !== 200) {
      return res.send(response.statusCode, body);
    } else {
      return db.get(body.ids, function(err, docs) {
        var doc, i, len, resDoc, resultObject, results;
        if (err) {
          return next(err);
        } else {
          results = [];
          for (i = 0, len = docs.length; i < len; i++) {
            doc = docs[i];
            if (doc.doc != null) {
              resDoc = doc.doc;
              resDoc.id = doc.id;
              results.push(resDoc);
            }
          }
          resultObject = {
            rows: results
          };
          if (showNumResults) {
            resultObject.numResults = body.numResults;
          }
          return res.send(200, resultObject);
        }
      });
    }
  });
};

module.exports.remove = function(req, res, next) {
  return client.del("index/" + req.params.id + "/", function(err, response, body) {
    if (err) {
      return next(err);
    } else {
      res.send(200, {
        success: true
      });
      return next();
    }
  }, false);
};

module.exports.removeAll = function(req, res, next) {
  return client.del("clear-all/", function(err, response, body) {
    if (err) {
      return next(err);
    } else {
      return res.send(200, {
        success: true
      });
    }
  }, false);
};
