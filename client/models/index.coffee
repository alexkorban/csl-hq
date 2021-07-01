unauthorisedHandler = =>
    Uplink.abortPendingRequests()
    app.logout()
    
permissionDeniedHandler = =>
    Uplink.abortPendingRequests()
    store.dispatch Action.global.setProject {}
    location.reload()


window.Uplink = require("./uplink") unauthorisedHandler, permissionDeniedHandler

window.TIME_FORMAT = "DD/MM/YY HH:mm:ss"
window.POLYGON_PURPOSES = [
    ["none", "None"]
    ["borrowPit", "Borrow pit"]
    ["breakArea", "Break area"]
    ["cut", "Cut"]
    ["environmental", "Environmental"]
    ["fill", "Fill"]
    ["hazard", "Hazard"]
    ["heritage", "Heritage"]
    ["stockpile", "Stockpile"]
    ["waste", "Waste"]
]
