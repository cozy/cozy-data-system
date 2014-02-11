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

module.exports =

    # Information page
    '':  get: data.index

    # Data management
    'data/': post: [data.permissions_param, data.encryptPassword, data.create]
    'data/:id/':
        get: [data.getDoc, data.permissions, data.decryptPassword, data.find]
        post: [data.permissions_param, data.encryptPassword, data.create]
        put: [data.lockRequest, data.permissions_param, data.getDoc, data.encryptPassword, data.update, data.unlockRequest]
        del: [data.lockRequest, data.getDoc, data.permissions, data.delete, data.unlockRequest]
    'data/exist/:id/': get: data.exist
    'data/upsert/:id/': put: [data.lockRequest, data.permissions_param, data.encryptPassword, data.upsert, data.unlockRequest]
    'data/merge/:id/': put: [data.lockRequest, data.permissions_param, data.getDoc, data.permissions, data.encryptPassword2, data.merge, data.unlockRequest]

    # Requests management
    'request/:type/:req_name/':
        post: [requests.permissions, requests.results]
        put: [requests.permissions, requests.lockRequest, requests.definition, requests.unlockRequest]
        del: [requests.permissions, requests.lockRequest, requests.remove, requests.unlockRequest]
    'request/:type/:req_name/destroy/': put: [requests.permissions, requests.removeResults]

    # Tags API
    'tags': get: requests.tags

    # Doctypes API
    'doctypes': get: requests.doctypes

    # File management
    # attachment API is deprecated
    'data/:id/attachments/': post: [attachments.lockRequest, attachments.getDoc, attachments.permissions, attachments.add, attachments.unlockRequest]
    'data/:id/attachments/:name':
        get: [attachments.getDoc, attachments.permissions, attachments.get]
        del: [attachments.lockRequest, attachments.getDoc, attachments.permissions, attachments.remove, attachments.unlockRequest]

    'data/:id/binaries/': post: [binaries.lockRequest, binaries.getDoc, binaries.permissions, binaries.add, binaries.unlockRequest]
    'data/:id/binaries/:name':
        get: [binaries.getDoc, binaries.permissions, binaries.get]
        del: [binaries.lockRequest, binaries.getDoc, binaries.permissions, binaries.remove, binaries.unlockRequest]

    # Scrapper connectors
    'connectors/bank/:name/': post: connectors.bank
    'connectors/bank/:name/history': post: connectors.bankHistory

    # Device management
    'device/': post: [devices.permissions, devices.create]
    'device/:id/': del: [devices.permissions, devices.lockRequest, devices.getDoc, devices.remove, devices.unlockRequest]

    # Indexer management
    'data/index/:id':
        post: [indexer.lockRequest, indexer.index, indexer.unlockRequest]
        del: [indexer.lockRequest, indexer.remove, indexer.unlockRequest]
    'data/search/:type': post: [indexer.permissionType, indexer.search]
    'data/index/clear-all/': del: [indexer.permissionAll, indexer.removeAll]

    # Mail management
    'mail/': post: [mails.permissionSendMail, mails.send]
    'mail/to-user': post: [mails.permissionSendMailToUser, mails.sendToUser]
    'mail/from-user': post: [mails.permissionSendMailFromUser, mails.sendFromUser]

    #User management
    'user/': post: [user.permissions_add, user.create]
    'user/merge/:id': put: [user.lockRequest, user.permissions_add, user.permissions, user.getDoc, user.merge, user.unlockRequest]

    #Account management
    'accounts/password/':
        post: [account.permission_keys, account.initializeKeys]
        put: [account.permission_keys, account.updateKeys]
    'accounts/reset/': del: [account.permission_keys, account.resetKeys]
    'accounts/': del: [account.permission_keys, account.deleteKeys]
