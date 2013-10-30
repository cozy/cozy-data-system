User = require './lib/user'
user = new User()
nodemailer = require "nodemailer"
checkDocType = require('./lib/token').checkDocType

# Check if application is authorized to manage send any mail
before 'permissionSendMail', ->
    auth = req.header('authorization')
    checkDocType auth, "send mail",  (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            compound.app.feed.publish 'usage.application', appName
            next()
, only: ['sendMail']

# Check if application is authorized to send a mail to user
before 'permissionSendMail', ->
    auth = req.header('authorization')
    checkDocType auth, "send mail to user",  (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            compound.app.feed.publish 'usage.application', appName
            next()
, only: ['sendMailToUser']

# Check if application is authorized to send a mail from user
before 'permissionSendMail', ->
    auth = req.header('authorization')
    checkDocType auth, "send mail from user",  (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            compound.app.feed.publish 'usage.application', appName
            next()
, only: ['sendMailFromUser']

# Helpers
sendEmail = (mailOptions, callback) =>
    transport = nodemailer.createTransport "SMTP", {}
    transport.sendMail mailOptions, (error, response) =>
        transport.close()
        callback error, response

checkBody = (attributes) =>
    for attr in attributes
        if not body[attr]?
            send error: "Body has not all necessary attributes", 400

# POST /mail/
# Send an email with options given in body
action 'sendMail', =>
    checkBody ['to', 'from', 'subject', 'text', 'html']
    mailOptions =
        to: body.to
        from: body.from
        subject: body.subject
        text: body.text
        html: body.html
    if body.attachments?
        mailOptions.attachments = body.attachments
    sendEmail mailOptions, (error, response) =>
        if error
            console.log "[sendMail] Error : " + error
            send error: error, 500
        else
            send response, 200


# POST /mail/to-user/
# Send an email to user with options given in body
action 'sendMailToUser', =>
    checkBody ['from', 'subject', 'text', 'html']
    user.getUser (err, user) ->
        if err
            console.log "[sendMailToUser] err: #{err}"
            send 500
        else
            mailOptions =
                to: user.email
                from: body.from
                subject: body.subject
                text: body.text
                html: body.html
            if body.attachments?
                mailOptions.attachments = body.attachments
            sendEmail mailOptions, (error, response) =>
                if error
                    console.log "[sendMail] Error : " + error
                    send error: error, 500
                else
                    send response, 200

# POST /mail/from-user/
# Send an email from user with options given in body
action 'sendMailFromUser', =>
    checkBody ['to', 'subject', 'text', 'html']
    user.getUser (err, user) ->
        if err
            console.log "[sendMailFromUser] err: #{err}"
            send 500
        else
            mailOptions =
                to: body.to
                from: user.email
                subject: body.subject
                text: body.text
                html: body.html
            if body.attachments?
                mailOptions.attachments = body.attachments
            sendEmail mailOptions, (error, response) =>
                if error
                    console.log "[sendMail] Error : " + error
                    send error: error, 500
                else
                    send response, 200