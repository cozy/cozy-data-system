nodemailer = require "nodemailer"
User = require '../lib/user'
user = new User()

# Helpers
sendEmail = (mailOptions, callback) ->
    transport = nodemailer.createTransport "SMTP", {}
    transport.sendMail mailOptions, (error, response) ->
        transport.close()
        callback error, response

checkBody = (res, body, attributes) ->
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
            sendEmail mailOptions, (error, response) ->
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
            sendEmail mailOptions, (error, response) ->
                if error
                    console.log "[sendMail] Error : " + error
                    res.send 500, error: error
                else
                    res.send 200, response
