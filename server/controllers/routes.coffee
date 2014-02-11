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
    'data/': post: [data.permissions_param, data.encryptPassword, data.create]
    'data/:id/':
        get: [data.getDoc, data.permissions, data.decryptPassword, data.find]
        post: [data.permissions_param, data.encryptPassword, data.create]
        put: [utils.lockRequest, data.permissions_param, data.getDoc, data.encryptPassword, data.update, utils.unlockRequest]
        del: [utils.lockRequest, data.getDoc, data.permissions, data.delete, utils.unlockRequest]
    'data/exist/:id/': get: data.exist
    'data/upsert/:id/': put: [utils.lockRequest, data.permissions_param, data.encryptPassword, data.upsert, utils.unlockRequest]
    'data/merge/:id/': put: [utils.lockRequest, data.permissions_param, data.getDoc, data.permissions, data.encryptPassword2, data.merge, utils.unlockRequest]

    # Requests management
    'request/:type/:req_name/':
        post: [requests.permissions, requests.results]
        put: [requests.permissions, utils.lockRequest, requests.definition, utils.unlockRequest]
        del: [requests.permissions, utils.lockRequest, requests.remove, utils.unlockRequest]
    'request/:type/:req_name/destroy/': put: [requests.permissions, requests.removeResults]

    # Tags API
    'tags': get: requests.tags

    # Doctypes API
    'doctypes': get: requests.doctypes

    # File management
    # attachment API is deprecated
    'data/:id/attachments/': post: [utils.lockRequest, attachments.getDoc, attachments.permissions, attachments.add, utils.unlockRequest]
    'data/:id/attachments/:name':
        get: [attachments.getDoc, attachments.permissions, attachments.get]
        del: [utils.lockRequest, attachments.getDoc, attachments.permissions, attachments.remove, utils.unlockRequest]

    'data/:id/binaries/': post: [utils.lockRequest, binaries.getDoc, binaries.permissions, binaries.add, utils.unlockRequest]
    'data/:id/binaries/:name':
        get: [binaries.getDoc, binaries.permissions, binaries.get]
        del: [utils.lockRequest, binaries.getDoc, binaries.permissions, binaries.remove, utils.unlockRequest]

    # Scrapper connectors
    'connectors/bank/:name/': post: connectors.bank
    'connectors/bank/:name/history': post: connectors.bankHistory

    # Device management
    'device/': post: [devices.permissions, devices.create]
    'device/:id/': del: [devices.permissions, utils.lockRequest, devices.getDoc, devices.remove, utils.unlockRequest]

    # Indexer management
    'data/index/:id':
        post: [utils.lockRequest, indexer.index, utils.unlockRequest]
        del: [utils.lockRequest, indexer.remove, utils.unlockRequest]
    'data/search/:type': post: [indexer.permissionType, indexer.search]
    'data/index/clear-all/': del: [indexer.permissionAll, indexer.removeAll]

    # Mail management
    'mail/': post: [mails.permissionSendMail, mails.send]
    'mail/to-user': post: [mails.permissionSendMailToUser, mails.sendToUser]
    'mail/from-user': post: [mails.permissionSendMailFromUser, mails.sendFromUser]

    #User management
    'user/': post: [user.permissions_add, user.create]
    'user/merge/:id': put: [utils.lockRequest, user.permissions_add, user.permissions, user.getDoc, user.merge, utils.unlockRequest]

    #Account management
    'accounts/password/':
        post: [account.permission_keys, account.initializeKeys]
        put: [account.permission_keys, account.updateKeys]
    'accounts/reset/': del: [account.permission_keys, account.resetKeys]
    'accounts/': del: [account.permission_keys, account.deleteKeys]
