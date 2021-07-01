every = require "flyd/module/every"
reduxBatched = require "redux-batched-actions"
reduxReselect = require "reselect"

batch = reduxBatched.batchActions
createSelector = reduxReselect.createSelector


class TimelineControl
    constructor: (params) ->
        {@$el, @map} = params
        @prevState = store.getState().timelinePage

        @$(".timeline").css "background-image": "none"
        @$(".playBtn").text "Play"
        @$("select.speedSelector").val("1").selectmenu("refresh", true)

        @$(".timeline, .timelineLabels").on "mousemove", (e) =>
            store.dispatch Action.timelinePage.ui.selectTime e.offsetX / e.target.offsetWidth

        @$(".timeline, .timelineLabels").on "click", (e) =>
            store.dispatch Action.timelinePage.timeline.movePlayhead store.getState().timelinePage.ui.selectedTime

        @$(".timeline").on "mouseout", (e) =>
            store.dispatch Action.timelinePage.ui.unselectTime()

        @$(".playBtn").on "click", (e) =>
            @map.closePopup()
            store.dispatch Action.timelinePage.ui.playToggle()

        @$("select.speedSelector").on "change", (e) =>
            store.dispatch Action.timelinePage.ui.setPlaybackSpeed parseInt @$("select.speedSelector option:selected").val()

        Uplink.get("projects/#{store.getState().project.id}/timeline", date: store.getState().timelinePage.filters.date.format "YYYY-MM-DD")
        .then (result) =>
            Tracer.log "Timeline info: ", result
            store.dispatch Action.timelinePage.timeline.setTimelineParams result


    teardown: =>
        R.map ((selector) => @$(selector).off()), [".timeline", ".timelineLabels", ".playBtn", ".speedSelect"]

        @$(".hoverMarker").hide()
        @$(".timeMarker").hide()

    $: (selector) =>
        @$el.find selector


    updateTimeSelector: (state) =>
        if state.ui.selectedTime?
            @$(".hoverMarker").show().css(left: "#{state.ui.selectedTime * 100}%")
        else
            @$(".hoverMarker").hide()


    updatePlayButton: (state) =>
        return if state.ui.isPlaying == @prevState.ui.isPlaying
        @$(".playBtn").text if state.ui.isPlaying then "Pause" else "Play"


    updatePlayhead: (state) =>
        return if state.timeline == @prevState.timeline
        if state.timeline.start == 0
            @$(".timeMarker").hide()
        else
            @$(".timeMarker").show()
            .css left: "#{(state.timeline.time - state.timeline.start) / (state.timeline.finish - state.timeline.start) * 100}%"


    updateTimeLabels: (state) =>
        return if state.timeline == @prevState.timeline && state.ui == @prevState.ui

        formatTime = (timestamp) =>
            return "" if timestamp == 0
            moment.tz(timestamp, state.timeline.timeZone).format "HH:mm"

        @$(".startTimeLabel").text formatTime(state.timeline.start)
        @$(".finishTimeLabel").text formatTime(state.timeline.finish)

        currTimeText = formatTime(state.timeline.time)
        currentTimeLabelText = if state.timeline.start > 0 && state.ui.selectedTime?
            selTime = Math.floor(state.timeline.start + (state.timeline.finish - state.timeline.start) * state.ui.selectedTime)
            if selTime <= state.timeline.time
                """<span class="selTime">#{formatTime(selTime)}</span> &#8668; #{currTimeText}"""
            else
                """#{currTimeText} &#8669; <span class="selTime">#{formatTime(selTime)}</span>"""
        else
            currTimeText

        @$(".currentTimeLabel").html currentTimeLabelText


    updateTimelineGradient: (state) =>
        return if state.timeline.userCounts == @prevState.timeline.userCounts

        if R.isEmpty state.timeline.userCounts
            @$(".timeline").css "background-image": "none"
            return

        maxCount = Math.max state.timeline.userCounts...

        percToColor = (perc) =>
            fromColor = [255, 255, 255]
            toColor = [187, 255, 175]
            R.map ((pair) => Math.round pair[0] * (1 - perc) + pair[1] * (perc)), R.zip(fromColor, toColor)

        gradient = R.map ((c) => "rgb(#{percToColor(c / maxCount).join ","})"), state.timeline.userCounts
        Tracer.log "Setting gradient to: ", gradient
        @$(".timeline").css "background-image": "-webkit-linear-gradient(left, #{gradient.join ","})"


    updateSpeedSelector: (state) =>
        @$("select.speedSelector").val("#{state.ui.playbackSpeed}").selectmenu("refresh", true)
        

    render: =>
        state = store.getState().timelinePage
        @updateTimeSelector state
        @updatePlayButton state
        @updatePlayhead state
        @updateTimeLabels state
        @updateTimelineGradient state
        @updateSpeedSelector state
        @prevState = state


