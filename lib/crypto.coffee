crypto = require("crypto")

class Crypto


    constructor: ->
        @masterKey = null
        @slaveKey = null

    genHash: (key) ->
        crypto.createHash('sha256').update(key).digest('binary')

    applySalt: (key, salt) ->
        key + salt

    genHashWithSalt: (key, salt) ->
    	newKey = key + salt
    	crypto.createHash('sha256').update(newKey).digest('binary')

    genSalt: (length) ->
        string = ""
        while string.length < length
            string += Math.random().toString(36).substr(2) 
        string.substr 0, length

    encrypt: (key, data) ->
        cipher = crypto.createCipher('aes-256-cbc', key.toString())
        crypted = cipher.update(data.toString(), 'binary', 'base64')
        crypted += cipher.final 'base64'
        crypted

    decrypt: (key, data) ->
        decipher = crypto.createDecipher('aes-256-cbc', key.toString())
        decrypted = decipher.update(data.toString(), 'base64', 'utf8')
        decrypted += decipher.final 'utf8'
        decrypted


app.crypto = new Crypto()