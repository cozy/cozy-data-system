# TODO debug forgery with singe page application
#before 'protect from forgery', ->
#    protectFromForgery '014bab01fb364db464d3f1c9a4c4fe8e4032ed0b'


if app.settings.env == "production"
    before 'check authentication', ->
        if req.isAuthenticated() then next() else send 403

