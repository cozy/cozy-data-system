logging = require '../../lib/logging'

module.exports = (compound) ->

	if process.env.NODE_ENV isnt "test"
	    console.log = () =>
		    logging.write.apply logging, arguments

	    console.info = () =>
	    	logging.write.apply logging, arguments

	    console.error = () =>
		    logging.write.apply logging, arguments

	    console.warm = () =>
		    logging.write.apply logging, arguments