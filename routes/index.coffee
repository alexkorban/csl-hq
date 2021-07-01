exports.index = (req, res) =>
    # the request token should only be set in the dev environment (when running on localhost).
    # This is because the mobile app also sets origin as localhost
    title =
        switch req.headers.host
            when "www.myvirtualsuper.com"
                "Virtual Super"
            when "localhost:5000"
                "LocalHQ"
            else
                "HQ"

    res.render "index", { title: title }
