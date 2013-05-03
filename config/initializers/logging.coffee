module.exports = (compound) ->
    console.log = (text) ->
        compound.logger.write text

    console.info = (text) ->
        compound.logger.write text

    console.err = (text) ->
        compound.logger.write text

    console.warn = (text) ->
        compound.logger.write text
