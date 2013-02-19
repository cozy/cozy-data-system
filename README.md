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
    
    # Load submodules
    git submodule init
    git submodule update

    # Load dependencies
    npm install

Once datasystem is installed, run it with:

    coffee server

## Cozy instance setup

To set it up inside your cozy instance:

    # Get cozy monitor
    git clone git://github.com/mycozycloud/cozy-setup.git
    cd cozy-setup
    npm install

    # Then install data system:
    coffee monitor install data-system
    
## Tests

Run tests with following commmand

    NODE_ENV="test" cake tests

NB: Indexation tests required that 
[Cozy Indexer](https://github.com/mycozycloud/cozy-data-indexer) to be up.

# About Cozy

Cozy Data System is part of the Cozy platform backend. Cozy is the personal
server for everyone. It allows you to install your every day web applications 
easily on your server, a single place you control. This means you can manage 
efficiently your data while protecting your privacy without technical skills.

More informations and hosting services on:
http://www.cozycloud.cc

# Cozy on IRC
Feel free to check out our IRC channel (#cozycloud on irc.freenode.org) if you have any technical issues/inquiries or simply to speak about Cozy cloud in general.
