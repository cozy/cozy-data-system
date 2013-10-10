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
    map.post '/connectors/bank/:name/history', 'connector#bankHistory'

    # File management
    map.post '/data/:id/attachments/', 'attachment#addAttachment'
    map.get '/data/:id/attachments/:name', 'attachment#getAttachment'
    map.delete '/data/:id/attachments/:name', 'attachment#removeAttachment'

    # Request handling
    map.get '/doctypes', 'request#doctypes'
    map.post '/request/:type/:req_name/', 'request#results'
    map.put '/request/:type/:req_name/destroy/', 'request#removeResults'
    map.put '/request/:type/:req_name/', 'request#definition'
    map.delete '/request/:type/:req_name/', 'request#remove'

    # Filter handling
    map.put '/filter/:req_name/', 'filter#definition'
    map.delete '/filter/:req_name/', 'filter#remove'

    #Account management
    map.post '/accounts/password/', 'account#initializeKeys'
    map.put '/accounts/password/', 'account#updateKeys'
    map.delete '/accounts/reset/', 'account#resetKeys'
    map.delete '/accounts/', 'account#deleteKeys'
    map.delete '/account/all/', 'account#deleteAllAccounts'

    map.post '/account/', 'account#createAccount'
    map.post '/account/:id/', 'account#createAccount'
    map.get '/account/:id/', 'account#findAccount'
    map.get '/account/exist/:id/', 'account#existAccount'
    map.put '/account/:id/', 'account#updateAccount'
    map.put '/account/merge/:id/', 'account#mergeAccount'
    map.put '/account/upsert/:id/', 'account#upsertAccount'
    map.delete '/account/:id/', 'account#deleteAccount'

    #DocType management
    map.post '/doctype/', 'doctype#create'
    map.post '/doctype/:id', 'doctype#create'
    map.delete '/doctype/:id', 'doctype#delete'

    # Mail management
    map.post '/mail/', 'mail#sendMail'
    map.post '/mail/to-user', 'mail#sendMailToUser'
    map.post '/mail/from-user', 'mail#sendMailFromUser'
