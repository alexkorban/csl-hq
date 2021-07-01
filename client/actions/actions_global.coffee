module.exports =
    destroyWatchers: -> type: "destroyWatchers"
    login: -> type: "login"
    logout: -> type: "logout"
    setCustomerLogo: (customerLogo) -> type: "setCustomerLogo", customerLogo: customerLogo
    setEmail: (email) -> type: "setEmail", email: email
    setLastSelectedReport: (lastSelectedReport) -> type: "setLastSelectedReport", lastSelectedReport: lastSelectedReport
    setMapType: (mapType) -> type: "setMapType", mapType: mapType
    setPermissions: (permissions) -> type: "setPermissions", permissions: permissions
    setProject: (project) -> type: "setProject", project: project
    setSessionId: (sessionId) -> type: "setSessionId", sessionId: sessionId
    updateAssets: (assets) -> type: "updateAssets", assets: assets
    updateDebugParams: (params) -> type: "updateDebugParams", params: params
    updatePositions: (positions) -> type: "updatePositions", positions: positions
    updatePavingUsers: (pavingUsers) -> type: "updatePavingUsers", pavingUsers: pavingUsers
    updateUsers: (users) -> type: "updateUsers", users: users
    updateVehicles: (vehicles) -> type: "updateVehicles", vehicles: vehicles
    updateWatchers: (watcher) -> type: "updateWatchers", watcher: watcher
    updateWeather: (weather) -> type: "updateWeather", weather: weather
