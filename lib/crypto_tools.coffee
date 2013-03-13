crypto = require("crypto")


module.exports = class CryptoTools


    constructor: ->
        @masterKey = null
        @slaveKey = null

    # Generate a hash of data with the algorithm sha256
    genHash: (data) ->
        crypto.createHash('sha256').update(data).digest('binary')

    # Apply a salt to the data 'data'
    applySalt: (data, salt) ->
        data + salt

    # Generate a hash of data with a salt with the algorithm sha256
    genHashWithSalt: (data, salt) ->
     newData = data + salt
     crypto.createHash('sha256').update(newData).digest('binary')

    # Generate a salt with a length of 'length'
    genSalt: (length) ->
        string = ""
        while string.length < length
            string += Math.random().toString(36).substr(2)
        string.substr 0, length

    # Encrypt the data with the algorithm AES-256 and the key 'key',
    # return the encrypted data
    encrypt: (key, data) ->
        cipher = crypto.createCipher 'aes-256-cbc', key.toString()
        crypted = cipher.update data.toString(), 'binary', 'base64'
        crypted += cipher.final 'base64'
        crypted

    # Decrypt the data with the algorithm AES-256 and the key 'key'
    # return the decrypted data
    decrypt: (key, data) ->
        decipher = crypto.createDecipher 'aes-256-cbc', key.toString()
        decrypted = decipher.update data.toString(), 'base64', 'utf8'
        decrypted += decipher.final 'utf8'
        decrypted