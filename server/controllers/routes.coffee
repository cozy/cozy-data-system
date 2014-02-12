# See documentation on https://github.com/frankrousseau/americano#routes

data = require './data'
requests = require './requests'
attachments = require './attachments'
binaries = require './binaries'
connectors = require './connectors'
devices = require './devices'
indexer = require './indexer'
mails = require './mails'
user = require './user'
account = require './accounts'

utils = require './utils'

module.exports =

    # Information page
    '':  get: data.index

    # Data management
    'data/': post: [
                utils.checkPermissionsByBody
                data.encryptPassword
                data.create
            ]
    'data/:id/':
        get: [
            utils.getDoc
            utils.checkPermissionsByDoc
            data.decryptPassword
            data.find
        ]
        post: [
            utils.checkPermissionsByBody
            data.encryptPassword
            data.create
        ]
        put: [
            utils.lockRequest
            utils.checkPermissionsByBody
            utils.getDoc
            data.encryptPassword
            data.update
            utils.unlockRequest
        ]
        del: [
            utils.lockRequest
            utils.getDoc
            utils.checkPermissionsByDoc
            data.delete
            utils.unlockRequest
        ]
    'data/exist/:id/': get: data.exist
    'data/upsert/:id/': put: [
        utils.lockRequest
        utils.checkPermissionsByBody
        data.encryptPassword
        data.upsert
        utils.unlockRequest
    ]
    'data/merge/:id/': put: [
        utils.lockRequest
        utils.checkPermissionsByBody
        utils.getDoc
        utils.checkPermissionsByDoc
        data.encryptPassword2
        data.merge
        utils.unlockRequest
    ]

    # Requests management
    'request/:type/:req_name/':
        post: [utils.checkPermissionsByType, requests.results]
        put: [
            utils.checkPermissionsByType
            utils.lockRequest
            requests.definition
            utils.unlockRequest
        ]
        del: [
            utils.checkPermissionsByType
            utils.lockRequest
            requests.remove
            utils.unlockRequest
        ]
    'request/:type/:req_name/destroy/': put: [
        utils.checkPermissionsByType
        requests.removeResults
    ]

    # Tags API
    'tags': get: requests.tags

    # Doctypes API
    'doctypes': get: requests.doctypes

    # File management
    # attachment API is deprecated
    'data/:id/attachments/': post: [
        utils.lockRequest
        utils.getDoc
        utils.checkPermissionsByDoc
        attachments.add
        utils.unlockRequest
    ]
    'data/:id/attachments/:name':
        get: [utils.getDoc, utils.checkPermissionsByDoc, attachments.get]
        del: [
            utils.lockRequest
            utils.getDoc
            utils.checkPermissionsByDoc
            attachments.remove
            utils.unlockRequest
        ]

    'data/:id/binaries/': post: [
        utils.lockRequest
        utils.getDoc
        utils.checkPermissionsByDoc
        binaries.add
        utils.unlockRequest
    ]
    'data/:id/binaries/:name':
        get: [utils.getDoc, utils.checkPermissionsByDoc, binaries.get]
        del: [
            utils.lockRequest
            utils.getDoc
            utils.checkPermissionsByDoc
            binaries.remove
            utils.unlockRequest
        ]

    # Scrapper connectors
    'connectors/bank/:name/': post: connectors.bank
    'connectors/bank/:name/history': post: connectors.bankHistory

    # Device management
    'device/': post: [utils.checkPermissionsFactory('device'), devices.create]
    'device/:id/': del: [
        utils.checkPermissionsFactory('device')
        utils.lockRequest
        utils.getDoc
        devices.remove
        utils.unlockRequest
    ]

    # Indexer management
    'data/index/:id':
        post: [utils.lockRequest, indexer.index, utils.unlockRequest]
        del: [utils.lockRequest, indexer.remove, utils.unlockRequest]
    'data/search/:type': post: [utils.checkPermissionsByType, indexer.search]
    'data/index/clear-all/': del: [
        utils.checkPermissionsFactory('all')
        indexer.removeAll
    ]

    # Mail management
    'mail/': post: [utils.checkPermissionsFactory('send mail'), mails.send]
    'mail/to-user': post: [
        utils.checkPermissionsFactory('send mail to user')
        mails.sendToUser
    ]
    'mail/from-user': post: [
        utils.checkPermissionsFactory('send mail from user')
        mails.sendFromUser
    ]

    #User management
    'user/': post: [utils.checkPermissionsFactory('User'), user.create]
    'user/merge/:id': put: [
        utils.lockRequest
        utils.checkPermissionsFactory('User')
        utils.getDoc
        user.merge
        utils.unlockRequest
    ]

    #Account management
    'accounts/password/':
        post: [account.checkPermissions, account.initializeKeys]
        put: [account.checkPermissions, account.updateKeys]
    'accounts/reset/': del: [account.checkPermissions, account.resetKeys]
    'accounts/': del: [account.checkPermissions, account.deleteKeys]
