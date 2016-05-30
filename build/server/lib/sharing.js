// Generated by CoffeeScript 1.10.0
var async, checkDomain, db, getDomain, log, request;

db = require('../helpers/db_connect_helper').db_connect();

async = require('async');

request = require('request-json');

log = require('printit')({
  prefix: 'sharing'
});

getDomain = function(callback) {
  return db.view('cozyinstance/all', function(err, instance) {
    var domain, ref;
    if (err != null) {
      return callback(err);
    }
    if ((instance != null ? (ref = instance[0]) != null ? ref.value.domain : void 0 : void 0) != null) {
      domain = instance[0].value.domain;
      if (!(domain.indexOf('http') > -1)) {
        domain = "https://" + domain + "/";
      }
      return callback(null, domain);
    } else {
      return callback(null);
    }
  });
};

checkDomain = function(params, callback) {
  if (params.hostUrl == null) {
    return getDomain(function(err, domain) {
      if ((err != null) || (domain == null)) {
        return callback(new Error('No instance domain set'));
      } else {
        params.hostUrl = domain;
        return callback(err, params);
      }
    });
  } else {
    return callback(null, params);
  }
};

module.exports.notifyTarget = function(path, params, callback) {
  return checkDomain(params, function(err, params) {
    var remote;
    remote = request.createClient(params.url);
    return remote.post(path, params, function(err, result, body) {
      if (err != null) {
        return callback(err);
      } else if ((result != null ? result.statusCode : void 0) == null) {
        err = new Error("Bad request");
        err.status = 400;
        return callback(err);
      } else if ((body != null ? body.error : void 0) != null) {
        err = body;
        err.status = result.statusCode;
        return callback(err);
      } else if ((result != null ? result.statusCode : void 0) !== 200) {
        err = new Error("The request has failed");
        err.status = result.statusCode;
        return callback(err);
      } else {
        return callback();
      }
    });
  });
};

module.exports.replicateDocs = function(params, callback) {
  var auth, err, replication, url;
  if (!((params.target != null) && (params.docIDs != null) && (params.id != null))) {
    err = new Error('Parameters missing');
    err.status = 400;
    return callback(err);
  } else {
    auth = params.id + ":" + params.target.token;
    url = params.target.url.replace("://", "://" + auth + "@");
    replication = {
      source: "cozy",
      target: url + "/services/sharing/replication/",
      continuous: params.continuous || false,
      doc_ids: params.docIDs
    };
    log.info("Replicate " + JSON.stringify(params.docIDs + " to " + url));
    return db.replicate(replication.target, replication, function(err, body) {
      if (err != null) {
        return callback(err);
      } else if (!body.ok) {
        err = "Replication failed";
        return callback(err);
      } else {
        return callback(null, body._local_id);
      }
    });
  }
};

module.exports.cancelReplication = function(replicationID, callback) {
  var cancel, err;
  if (replicationID == null) {
    err = new Error('Parameters missing');
    err.status = 400;
    return callback(err);
  } else {
    cancel = {
      replication_id: replicationID,
      cancel: true
    };
    return db.replicate('', cancel, function(err, body) {
      if (err != null) {
        return callback(err);
      } else if (!body.ok) {
        err = "Cancel replication failed";
        return callback(err);
      } else {
        return callback();
      }
    });
  }
};