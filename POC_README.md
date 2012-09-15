## POC Cloundfoundry

This Proof Of Concept is here to show how to configure the Data System through
an environment variable VCAP_SERVICES.

To use this version, just do as the README.md says. You can test the
configuration of the Data System through the variable by doing the following
changes.

## Setup

Change the content of the file couchdb.env.var to put the correct values.

Run tests

    VCAP_SERVICES=`cat couchdb.env.var` NODE_ENV='test' cake tests
