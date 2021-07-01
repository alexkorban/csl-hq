window.printStackTrace = require("./stacktrace").printStackTrace
window.Tracer = require "./tracer"

require "./utils"

require "./L.Control.Sidebar"
require "./leaflet_button"

window.exceptionator = require "./shared/exceptionator"
window.actionTypesChecker = require "./shared/action_types_checker"

Store = require "./store"
window.store = Store.initialise()
window.observeStore = Store.observeStore

window.controls = R.merge(
    require("./controls"),
    require("./controls/user_list")
)

window.watchers = require "./watcher"
window.mapLists = require "./map_lists"
window.mapLayers = require "./map_layers"
window.weatherReport = require "./weather_report"