class PeopleLayer
    constructor: (params) ->
        {@map} = params


    teardown: =>
        if @cluster?
            @clearCluster()
            @map.removeLayer @cluster


    createMarkers: (people) =>
        R.map @createMarkerWithPopup, people


    addMarkersToCluster: (markers) =>
        @cluster.addLayers markers


    clearCluster: =>
        R.forEach ((marker) => marker.clearAllEventListeners()), @cluster.getLayers()
        @cluster.clearLayers()


    createMarkerWithPopup: (person) =>
        buildPopupContent = (p) =>
            date = mapLayers.markerBuilders.getDate p

            timeString = """<span style = "font-size: 0.8em">Last updated: #{date}</span>"""


            role = if p.role? && p.role.length > 0 then " - #{p.role}" else ""

            company = if p.company? && p.company.length > 0 then "<em>#{p.company}</em><br/>" else ""

            phoneDetails = if p.phoneNo? && p.phoneNo.length > 0
                "#{p.phoneNo}"
            else
                "unknown"

            "<b>#{p.name}</b>#{role}<br/>#{company}#{timeString}<br/>Phone: #{phoneDetails}"

        marker = mapLayers.markerBuilders.user.create person
        marker.on "click", (e) =>
            if !store.getState().timelinePage.ui.isPlaying
                @map.openPopup buildPopupContent(person), e.latlng, {autoPan: false, keepInView: false}
        marker


    render: (force) =>
        if @cluster?
            @clearCluster()
            @map.removeLayer @cluster

        @cluster = new L.MarkerClusterGroup
            showCoverageOnHover: false
            disableClusteringAtZoom: 17
            maxClusterRadius: 50
            polygonOptions:
                fillColor: "#3887be"
                color: "#3887be"
                weight: 2
                opacity: 1
                fillOpacity: 0.5

        @map.addLayer @cluster


    redraw: (positions) =>
        # The code to re-spiderfy on redraw is hacky but the cluster doesn't expose the methods to do it otherwise

        spiderfiedBounds = R.clone @cluster._spiderfied?.getBounds()

        @clearCluster()

        @addMarkersToCluster @createMarkers positions
        if spiderfiedBounds?
            marker = R.find ((layer) => spiderfiedBounds.contains(layer.getLatLng())), @cluster.getLayers()
            if marker?
                marker.__parent.spiderfy()



class TimelinePage extends pages.BasePage
    @pageId "timelinePage"

    HEADER_BUTTON: {label: "Filters", icon: "calendar", target: "#timelineUsersList"}

    constructor: ->
        super

        Tracer.log "in timelinePage constructor"
        @setupState()


    teardown: =>
        @stopObservingTimelinePage()
        @timelineControl?.teardown()
        @peopleLayer?.teardown()
        @$el.off()
        @usersSidebar.hide()
        @$("#timelineUsersList .userList").html ""

        $.mobile.loading "hide"
        clearInterval @tickerId


    setupState: =>
        @prevState = store.getState().timelinePage


        timeSelector = (state) => state.timeline.time
        positionSelector = (state) => state.data.positions

        # (A -> B -> Output -> Output) -> (A -> B -> Output)
        withFeedback = (func) =>
            lastOutput = undefined
            (a, b) => lastOutput = func a, b, lastOutput

        # Returns an object mapping user IDs to position indexes at a given time
        # Note: by using withFeedback, I'm feeding the previous mapping into the function which computes the current mapping
        @positionSliceSelector = createSelector timeSelector, positionSelector, withFeedback (time, usersWithPositions, prevIndexes) =>
            result = R.reduce (res, user) =>
                res[user.userId] = R.findLastIndex ((posArr) => posArr[0] < time), user.positions
                res
