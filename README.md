## [Cozy](http://cozy.io) Data System

Little API that act as a middleware between Cozy Platform applications and data
sent to the database, to the indexer and to the file system.
It manages application permissions and provide helpers to make Cozy app
development easier.


## Install

To set it up inside your cozy instance:

    # Get cozy monitor
    npm install cozy-monitor -g
    cozy-monitor install data-system

## Contribution

You can contribute to the Cozy Data System in many ways:

* Pick up an [issue](https://github.com/cozy/cozy-data-system/issues?state=open) and solve it.
* Add bulk features.
* Improve mass deletion.
* Write new tests.

## Hack

Install
[CouchDB](https://github.com/cozy/cozy-data-system/wiki/Couchdb-help)
(>= 1.2.0),
[NodeJS](https://github.com/cozy/cozy-data-system/wiki/Nodejs-help)
(>= 0.10.0) then:

    git clone git://github.com/cozy/cozy-data-system.git
    cd cozy-data-system

    # Load dependencies
    npm install

Once datasystem is installed, run it with:

    npm start # performs a node build/server.js

Or you can start it in dev mode with:

    coffee server.coffee

## Tests

[![Build
Status](https://travis-ci.org/cozy/cozy-data-system.png?branch=master)](https://travis-ci.org/cozy/cozy-data-system)

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

## About code coverage

The `cake coverage` command requires a bit of explanation. To achieve a proper code coverage, all CouchDB requests must be written in full javascript, otherwise the tests cannot work (since the coffee source is compiled with a special version).

## License

Cozy Data System is developed by Cozy Cloud and distributed under the AGPL v3 license.

## What is Cozy?

![Cozy Logo](https://raw.github.com/cozy/cozy-setup/gh-pages/assets/images/happycloud.png)

[Cozy](http://cozy.io) is a platform that brings all your web services in the
same private space.  With it, your web apps and your devices can share data
easily, providing you
with a new experience. You can install Cozy on your own hardware where no one
profiles you. 

## Community 

You can reach the Cozy Community by:

* Chatting with us on IRC #cozycloud on irc.freenode.net
* Posting on our [Forum](https://forum.cozy.io/)
* Posting issues on the [Github repos](https://github.com/cozy/)
* Mentioning us on [Twitter](http://twitter.com/mycozycloud)
