should = require('chai').Should()
async = require('async')
Client = require('request-json').JsonClient
app = require('../server')

client = new Client("http://localhost:7000/")

# connection to DB for "hand work"
cradle = require 'cradle'
connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database('cozy')

# helpers

# Clear DB, create a new one, then init data for tests.
before (done) ->
    db.destroy ->
        console.log 'DB destroyed'
        db.create ->
            console.log 'DB recreated'
            db.save '321', {"value":"val"}, ->
                done()
       
createNoteFunction = (title, content) ->
    (callback) ->
        note =
            title: title
            content: content
            docType: "Note"


        client.post "data/", note, (error, response, body) ->
            client.post "data/index/#{body._id}",
                fields: ["title", "content"]
                , callback


        
# Start application before starting tests.
before (done) ->
    app.listen(8888)
    done()

# Stop application after finishing tests.
after (done) ->
    app.close()
    done()

describe "indexing", ->
    it "Given I index four notes", (done) ->
        async.series [
            createNoteFunction "Note 01", "little stories begin"
            createNoteFunction "Note 02", "great dragons are coming"
            createNoteFunction "Note 03", "small hobbits are afraid"
            createNoteFunction "Note 04", "such as humans"
        ], ->
            done()
        
        
    it "When I send a request to search the notes containing dragons", (done) ->
        client.post "data/search", { query: "dragons", docType: "Note" }, \
                (error, response, body) =>
            @result = body
            done()

    it "Then result is the second note I created", ->
        console.log @result
        @result.rows.length.should.equal 1
        @result.rows[0].title.should.equal "Note 02"
        @result.rows[0].content.should.equal "great dragons are coming"


