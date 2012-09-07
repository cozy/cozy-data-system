exports.routes = (map) ->
    map.get '/data/exist/:id/', 'data#exist'
    map.get '/data/:id/', 'data#find'

    map.post '/data/', 'data#create'
    map.post '/data/:id/', 'data#create'

    map.put '/data/upsert/:id/', 'data#upsert'
    map.put '/data/merge/:id/', 'data#merge'
    map.put '/data/:id/', 'data#update'

    map.delete '/data/:id/', 'data#delete'
    
    map.post '/data/index/:id', 'index#index'
    map.post '/data/search/:type', 'index#search'
    map.delete '/data/index/:id', 'index#remove'
