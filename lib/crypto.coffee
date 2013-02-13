crypto = require("crypto")

class Crypto


    constructor: ->
        @masterKey = null

    genHash: (key) ->
        crypto.createHash('sha256').update(key).digest("binary")

    applySalt: (key, salt) ->
        key + salt

    genHashWithSalt: (key, salt) ->
    	newKey = key + salt
    	crypto.createHash('sha256').update(newKey).digest("binary")

    genSalt: (length) ->
            string = ""
            string += Math.random().toString(36).substr(2) while string.length < length
            string.substr 0, length

    encrypt: (key, data) ->
        cipher = crypto.createCipher("aes256", key)
        crypted = cipher.update(data, 'binary', 'binary')
        crypted += cipher.final('binary')
        crypted

    decrypt: (key, data) ->
        decipher = crypto.createDecipher("aes256", key)
        decrypted = decipher.update(data, 'binary', 'binary')
        decrypted += decipher.final('binary')
        decrypted


app.crypto = new Crypto()
