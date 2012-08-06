exports.routes = (map) ->
    map.get '/data/exist/:id/', 'data#exist'
    map.get '/data/:id/', 'data#find'
