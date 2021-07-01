reduxBatched = require "redux-batched-actions"

Reducers =
    global: require "../reducers/reduce_global"
    mapPage: require "../reducers/reduce_map_page"
    pavingPage: require "../reducers/reduce_paving_page"
    timelinePage: require "../reducers/reduce_timeline_page"
    usersPage: require "../reducers/reduce_users_page"

emptyState =
    assets: []
    customerLogo: ""
    email: ""
    isLoggedIn: false
    lastSelectedReport: {}
    mapType: "satellite"
    pavingUsers: []
    permissions: {}
    positions: []
    project: {}
    sessionId: ""
    users: []
    vehicles: []
    watchers: {}
    weather: {}
    debug:
        requests: false
        paving: false

    mapPage:
        filters:
            users: []
            selectedMarker: {}
        ui:
            trackUsers: false
            showMarkerPopup: true

    pavingPage:
        data:
            batchPlantInfo: []
            truckInfo: {}
            production: {}
            paverInfo: []
        ui:
            showControlPanel: true
            trackUsers: false
            customSorting: false
            showMarkerPopup: true
        filters:
            users: []
            selectedMarker: {}

    timelinePage:
        data:
            positions: []
            users: []
        filters:
            date: moment()
            users: []
        timeline:
            time: 0
            start: 0
            finish: 0
            timeZone: "UTC"
            userCounts: []
        ui:
            selectedTime: null
            isPlaying: false
            playbackSpeed: 1
            dateControlReady: false
            dataRequestIsInProgress: false

    usersPage:
        hqUsers: []
        userAppConfigs: []

PERSISTENT_ITEMS = ["customerLogo", "email", "isLoggedIn", "lastStateReport", "mapType", "permissions", "project", "sessionId"]


initialise = ->
    # Make sure the key is always present
    if !localStorage.get("savedState")?
        localStorage.set "savedState", {}

    savedState = localStorage.get("savedState")
    INITIAL_STATE = R.merge emptyState, savedState
    # Adding default timezone to avoid errors for existing users. To be removed later.
    if !R.isEmpty(INITIAL_STATE.project) && !INITIAL_STATE.project.timezone?
        INITIAL_STATE.project.timezone = "Australia/NSW"

    postReduce = (state, action) ->
        newState = if action.type == "SET_PROJECT"
            # Reset page state to saved state (clear out whatever state accumulated for the previous project)
            savedState = R.merge emptyState, localStorage.get("savedState")
            R.merge state, R.pick(["weather", "users", "positions", "mapPage", "pavingPage", "timelinePage", "usersPage"], savedState)
        else
            state
        R.merge newState, timelinePage: Reducers.timelinePage.postReduce state.timelinePage, action

    reduce = (state, action) ->
        Tracer.log "Reducing global state: #{action.type}", R.omit(["type"], action)

        reducedState = R.merge (Reducers.global state, action),
                mapPage:
                    filters: Reducers.mapPage.reduceFilters state.mapPage.filters, action
                    ui: Reducers.mapPage.reduceUi state.mapPage.ui, action
                pavingPage:
                    data: Reducers.pavingPage.reduceData state.pavingPage.data, action
                    filters: Reducers.pavingPage.reduceFilters state.pavingPage.filters, action
                    ui: Reducers.pavingPage.reduceUi state.pavingPage.ui, action
                timelinePage:
                    data: Reducers.timelinePage.reduceData state.timelinePage.data, action
                    filters: Reducers.timelinePage.reduceFilters state.timelinePage.filters, action
                    timeline: Reducers.timelinePage.reduceTimeline state.timelinePage.timeline, action
                    ui: Reducers.timelinePage.reduceUi state.timelinePage.ui, action
                usersPage:
                    Reducers.usersPage state.usersPage, action

        postReduce reducedState, action

    store = createStore reduxBatched.enableBatching(reduce), INITIAL_STATE

    store.subscribe =>
        prevState = localStorage.get "savedState"
        curState = store.getState()

        if R.any ((key) -> curState[key] != prevState[key]), PERSISTENT_ITEMS
            localStorage.set "savedState", R.pick(PERSISTENT_ITEMS, curState)
    store


observeStore = (select, onChange) ->
    currentState = undefined
    handleChange = ->
        nextState = select()
        if R.identical(nextState, currentState) || R.equals(nextState, currentState)
            # No change observed, do nothing
        else
            currentState = nextState
            onChange(nextState)

    unsubscribe = store.subscribe handleChange

    handleChange()
    unsubscribe


module.exports =
    initialise: initialise
    observeStore: observeStore
