exports.routes = (map) ->

    map.get '/', 'data#index'

    # Data managing
    map.get '/data/exist/:id/', 'data#exist'
    map.get '/data/:id/', 'data#find'

    map.post '/data/', 'data#create'
    map.post '/data/:id/', 'data#create'

    map.put '/data/upsert/:id/', 'data#upsert'
    map.put '/data/merge/:id/', 'data#merge'
    map.put '/data/:id/', 'data#update'

    map.delete '/data/:id/', 'data#delete'

    # Indexation
    map.post '/data/index/:id', 'index#index'
    map.post '/data/search/:type', 'index#search'
    map.delete '/data/index/clear-all/', 'index#removeAll'
    map.delete '/data/index/:id', 'index#remove'

    # Browser connectors
    map.post '/connectors/bank/:name/', 'connector#bank'

    # File management
    map.post '/data/:id/attachments/', 'attachment#addAttachment'
    map.get '/data/:id/attachments/:name', 'attachment#getAttachment'
    map.delete '/data/:id/attachments/:name', 'attachment#removeAttachment'

    #Request handling
    map.post '/request/:type/:req_name/', 'request#results'
    map.put '/request/:type/:req_name/destroy/', 'request#removeResults'
    map.put '/request/:type/:req_name/', 'request#definition'
    map.delete '/request/:type/:req_name/', 'request#remove'

    #Account management
    map.post '/accounts/password/', 'account#initializeKeys'
    map.delete '/accounts/', 'account#deleteKeys'

    map.post '/account/', 'account#createAccount'
    map.post '/account/:id/', 'account#createAccount'
    map.get '/account/:id/', 'account#findAccount'
    map.get '/account/exist/:id/', 'account#existAccount'
    map.put '/account/:id/', 'account#updateAccount'
    map.put '/account/merge/:id/', 'account#mergeAccount'
    map.delete '/account/:id/', 'account#deleteAccount'