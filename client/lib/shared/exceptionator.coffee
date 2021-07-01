# Exceptionator hooks all global event listeners and timeout functions to add try/catch exception handling

ignoreOnErrorCallbacks = 0

exceptionator = {}

# Default exception handler
exceptionator.exceptionHandler = (e, stack, event) ->
    console.log e, stack
    alert e.message


exceptionator.initialise = (exceptionHandler) ->
    exceptionator.exceptionHandler = exceptionHandler || exceptionator.exceptionHandler

    # EventTarget is all that's required in modern chrome/opera
    # EventTarget + Window + ModalWindow is all that's required in modern FF (there are a few Moz prefixed ones that
    # we're ignoring). The rest is a collection of stuff for Safari and IE 11. (Again ignoring a few MS and WebKit
    # prefixed things)
    eventListeners   = "EventTarget Window Node ApplicationCache AudioTrackList ChannelMergerNode CryptoOperation EventSource FileReader HTMLUnknownElement IDBDatabase IDBRequest IDBTransaction KeyOperation MediaController MessagePort ModalWindow Notification SVGElementInstance Screen TextTrack TextTrackCue TextTrackList WebSocket WebSocketWorker Worker XMLHttpRequest XMLHttpRequestEventTarget XMLHttpRequestUpload"
    timeoutFunctions = "setTimeout setInterval requestAnimationFrame"

    Tracer.log "Exceptionator: Hooking timeout functions: [#{timeoutFunctions}]"
    R.map replaceFunctions, timeoutFunctions.split " "

    Tracer.log "Exceptionator: Hooking event functions: [#{eventListeners}]"
    R.map replaceEventListeners, eventListeners.split " "

    Tracer.log "Exceptionator: Hooking [window.onerror]"
    oldOnError = window.onerror
    window.onerror = (message, url, lineNo, charNo, exception) ->
        if ignoreOnErrorCallbacks <= 0
            exception ?= {}
            exception.source = "window.onerror"
            exception.message = "#{message} @ #{url}:#{lineNo}:#{charNo}"
            exceptionator.exceptionHandler exception, generateStacktrace()

            # Call the original onerror handler if there was one
            if oldOnError
                oldOnError message, url, lineNo, charNo, exception

    Tracer.log "Exceptionator: Hooking [Promise]"
    window.addEventListener "unhandledrejection", (e) =>
        return if e.detail.reason.suppressUnhandledRejection
        e.preventDefault()
        e.detail.reason.source = "Promise"
        exceptionator.exceptionHandler e.detail.reason, e.detail.promise._trace.stack.split("\n").slice(4).join("\n")


wrap = (original, stack, options = {}) ->


exceptionator.wrapEventHandler = (original, stack) ->
    return original if typeof original != "function"

    if !original._wrapped
        original._wrapped = (event) ->
            try
                return original.apply @, arguments
            catch e
                ignoreNextOnError()
                # Use a stack trace passed in rather than one from the exception
                e.source = "event handler"
                exceptionator.exceptionHandler e, stack, event

    original._wrapped


exceptionator.wrap = (original) ->
    return original if typeof original != "function"
    stack = generateStacktrace()
    ->
        try
            original.apply @, arguments
        catch e
            ignoreNextOnError()
            # Use a stack trace passed in rather than one from the exception
            e.source = "manually wrapped callback"
            exceptionator.exceptionHandler e, stack, arguments


hookTimeFunc = (original) ->
# Return a function that will call the original setTimeout function but instead of passing specified function
# as the first parameter we create a new function which wraps the request function within a try catch block

    (func, timeout) ->
        stack = generateStacktrace()
        original ->
            try
                func.apply(this, arguments)
            catch e
                ignoreNextOnError()
                e.source = "time function"
                exceptionator.exceptionHandler e, stack
        , timeout


replace = (object, name, makeReplacement) ->
# We only want to be replacing functions with wrapped versions,
# ignore any non functions that accidentally get passed in
    return if typeof object[name] != "function"
    object[name] = makeReplacement object[name]


replaceFunctions = (functionName) ->
    replace window, functionName, hookTimeFunc


replaceEventListeners = (listenerName) ->
    prototype = window[listenerName]?.prototype
    if prototype?.hasOwnProperty?("addEventListener")
        replace prototype, "addEventListener",    hookEventFunc
        replace prototype, "removeEventListener", hookEventFunc


hookEventFunc = (original) ->
    (eventName, listener, useCapture, wantsUntrusted) ->
        stack = generateStacktrace()

        if listener?.handleEvent?
            listener.handleEvent = exceptionator.wrapEventHandler(listener.handleEvent, stack)

        original.call this, eventName, exceptionator.wrapEventHandler(listener, stack), useCapture, wantsUntrusted


generateStacktrace = ->
    stacktrace = undefined
    # Try to generate a real stacktrace (most browsers, except IE9 and below).
    try
        throw new Error("")
    catch exception
        stacktrace = exception.stack || exception.backtrace || exception.stacktrace
    stacktrace.split("\n").slice(2).join("\n")


ignoreNextOnError = ->
    ignoreOnErrorCallbacks += 1
    window.setTimeout (-> ignoreOnErrorCallbacks -= 1), 0


module.exports = exceptionator
