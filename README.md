## Cozy Data System

Little API that act as a middleware between applications and data sent to the 
database, to the indexer and to the file system.

## Setup 

Install CouchDB, NodeJS then clone this repository.

Load submodules

    git submodule init
    git submodule update

Load dependencies

    npm install

Run tests

    NODE_ENV="test" cake tests

Then, run server

    coffee server.coffee


# About Cozy

Cozy Data System is part of the Cozy platform backend. Cozy is the personal
server for everyone. It allows you to install your every day web applications 
easily on your server, a single place you control. This means you can manage 
efficiently your data while protecting your privacy without technical skills.

More informations and hosting services on:
http://www.mycozycloud.com
