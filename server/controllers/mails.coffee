nodemailer = require "nodemailer"
feed = require '../helpers/db_feed_helper'
checkDocType = require('../lib/token').checkDocType
User = require '../lib/user'
user = new User()

# Check if application is authorized to manage send any mail
module.exports.permissionSendMail = (req, res, next) ->
    auth = req.header 'authorization'
    checkDocType auth, "send mail",  (err, appName, isAuthorized) =>
        if not appName
            err = new Error "Application is not authenticated"
            res.send 401, error: err
        else if not isAuthorized
            err = new Error "Application is not authorized"
            res.send 403, error: err
        else
            feed.publish 'usage.application', appName
            next()

# Check if application is authorized to send a mail to user
module.exports.permissionSendMailToUser = (req, res, next) ->
    auth = req.header 'authorization'
    checkDocType auth, "send mail to user",  (err, appName, isAuthorized) =>
        if not appName
            err = new Error "Application is not authenticated"
            res.send 401, error: err
        else if not isAuthorized
            err = new Error "Application is not authorized"
            res.send 403, error: err
        else
            feed.publish 'usage.application', appName
            next()

# Check if application is authorized to send a mail from user
module.exports.permissionSendMailFromUser = (req, res, next) ->
    auth = req.header 'authorization'
    checkDocType auth, "send mail from user",  (err, appName, isAuthorized) =>
        if not appName
            err = new Error "Application is not authenticated"
            res.send 401, error: err
        else if not isAuthorized
            err = new Error "Application is not authorized"
            res.send 403, error: err
        else
            feed.publish 'usage.application', appName
            next()
# Helpers
sendEmail = (mailOptions, callback) =>
    transport = nodemailer.createTransport "SMTP", {}
    transport.sendMail mailOptions, (error, response) =>
        transport.close()
        callback error, response

checkBody = (res, body, attributes) =>
    for attr in attributes
        if not body[attr]?
            res.send 400, error: "Body has not all necessary attributes"

# POST /mail/
# Send an email with options given in body
module.exports.send = (req, res) ->
    body = req.body
    checkBody res, body, ['to', 'from', 'subject', 'content']
    mailOptions =
        to: body.to
        from: body.from
        subject: body.subject
        text: body.content
        html: body.html or undefined
    if body.attachments?
        mailOptions.attachments = body.attachments
    sendEmail mailOptions, (error, response) ->
        if error
            console.log "[sendMail] Error : " + error
            res.send 500, error: error
        else
            res.send 200, response


# POST /mail/to-user/
# Send an email to user with options given in body
module.exports.sendToUser = (req, res) ->
    body = req.body
    checkBody res, body, ['to', 'from', 'subject', 'content']
    user.getUser (err, user) ->
        if err
            console.log "[sendMailToUser] err: #{err}"
            res.send 500, error: err
        else
            mailOptions =
                to: user.email
                from: body.from
                subject: body.subject
                text: body.content
                html: body.html or undefined
            if body.attachments?
                mailOptions.attachments = body.attachments
            sendEmail mailOptions, (error, response) =>
                if error
                    console.log "[sendMail] Error : " + error
                    res.send 500, error: error
                else
                    res.send 200, response

# POST /mail/from-user/
# Send an email from user with options given in body
module.exports.sendFromUser = (req, res) ->
    body = req.body
    checkBody res, body, ['to', 'from', 'subject', 'content']
    user.getUser (err, user) ->
        if err
            console.log "[sendMailFromUser] err: #{err}"
            res.send 500, error: err
        else
            mailOptions =
                to: body.to
                from: user.email
                subject: body.subject
                text: body.content
                html: body.html or undefined
            if body.attachments?
                mailOptions.attachments = body.attachments
            sendEmail mailOptions, (error, response) =>
                if error
                    console.log "[sendMail] Error : " + error
                    res.send 500, error: error
                else
                    res.send 200, response