#                prevIndex = if prevIndexes? then prevIndexes[user.userId] else -1
#                prevPos = user.positions[prevIndex]
#                res[user.userId] = if prevIndex >= 0 && prevPos? && (prevIndex == user.positions.length || prevPos[1] > time)
#                    # Already reached the last position, OR haven't reached the next position => no change of index
#                    prevIndex
#                else
#                    # Find the next index (could be jumping over several positions)
#                    #followingPositions = R.takeLast(user.positions.length - prevIndex - 1, user.positions)
#                    R.findLastIndex ((posArr) => posArr[0] < time), user.positions
#                res
            , {}, usersWithPositions

            result


    applyFilters: (state, prevState) =>
        Tracer.log "Applying filters"

        if state.filters.date - prevState.filters.date == 0  # If the date is still the same, then we only need to reconcile
                                                             # position data with the user filters
            # Remove data not matching the filters
            trimmedPositions = R.reject R.compose(R.not, R.contains(R.__, state.filters.users), R.prop("userId")), state.data.positions

            userIdsToRetrieve = R.difference state.filters.users, R.pluck("userId", trimmedPositions)
            Tracer.log "User ids to retrieve:", userIdsToRetrieve
            

            Promise.resolve().then => # Force async execution to prevent .dispatch() in .subscribe callback
                if userIdsToRetrieve.length > 0
                    store.dispatch Action.timelinePage.ui.startDataRequest()

                    Tracer.log "Requesting position data"
                    # Add data not currently present
                    Promise.all R.map ((userId) =>
                        Uplink.get "projects/#{store.getState().project.id}/timeline/positions"
                        , {userId: userId, date: state.filters.date.format "YYYY-MM-DD"})
                    , userIdsToRetrieve
                    .then (result) =>
                        Tracer.log "Received position data", result
                        store.dispatch batch [
                            Action.timelinePage.data.setPositions(R.concat result, trimmedPositions),
                            Action.timelinePage.ui.finishDataRequest()
                        ]
                    .catch =>
                        store.dispatch Action.timelinePage.ui.finishDataRequest()
                else
                    store.dispatch Action.timelinePage.data.setPositions trimmedPositions

        else
            # If the date has changed, then we need to get the list of users active on that date, reconcile
            # the selected users with active users (so as to preserve as many selections as possible),
            # and retrieve position data for all selected users

            # This is a two step process: here, we get the list of active users, get rid of outdated position data
            # and reconcile filters; this step will trigger another call to apply filters which will see no date change
            # and execute the above branch instead to retrieve the necessary positions

            Uplink.get("projects/#{store.getState().project.id}/users", date: state.filters.date.format "YYYY-MM-DD")
            .then (users) =>
                Tracer.log "Retrieved users at applyFilters"
                store.dispatch batch [
                    Action.timelinePage.data.setUsers(users),
                    Action.timelinePage.data.setPositions([]),
                    Action.timelinePage.filter.reconcileUsers(users)
                ]

                Uplink.get("projects/#{store.getState().project.id}/timeline", date: state.filters.date.format "YYYY-MM-DD")
            .then (result) =>
                Tracer.log "Timeline info: ", result
                store.dispatch Action.timelinePage.timeline.setTimelineParams result
                store.dispatch Action.timelinePage.timeline.setTimelineParams result


    render: (state, options = {}) =>
        Tracer.log "Rendering timelinePage", options

        R.forEach ((fn) => @[fn](state, options.force))
        , ["renderTicker", "renderTimelineControl", "renderCluster", "renderFilterButton",
                "renderFilterUserList" , "renderLoadingMessage"]


    renderTimelineControl: (state, force) =>
        @timelineControl.render(force)


    renderTicker: (state, force) =>
        return if !force && state.ui.isPlaying == @prevState.ui.isPlaying && state.ui.playbackSpeed == @prevState.ui.playbackSpeed

        if state.ui.isPlaying
            if @tickerId? # Already playing => it must be a speed change
                clearInterval @tickerId
                @tickerId = null

            advancePlayhead = => store.dispatch Action.timelinePage.timeline.advancePlayhead(60 * 1000)
            @tickerId = setInterval advancePlayhead, Math.floor(1000 / state.ui.playbackSpeed)
            Promise.resolve().then => advancePlayhead()
        else
            clearInterval @tickerId
            @tickerId = null


    renderFilterButton: (state, force) =>
        @$(".ui-header a:first-child").text state.filters.date.format "DD/MM/YY"


    renderLoadingMessage: (state, force) =>
        $.mobile.loading (if state.ui.dataRequestIsInProgress then "show" else "hide"), textVisible: false


    renderFilterUserList: (state, force) =>
        Tracer.log "in renderFilterUserList: ", force
        return if !force && state.data.users == @prevState.data.users

        Tracer.log "Rendering filter user list"

        htmlContent = if state.data.users.length > 0
            userItem = (user) =>
                selectedClass = if R.contains user.id, state.filters.users then "selected" else ""
                """
                <li class="filterUserItem #{selectedClass}"
                    data-user-id="#{user.id}"
                    data-user-role="#{user.role}">#{user.name}</li>
                """

            """
            <div  data-role="controlgroup" data-type="horizontal" data-mini="true" style="width: 100%;">
                <a href="#" class="selectAllUsers ui-btn ui-mini ui-shadow">Select all users</a>
                <a href="#" class="selectNoUsers ui-btn ui-mini ui-shadow">Clear all users</a>
            </div>

            <form class="ui-filterable">
                <input class="filterUserListFilterTimeline" placeholder="Find users by name..."  data-type="search">
            </form>

            <ul class="filterUserList" data-role="listview" data-autodividers="true"
                 data-filter="true" data-input=".filterUserListFilterTimeline">
                 #{R.map(userItem, state.data.users).join "\n"}
            </ul>
            """
        else
            """<div style="margin: 30px">No active users on this date</div>"""

        @$("#timelineUsersList .userList").html(htmlContent).enhanceWithin()


        @$(".filterUserList").listview
            autodividers: true
            autodividersSelector: (li) => Tracer.log("role attr:", li.attr("data-user-role")); li.attr("data-user-role")
        .listview "refresh"

        @$(".userList .ui-input-search,  .ui-controlgroup").removeClass("ui-corner-all")


    renderCluster: (state, force) =>
        return if !force && state.timeline.time == @prevState.timeline.time &&
            state.data.positions == @prevState.data.positions

        positionIndexes = @positionSliceSelector state
        #Tracer.log "Position slice: ", positionIndexes

        positionArrayToObj = (attrArray) =>
            timestamp: attrArray[0]
            lon: attrArray[2]
            lat: attrArray[3]
            speed: attrArray[4]
            heading: attrArray[5]


        relevantUsersWithPositions = R.filter ((user) => positionIndexes[user.userId] >= 0), state.data.positions
        positions = R.map (userWithPositions) =>
            R.merge userWithPositions
            , positionArrayToObj userWithPositions.positions[positionIndexes[userWithPositions.userId]]
        , relevantUsersWithPositions

        # remove stale positions
        positions = R.reject ((pos) => state.timeline.time - pos.timestamp > 60 * 60 * 1000), positions

        calcOpacity = (pos) =>
            if state.timeline.time - pos.timestamp < 4 * 60 * 1000
                1.0
            else
                Math.max(0.5, 1 - (state.timeline.time - pos.timestamp - 4 * 60 * 1000) / (10 * 60 * 1000))

        positions = R.map ((pos) => R.merge pos, opacity: calcOpacity(pos)), positions
        #Tracer.log "Redrawing people icons", positions
        @peopleLayer.redraw positions


    onPageBeforeShow: =>
        super

        # This is how to handle the panel closing:
        #@$el.on "panelclose", "#filterPanel", (e) =>

        @$el.on "change", "#timelineDate", (e) =>
            date = moment $(e.target).datebox("getTheDate")

            Tracer.log "Setting the date to ", date, "prev date:", @prevState.filters.date
            store.dispatch batch [Action.timelinePage.filter.setDate(date), Action.timelinePage.ui.pause()]

        # Note: Ideally, filter state would be updated after a store notification based on the state of the filter;
        # however, I don't have a nice mechanism for that, so instead, the handlers below update UI directly
        @$("#timelineUsersList").on "click", ".filterUserItem", (e) =>
            action = if $(e.target).hasClass("selected") then "removeUser" else "addUser"
            store.dispatch Action.timelinePage.filter[action] parseInt $(e.target).attr("data-user-id")
            $(e.target).toggleClass "selected"

        @$("#timelineUsersList").on "click", ".selectAllUsers", (e) =>
            store.dispatch Action.timelinePage.filter.selectAllUsers()
            @$(".filterUserItem").addClass "selected"

        @$("#timelineUsersList").on "click", ".selectNoUsers", (e) =>
            store.dispatch Action.timelinePage.filter.resetUsers()
            @$(".filterUserItem").removeClass "selected"

        @setupMap()

        @usersSidebar = L.control.sidebar 'timelineUsersList',
            position: 'left'
            closeButton: false
        @map.addControl @usersSidebar

        $(".ui-btn[href=#timelineUsersList]").on 'click', => @usersSidebar.toggle()

        @$(".controlPanel, .leaflet-map-pane").on "click", => @usersSidebar.hide()

        Uplink.get "projects/#{store.getState().project.id}/geometries/base-layers"
        .then (baseLayers) =>
            @baseLayersLayer = new mapLayers.BaseLayer
                map: @map
                collection: baseLayers

        Uplink.get "projects/#{store.getState().project.id}/geometries/overlays"
        .then (overlays) =>
            @overlaysLayer = new mapLayers.OverlaysLayer
                map: @map
                collection: overlays
                allowEditing: false

        @timelineControl = new TimelineControl $el: @$el, map: @map

        @peopleLayer = new PeopleLayer map: @map
        @peopleLayer.render()

        @setupFilterControls() # this will trigger a call to @render()


        @stopObservingTimelinePage = observeStore (-> store.getState().timelinePage), @onChange

        @render store.getState().timelinePage, force: true


    onChange: (state) =>
        if state.filters != @prevState.filters
            @applyFilters state, @prevState
        @render state
        @prevState = state


    onPageHide: =>
        Tracer.log "Stopping map updates"
        @teardown()
        @baseLayersLayer.destroy()
        @overlaysLayer.destroy()


    onPageShow: =>
        @map.invalidateSize()
        @map.fitBounds L.latLngBounds store.getState().project.bboxPoints.coordinates


    setupFilterControls: =>
        Uplink.get("projects/#{store.getState().project.id}/users", date: store.getState().timelinePage.filters.date.format "YYYY-MM-DD")
        .then (users) =>
            Tracer.log "Retrieved users at setupFilterControls"
            store.dispatch batch [ Action.timelinePage.data.setUsers(users), Action.timelinePage.filter.resetUsers() ]

        return if store.getState().timelinePage.ui.dateControlReady

        $("""<div class="dateControl"></div>""").appendTo @$("#timelineUsersList")
        .html """
            <input id="timelineDate" type="text" class="date" data-role = "datebox"
                data-options = '{"mode":"calbox", "showInitialValue": true, "useNewStyle":true,
                "useInline": true, "hideInput": true, "calHighToday": false,
                "beforeToday": false, "useHeader": false, "overrideCalStartDay": 1}' />
        """
        .enhanceWithin()

        @$(".ui-datebox-container").removeClass("ui-overlay-shadow")

        store.dispatch Action.timelinePage.ui.dateControlReady()

        $("""<div class="userList">Retrieving users...</div>""").appendTo @$("#timelineUsersList")


    setupMap: =>
        if @map?
            Tracer.log "map already set up, doing nothing"
            return

        @map = L.mapbox.map "timelineMapContainer", null,
            minZoom: 8
            attributionControl: compact: true

        @map.addControl L.control.scale imperial: false, position: "bottomleft"


module.exports = TimelinePage
