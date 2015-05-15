nodemailer = require "nodemailer"
logger = require('printit')
    date: false
    prefix: 'controllers:mails'
User = require '../lib/user'
user = new User()
db = require('../helpers/db_connect_helper').db_connect()

# Helpers
sendEmail = (mailOptions, callback) ->
    transport = nodemailer.createTransport "SMTP", {}
    transport.sendMail mailOptions, (error, response) ->
        transport.close()
        callback error, response

checkBody = (body, attributes) ->
    missingAttributes = []
    for attr in attributes
        missingAttributes.push attr if not body[attr]?

    return missingAttributes

# POST /mail/
# Send an email with options given in body
module.exports.send = (req, res, next) ->
    body = req.body
    missingAttributes = checkBody body, ['to', 'from', 'subject', 'content']

    if missingAttributes.length > 0
        attrs = missingAttributes.join " "
        err = new Error "Body has at least one missing attribute (#{attrs})."
        err.status = 400
        next err
    else
        mailOptions =
            to: body.to
            from: body.from
            subject: body.subject
            cc: body.cc
            bcc: body.bcc
            replyTo: body.replyTo
            inReplyTo: body.inReplyTo
            references: body.references
            headers: body.headers
            alternatives: body.alternatives
            envelope: body.envelope
            messageId: body.messageId
            date: body.date
            encoding: body.encoding
            text: body.content
            html: body.html or undefined

        if body.attachments?
            mailOptions.attachments = body.attachments.map (attachment) ->
                newAttach =
                    filename: attachment.filename
                    contents: new Buffer attachment.content.split(",")[1], 'base64'

        sendEmail mailOptions, (error, response) ->
            if error
                logger.info "[sendMail] Error : " + error
                error.code = 'postfix_unavailable'
                error.status = 501
                next error
            else
                res.send 200, response


# POST /mail/to-user/
# Send an email to user with options given in body
module.exports.sendToUser = (req, res, next) ->
    body = req.body
    missingAttributes = checkBody body, ['from', 'subject', 'content']

    if missingAttributes.length > 0
        attrs = missingAttributes.join " "
        err = new Error "Body has at least one missing attribute (#{attrs})."
        err.status = 400
        next err
    else
        user.getUser (err, user) ->
            if err
                logger.info "[sendMailToUser] err: #{err}"
                next err
            else
                mailOptions =
                    to: user.email
                    from: body.from
                    subject: body.subject
                    text: body.content
                    html: body.html or undefined
                if body.attachments?
                    mailOptions.attachments = body.attachments
                sendEmail mailOptions, (error, response) ->
                    if error
                        logger.info "[sendMail] Error : " + error
                        error.code = 'postfix_unavailable'
                        error.status = 501
                        next error
                    else
                        res.send 200, response

# POST /mail/from-user/
# Send an email from user with options given in body
module.exports.sendFromUser = (req, res, next) ->
    body = req.body
    missingAttributes = checkBody body, ['to', 'subject', 'content']

    if missingAttributes.length > 0
        attrs = missingAttributes.join " "
        err = new Error "Body has at least one missing attribute (#{attrs})."
        err.status = 400
        next err
    else
        db.view 'cozyinstance/all', (err, instance) ->
            db.view 'user/all', (err, users) ->
                if instance?[0]?.value.domain?
                    domain = instance[0].value.domain
                    if domain.indexOf('https://') isnt -1
                        domain = domain.substring(8, domain.length)
                else
                    domain = 'your.cozy.io'

                # retrieves and slugifies the username if it exists
                if users?[0]?.value.public_name? and
                    users?[0]?.value.public_name? isnt ''
                        displayName = users[0].value.public_name
                        displayName = displayName.toLowerCase()
                                                 .replace ' ', '-'
                        displayName += "-"
                else
                    displayName = ''

                mailOptions =
                    to: body.to
                    from: "#{displayName}noreply@#{domain}"
                    subject: body.subject
                    text: body.content
                    html: body.html or undefined
                if body.attachments?
                    mailOptions.attachments = body.attachments
                sendEmail mailOptions, (error, response) ->
                    if error
                        logger.info "[sendMail] Error : " + error
                        error.code = 'postfix_unavailable'
                        error.status = 501
                        next error
                    else
                        res.send 200, response
