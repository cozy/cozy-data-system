nodemailer = require "nodemailer"
logger = require('printit')
    date: false
    prefix: 'controllers:mails'
User = require '../lib/user'
user = new User()

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
            mailOptions.attachments = body.attachments
        sendEmail mailOptions, (error, response) ->
            if error
                logger.info "[sendMail] Error : " + error
                next new Error error
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
                next new Error err
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
                        next new Error error
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
        user.getUser (err, user) ->
            if err
                logger.info "[sendMailFromUser] err: #{err}"
                next new Error err
            else
                mailOptions =
                    to: body.to
                    from: user.email
                    subject: body.subject
                    text: body.content
                    html: body.html or undefined
                if body.attachments?
                    mailOptions.attachments = body.attachments
                sendEmail mailOptions, (error, response) ->
                    if error
                        logger.info "[sendMail] Error : " + error
                        next new Error error
                    else
                        res.send 200, response
