if process.env.VCAP_SERVICES?
    env = JSON.parse process.env.VCAP_SERVICES
    console.log JSON.stringify env, null, 4
