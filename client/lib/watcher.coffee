create = (watcher) ->
    Tracer.log "Creating #{watcher.name} watcher"

    updateWatcher = () ->
        update watcher
    intervalId = setInterval updateWatcher, watcher.period
    updateWatcher()
    intervalId


update = (watcher) ->
    Tracer.log "Updating data for #{watcher.name} watcher"

    projectId = store.getState().project.id
    return if !projectId?

    url = R.replace "$projectId", projectId, watcher.url

    Uplink.get url, watcher.params
    .then (result) =>
        Tracer.log "#{watcher.name} watcher update got #{result.length} items"
        store.dispatch watcher.action(result)

module.exports =
    create: create
    update: update
