crypto = require("crypto")

class Crypto


    constructor: ->
        @masterKey = ""

    genHash: (key) ->
        crypto.createHash('sha1').update(key).digest("hex")

    applySalt: (key, salt) ->
        key + salt

    genHashWithSalt: (key, salt) ->
    	newKey = applySalt(key, salt)
    	genHash(newKey)

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
