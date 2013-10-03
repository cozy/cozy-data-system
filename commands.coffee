Client = require("request-json").JsonClient

switch  process.argv[2]
    when 'test-install'
        permFile = process.argv[3] or '../package.json'
        packagePath = path.join process.cwd(), process.argv[3]

        try
            packageData = JSON.parse(fs.readFileSync(packagePath, 'utf8'))
        catch e
            console.log "Could not read package.json"
            console.log e.stack
            process.exit 2

        data =
            docType: "Application"
            state: 'installed'
            slug: slug
            name: slug
            password: 'apptoken'
            permissions: {}
            port: port

        for doctype, perm of packageData['cozy-permissions']
            data.permissions[doctype.toLowerCase()] = perm

        client = new Client dataSystemUrl
        client.setBasicAuth 'home', 'token'
        client.post "data/", data, (err, res, body) ->
            if err
                console.log "Cannot create app"
                console.log err.stack
                process.exit 3

            console.log "App created"
            process.exit 0

    else
        console.log "Wrong commang"
        process.exit 1