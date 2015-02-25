// Generated by CoffeeScript 1.9.0
var Client, CryptoTools, User, checkProxyHome, correctWitness, cryptoTools, db, encryption, errors, randomString, user;

db = require('../helpers/db_connect_helper').db_connect();

encryption = require('../lib/encryption');

Client = require("request-json").JsonClient;

CryptoTools = require('../lib/crypto_tools');

User = require('../lib/user');

randomString = require('../lib/random').randomString;

checkProxyHome = require('../lib/token').checkProxyHome;

errors = require('../middlewares/errors');

cryptoTools = new CryptoTools();

user = new User();

correctWitness = "Encryption is correct";

module.exports.checkPermissions = function(req, res, next) {
  return checkProxyHome(req.header('authorization'), function(err, isAuthorized) {
    if (!isAuthorized) {
      return next(errors.notAuthorized());
    } else {
      return next();
    }
  });
};

module.exports.initializeKeys = function(req, res, next) {
  if (req.body.password == null) {
    return next(errors.http(400, "No password field in request's body"));
  }
  return user.getUser(function(err, user) {
    if (err) {
      console.log("[initializeKeys] err: " + err);
      return next(err);
    }
    if ((user.salt != null) && (user.slaveKey != null)) {
      return encryption.logIn(req.body.password, user, function(err) {
        if (err) {
          return next(err);
        } else {
          return res.send(200, {
            success: true
          });
        }
      });
    } else {
      return encryption.init(req.body.password, user, function(err) {
        if (err) {
          return next(err);
        } else {
          return res.send(200, {
            success: true
          });
        }
      });
    }
  });
};

module.exports.updateKeys = function(req, res, next) {
  if (req.body.password == null) {
    return next(errors.http(400, "No password field in request's body"));
  }
  return user.getUser(function(err, user) {
    if (err) {
      console.log("[updateKeys] err: " + err);
      return next(err);
    } else {
      return encryption.update(req.body.password, user, function(err) {
        if (err) {
          return next(err);
        } else {
          return res.send(200, {
            success: true
          });
        }
      });
    }
  });
};

module.exports.resetKeys = function(req, res, next) {
  return user.getUser(function(err, user) {
    if (err) {
      console.log("[initializeKeys] err: " + err);
      return next(err);
    }
    return encryption.reset(user, function(err) {
      if (err) {
        return next(err);
      }
      return res.send(204, {
        success: true
      });
    });
  });
};

module.exports.deleteKeys = function(req, res) {
  return res.send(204, {
    sucess: true
  });
};
