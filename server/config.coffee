americano = require 'americano'

config =
    common:
        use: [
            americano.bodyParser limit: '1gb'
            americano.methodOverride()
            americano.errorHandler
                dumpExceptions: true
                showStack: true
        ]

    development: [
        americano.logger 'dev'
    ]

    production: [
        americano.logger 'short'
    ]

    plugins: []

module.exports = config
