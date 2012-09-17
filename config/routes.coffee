exports.routes = (map) ->
    # Data managing
    map.get '/data/exist/:id/', 'data#exist'
    map.get '/data/:id/', 'data#find'

    map.post '/data/', 'data#create'
    map.post '/data/:id/', 'data#create'

    map.put '/data/upsert/:id/', 'data#upsert'
    map.put '/data/merge/:id/', 'data#merge'
    map.put '/data/:id/', 'data#update'

    map.delete '/data/:id/', 'data#delete'

    #Request handling
    map.get '/request/:type/:req_name/', 'request#access'
    map.put '/request/:type/:req_name/', 'request#definition'
    map.delete '/request/:type/:req_name/', 'request#remove'
