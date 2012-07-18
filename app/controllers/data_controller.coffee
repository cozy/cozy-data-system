load 'application'


action 'exist', ->
    db.get params.id, (err, doc) ->
        send exist: doc?

