uplink =
    URL: (
        if location.hostname == "localhost" || location.hostname == "127.0.0.1" || /\.vm$/.test(location.hostname)
            "http://#{location.hostname}:3000"
        else if location.hostname.indexOf("-staging") != -1
            "https://csl-safesitenode-staging.herokuapp.com"
        else
            "https://csl-safesitenode.herokuapp.com"
        ) + "/v5"  # API version
    xhrPool: []

uplinkPromise = (type, path, data, unauthorisedHandler, permissionDeniedHandler) ->
    new Promise (resolve, reject) ->
        reqParams =
            url: "#{uplink.URL}/#{path}"
            type: type
            contentType: "application/json"
            timeout: 60 * 1000
            #xhrFields: withCredentials: true  # allow cross-domain sending of session cookie
            beforeSend: exceptionator.wrap (xhr, settings) ->
                uplink.xhrPool.push xhr
                sessionId = store.getState().sessionId
                if !R.isEmpty sessionId
                    xhr.setRequestHeader "SessionID", sessionId
            complete: (xhr) ->
                Tracer.log "Completing XHR"
                uplink.xhrPool = R.reject ((x) -> x == xhr), uplink.xhrPool
            dataType: "json"

        debugParams = R.filter(R.identity, store.getState().debug)
        fullData = R.merge data, if !R.isEmpty debugParams then debug: debugParams else {}

        if type == "POST"
            reqParams.data = JSON.stringify fullData
        else if type == "GET"
            if !R.isEmpty fullData
                reqParams.url += "?" + $.param fullData  #"?data=" + encodeURIComponent JSON.stringify data
            else
                # No params to encode
        else
            # Do nothing, we only handle GET and POST

        $.ajax(reqParams)
        .then exceptionator.wrap (res) -> resolve res
        .fail exceptionator.wrap (error) ->
            if error.status == 401
                unauthorisedHandler()
            else if error.status == 403
                permissionDeniedHandler()
            else
                # Only default handling for other error codes

            e = new Error "AJAX error: #{error.status} - #{error.statusText}"
            e.readyState = error.readyState; e.status = error.status; e.statusText = error.statusText
            e.responseText = error.responseText
            if e.status == 401 || e.status == 403 || e.status == 0
                e.suppressUnhandledRejection = true
            else
                # Other error codes are not something we expect, so don't suppress error handling
            reject e
    .catch (error) ->
        Tracer.log "Request failed in uplink: #{JSON.stringify error}"
        Promise.reject error



module.exports = (unauthorisedHandler, permissionDeniedHandler) ->
    R.merge uplink,
        get: (path, data = {}) ->
            uplinkPromise "GET", path, data, unauthorisedHandler, permissionDeniedHandler
        post: (path, data) ->
            uplinkPromise "POST", path, data, unauthorisedHandler, permissionDeniedHandler
        abortPendingRequests: ->
            R.forEach ((xhr) -> xhr.abort()), uplink.xhrPool
            uplink.xhrPool = []



