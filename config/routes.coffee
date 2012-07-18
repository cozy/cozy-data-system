exports.routes = (map) ->
    map.post '/data/:type/exist/', 'data#exist'
