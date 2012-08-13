exports.routes = (map) ->
    map.get '/data/exist/:id/', 'data#exist'
    map.get '/data/:id/', 'data#find'

    map.post '/data/', 'data#create'
    map.post '/data/:id/', 'data#create'
