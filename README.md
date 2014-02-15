## Cozy Data System

Little API that act as a middleware between applications and data sent to the
database, to the indexer and to the file system.

## Setup

Install
[CouchDB](https://github.com/mycozycloud/cozy-data-system/wiki/Couchdb-help)
(1.2.0),
[NodeJS](https://github.com/mycozycloud/cozy-data-system/wiki/Nodejs-help)
(> 0.8.0) then:

    git clone git://github.com/mycozycloud/cozy-data-system.git
    cd cozy-data-system

    # Load dependencies
    npm install

Once datasystem is installed, run it with:

    npm start # performs a node build/server.js

Or you can start it in dev mode with:

    coffee server.coffee

## Cozy instance setup

To set it up inside your cozy instance:

    # Get cozy monitor
    npm install cozy-monitor -g
    cozy-monitor install data-system

## Tests

[![Build
Status](https://travis-ci.org/mycozycloud/cozy-data-system.png?branch=master)](https://travis-ci.org/mycozycloud/cozy-data-system)

Run tests with following commmand

    cake tests


## Before submitting a pull request
* Make sure the tests pass
* Make sure you've built your modification:

```bash
cake tests
cake check-build
cake build
```

You can also use the provided hook:

```bash
cp pre-push .git/hooks/
```

# About code coverage
The `cake coverage` command requires a bit of explanation. To achieve a proper code coverage, all CouchDB requests must be written in full javascript, otherwise the tests cannot work (since the coffee source is compiled with a special version).

# About Cozy

Cozy Data System is part of the Cozy platform backend. Cozy is the personal
server for everyone. It allows you to install your every day web applications
easily on your server, a single place you control. This means you can manage
efficiently your data while protecting your privacy without technical skills.

More informations and hosting services on:
http://www.cozycloud.cc

# Cozy on IRC
Feel free to check out our IRC channel (#cozycloud on irc.freenode.org) if you have any technical issues/inquiries or simply to speak about Cozy cloud in general.
