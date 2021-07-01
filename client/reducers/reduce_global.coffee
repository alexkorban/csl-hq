module.exports = (state, action) ->
    switch action.type
        when "destroyWatchers" then R.merge state, watchers: {}
        when "login" then R.merge state, isLoggedIn: true
        when "logout" then R.merge state, isLoggedIn: false
        when "setCustomerLogo" then R.merge state, customerLogo: action.customerLogo
        when "setEmail" then R.merge state, email: action.email
        when "setLastSelectedReport" then R.merge state, lastSelectedReport: R.clone action.lastSelectedReport
        when "setMapType" then R.merge state, mapType: action.mapType
        when "setProject" then R.merge state, project: R.clone action.project
        when "setPermissions" then R.merge state, permissions: R.clone action.permissions
        when "setSessionId" then R.merge state, sessionId: action.sessionId
        when "updateAssets" then R.merge state, assets: R.clone action.assets
        when "updateDebugParams" then R.merge state, {debug: R.merge state.debug, action.params}
        when "updatePavingUsers" then R.merge state, pavingUsers: R.clone action.pavingUsers
        when "updatePositions" then R.merge state, positions: R.clone action.positions
        when "updateUsers" then R.merge state, users: R.clone action.users
        when "updateVehicles" then R.merge state, vehicles: R.clone action.vehicles
        when "updateWatchers" then R.merge state, {watchers: R.merge state.watchers, action.watcher}
        when "updateWeather" then R.merge state, weather: R.clone action.weather
        else state
