reduxBatched = require "redux-batched-actions"
batch = reduxBatched.batchActions


class PavingPage extends pages.BasePage
    @pageId "pavingPage"
    HEADER_BUTTON: {label: "Users", icon: "user", target: "#pavingUserList" }

    constructor: ->
        super

        Tracer.log "in pavingPage constructor"
        @setupState()

        Tracer.log "Radios:", (@$ "input[type=radio]")
        # vclick doesn't work for radio buttons
        (@$ "input[type=radio]").on "click", (e) =>
            e.stopPropagation()
            e.preventDefault()
            Tracer.log "Filter:", $(e.currentTarget).val()
            store.dispatch Action.pavingPage.ui.selectUsers($(e.currentTarget).val())


    setupState: =>
        @prevState = @getPavingState()
        @batchPlantCharts = []


    render: (state, options = {}) =>
        Tracer.log "Rendering"
        R.forEach ((fn) => @[fn](state, options.force))
        , ["renderControlPanel", "renderTruckPanel", "renderBatchPlantPanels", "renderBatchPlantCharts",
           "renderPaverPanels" , "renderPositions"]


    renderControlPanel: (state, force) =>
        Tracer.log "Rendering control panel with ", state
        return if !force && state.ui.showControlPanel == @prevState.ui.showControlPanel

        if state.ui.showControlPanel
            @sidebar.show()
            @map.removeControl(@sidebarButton) if @sidebarButton._map?
        else
            @sidebar.hide()
            @map.addControl(@sidebarButton) if !@sidebarButton._map?


    renderTruckPanel: (state, force) =>
        return if !force && state.data.truckInfo == @prevState.data.truckInfo

        @$(".truckInfo").html if !R.isEmpty(state.data.truckInfo) && state.data.truckInfo.loaded6wheelers?
            """
            <h2>Loaded trucks</h2>
            <table>
                <tr><td>6 wheelers</td><td>#{state.data.truckInfo.loaded6wheelers}</td></tr>
                <tr><td>8 wheelers</td><td>#{state.data.truckInfo.loaded8wheelers}</td></tr>
            </table>
            <h2>Empty trucks</h2>
            <table>
                <tr><td>6 wheelers</td><td>#{state.data.truckInfo.empty6wheelers}</td></tr>
                <tr><td>8 wheelers</td><td>#{state.data.truckInfo.empty8wheelers}</td></tr>
            </table>
            """
        else
            "<h2>No truck data</h2>"


    renderPaverPanels: (state, force) =>
        return if !force && state.data == @prevState.data
        Tracer.log "Rendering paver panels"

        # We are only interested in the positions of pavers so filter the global positions for what we want
        paverPositions = R.filter(R.propEq("role", "Paver"), store.getState().positions)

        # Paver positions do not yet have the paver_id so we fake it for now!
        # We Fake it by using the paverId from our paver info
        # Once the positions have a paverId filled in we can remove this block
        thePaverId = "Paver"
        firstPaver = R.head state.data.paverInfo
        if firstPaver? && firstPaver.paverId? then thePaverId = firstPaver.paverId
        paverPositions = R.map R.merge(paverId: thePaverId), paverPositions

        # The following reorders the pavers (and paver positions) into a structure where the
        # key is the paver id so that we can easily group the two data sets together.
        #
        # e.g. { "paver1": {paverId:"paver1", field:value, field2:value, ... },
        #        "paver2": {paverId:"paver2", field:value, field2:value, ... } }
        #
        # We assume each paver has a unique id and therefore can just take the head from the groupBy
        #
        groupById = (list) => R.map R.head, (R.groupBy(R.prop("paverId")) list)

        # Apply the function above to both paver data and paver position data in preparation
        # for merging the two sets together
        [positionsGrouped, paversGrouped] = R.map groupById, [paverPositions, state.data.paverInfo]

        # Combine both sets of paver info into a single set indexed by id we use both mergeWith
        # and merge here because we want to combine the properties when the ids match
        #
        paversCombined = R.values R.mergeWith ((a, b) => R.merge a, b), paversGrouped, positionsGrouped

        @$(".paverInfo").html if not R.isEmpty paversCombined
            R.map((paver) ->

                intervalFormatter = (time) =>
                    if time? then (((time.split ":")[...2]).join(':')) else "00:00"

                timeFormatter = (timeString) =>
                    if timeString? then  timeString.split(" ")[1].slice(0, -3) else "&mdash;"

                """
                <div class="paverPanel">
                    <h2>#{paver.paverId}</h2>
                    <table>
                        <tr><td>Load count</td><td>#{paver.loads ? 0}</td></tr>
                        <tr><td>Average haul time</td><td>#{intervalFormatter paver.travelTime}</td></tr>
                        <tr><td>Start chainage</td><td>#{if paver.startChainage? then paver.startChainage.toFixed(0) else "&mdash;"}</td></tr>
                        <tr><td>Current chainage</td><td>#{if paver.currentChainage? then paver.currentChainage.toFixed(0) else "&mdash;"}</td></tr>
                        <tr><td>Distance, m</td><td>#{if paver.totalDistance? then paver.totalDistance.toFixed(0) else "&mdash;"}</td></tr>
                        <tr><td>Speed, m/min</td><td>#{if paver.avgSpeed? then paver.avgSpeed.toFixed(2) else "0.0"}</td></tr>
                        <tr><td>Last reported</td><td>#{timeFormatter paver.lastPositionAt}</td></tr>
                    </table>
                </div>
                """
            , R.values paversCombined).join "\n<hr/>\n"
        else
            "<h2>No paver data</h2>"


    renderBatchPlantPanels: (state, force) =>
        return if !force && state.data.batchPlantInfo == @prevState.data.batchPlantInfo
        Tracer.log "Rendering batch plant panels"

        @$(".batchPlantInfo").html if state.data.batchPlantInfo.length > 0
            R.map((batchPlant) =>
                width = @$(".batchPlantInfo").width()
                startTime = if R.is(String, batchPlant.startTime)
                    batchPlant.startTime
                else
                    moment.tz(batchPlant.startTime * 1000, store.getState().project.timezone).format("HH:mm")

                """
                <div class="batchPlantPanel">
                    <h2>#{batchPlant.name}</h2>
                    <table>
                        <tr><td>Avg m<sup>3</sup> per hour</td>
                            <td>#{batchPlant.volumePerHour ? "N/A"}</td></tr>
                        <tr><td>m<sup>3</sup> in transit</td><td>#{batchPlant.volumeInTransit ? "N/A"}</td></tr>
                        <tr><td>m<sup>3</sup> produced</td><td>#{batchPlant.volumeProduced ? "N/A"}</td></tr>
                        <tr><td>Load count</td><td>#{batchPlant.loadCount}</td></tr>
                        <tr><td>Start time</td><td>#{startTime}</td></tr>
                        <tr><td>Production per hour, m<sup>3</sup>:</td><td> </td></tr>
                    </table>
                    <canvas width="#{width}" height="100"></canvas>
                </div>
                """
            , state.data.batchPlantInfo).join "\n<hr/>\n"
        else
            "<h2>No batch plant data</h2>"


    renderBatchPlantCharts: (state, force) =>
        return if !force && state.data.production == @prevState.data.production
        Tracer.log "Rendering batch plant charts"

        R.forEach ((chart) => chart.destroy()), @batchPlantCharts

        @batchPlantCharts = R.map (batchPlantWithIndex) =>
            batchPlantDiv = @$(".batchPlantPanel:nth-of-type(#{batchPlantWithIndex[1]})")
            ctx = batchPlantDiv.find("canvas")[0].getContext "2d"
            name = batchPlantDiv.find("h2").text()

            mergeColors = (dataset) =>
                R.merge dataset, {strokeColor: "#396b9e", pointColor: "#fff", pointStrokeColor: "#396b9e"
                , pointHighlightFill: "#396b9e", pointHighlightStroke: "#396b9e"}

            slumpChartData = R.merge state.data.production[name], datasets: R.map(mergeColors, state.data.production[name].datasets)

            Tracer.log "Slump chart data:", slumpChartData
            new Chart(ctx).Line slumpChartData,
                animation: false
                pointDotRadius: 3
                pointHitDetectionRadius: 5
                datasetFill: false
                scaleFontSize: 8
                tooltipFontSize: 12

        , R.zip(state.data.batchPlantInfo, R.range(1, state.data.batchPlantInfo.length + 1))


    getPavingUsers: =>
        store.getState().pavingUsers


    getFilteredPositions: =>
        state = store.getState()
        filter = state.pavingPage.filters.users
        filterResolved = if filter == "all" then R.pluck("id", state.users) else filter
        filteredUsers = R.intersection filterResolved, (R.map R.prop("id"), @getPavingUsers())

        R.filter ((pos) -> R.contains(pos.id, filteredUsers)), state.positions


    renderPositions: (state, force) =>
        return if !force &&
            state.data.positions == @prevState.data.positions &&
            state.filters.users == @prevState.filters.users &&
            state.filters.selectedMarker == @prevState.filters.selectedMarker &&
            state.ui.trackUsers == @prevState.ui.trackUsers &&
            state.ui.customSorting == @prevState.ui.customSorting

        @clusteredMarkerLayer ?= new mapLayers.ClusteredMarkerLayer
            map: @map
            page: "pavingPage"
            sources:
                user:
                    isTrackable: true
                    positionSelector: @getFilteredPositions
                    marker: mapLayers.markerBuilders.user
                vehicle:
                    isTrackable: false
                    positionSelector: -> store.getState().vehicles
                    marker: mapLayers.markerBuilders.vehicle

        @clusteredMarkerLayer.redraw()

        @userList.redraw state.filters.users


    getPavingState: =>
        data = R.merge store.getState().pavingPage.data, positions: store.getState().positions
        R.merge store.getState().pavingPage, data: data


    onChange: (state) =>
        @render state
        @prevState = state


    onPageBeforeShow: =>
        super

        @setupMap()

        @userSidebar = L.control.sidebar "pavingUserList",
            position: "left"
            closeButton: false
        @map.addControl @userSidebar
        @userSidebar.show()
        $(".ui-btn[href=#pavingUserList]").on "click", => @userSidebar.toggle()

        displaySendError = (error) ->
            errorDetails = JSON.parse(error.responseText).cause.message
            controls.DynamicAlert """Failed to notify user.<br/>
                <div data-role="collapsible" data-mini="true" data-inset="false" data-iconpos="right"
                    data-collapsed-icon="carat-d" data-expanded-icon="carat-u">
                    <h4>#{error.message}</h4>
                    #{errorDetails}
                </div>
            """

        onSendBreakNotification = (userId) ->
            Uplink.post "users/#{store.getState().project.id}/#{userId}/notifications",
                message: "Please drive to the break area for your break"
            .catch (error) ->
                displaySendError error

        onSendFinishNotification = (userId) ->
            Uplink.post "users/#{store.getState().project.id}/#{userId}/notifications",
                message: "Please finish your work for the day"
            .catch (error) ->
                displaySendError error

        onFinishSendMessage = ->
            Tracer.log "Sending message via notification"
            message = @messagePopup.popup().find("[name=inputMessage]").val()
            Uplink.post "users/#{store.getState().project.id}/#{userId}/notifications",
                message: message
            .catch (error) ->
                displaySendError error

        onCancelSendMessage = ->
            # ???

        onSendMessage = (userId) ->
            Tracer.log "Creating message popup"
            @messagePopup = new controls.DynamicPopup
                content: """
                    <div class="form-container">
                        <label for="inputMessage">Message</label>
                        <textarea cols="25" rows="3" name="inputMessage" id="inputMessage"
                            placeholder="Enter a message to send" data-mini="true">
                        </textarea>
                    </div>
                """
                buttons:
                    confirm:
                        title: "Send"
                        handler: onFinishSendMessage
                    cancel:
                        title: "Cancel"
                        handler: onCancelSendMessage

        @userList = new controls.UsersList
            getUsers: @getPavingUsers
            container: $("#pavingUserList")
            page: "pavingPage"
            actions: [
                {name: "Break", handler: onSendBreakNotification}
                {name: "Finish", handler: onSendFinishNotification}
                {name: "Message", handler: onSendMessage}
            ]
            sorting:
                name: "TTB"
                by: (user) -> user.ttb ? Infinity
            extraDetails: (user) ->
                if user.ttb?
                    ttbStyle =  "color: #ffffff; padding: 1px 4px; text-shadow: 0 0 0"
                    style =
                        if user.ttb < 0
                            "background-color: #aa0000; #{ttbStyle}"
                        else if 0 < user.ttb < 30 * 60
                            "background-color: #f28218; #{ttbStyle}"
                        else ""
                    """<span style="#{style}">Break in #{formattedDuration user.ttb * 1000}</span>"""
                else
                    if (user.role == "Truck" || user.role == "Concrete truck") && !user.hasSignedOn?
                        """<span style="color: #aa0000">No sign on today</span>"""
                    else
                        ""



        @stopObservingPavingPage = observeStore @getPavingState, @onChange
        @stopObservingWeather = observeStore (=> store.getState().weather), weatherReport.redraw

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

        updateControlPanelData = =>
            Tracer.log "Requesting control panel data"

            today = moment().tz(store.getState().project.timezone).format "YYYY-MM-DD"
            
            requests =
                R.fromPairs R.map (endpoint) =>
                    [endpoint, Uplink.get "paving/#{store.getState().project.id}/#{endpoint}", date: today]
                , ["trucks", "pavers", "batch-plants"]

            Promise.props requests
            .then (result) =>
                getChartData = (batchPlant) =>
                    params = {batchPlant: encodeURIComponent(batchPlant.name), date: today}
                    [batchPlant.name
                     Uplink.get("paving/#{store.getState().project.id}/production", params)]

                Promise.props R.fromPairs R.map getChartData, result["batch-plants"]
                .then (productionData) =>
                    formattedProductionData = R.mapObjIndexed (val) =>
                        # Iterating twice but the number of items is ~10
                        labels: R.pluck "hour", val
                        datasets: [{data: R.pluck "volume", val}]
                    , productionData

                    store.dispatch batch [
                        Action.pavingPage.data.setTruckInfo result["trucks"]
                        Action.pavingPage.data.setPaverInfo result["pavers"]
                        Action.pavingPage.data.setBatchPlantInfo result["batch-plants"]
                        Action.pavingPage.data.setProduction formattedProductionData
                    ]

        @controlPanelIntervalId = setInterval updateControlPanelData, 30000
        updateControlPanelData()


    onPageHide: =>
        Tracer.log "Stopping paving page updates"

        @userSidebar.hide()
        @userList.destroy()

        @stopObservingPavingPage()
        @$el.off()
        clearInterval @controlPanelIntervalId

        @clusteredMarkerLayer.destroy()
        @clusteredMarkerLayer = null
        @baseLayersLayer.destroy()
        @overlaysLayer.destroy()
        @stopObservingWeather()


    onPageShow: =>
        @map.invalidateSize()
        @map.fitBounds L.latLngBounds store.getState().project.bboxPoints.coordinates
        @render @getPavingState(), force: true


    setupMap: =>
        if @map?
            Tracer.log "map already set up, doing nothing"
            return

        @map = L.mapbox.map "pavingMapContainer", null,
            minZoom: 8
            attributionControl: compact: true

        @map.addControl L.control.scale imperial: false, position: "bottomleft"

        togglePanel = => store.dispatch Action.pavingPage.ui.panelToggle()
        @sidebarButton = new L.Control.Button icon: "fa-area-chart", onClick: togglePanel, position: "topright"
        @map.addControl @sidebarButton
        @sidebar = L.control.sidebar "pavingControlPanel", {position: "right", autoPan: false}
        @sidebar.on "hide", togglePanel
        @map.addControl @sidebar
        @sidebar.show()

        weatherReport.create @map


module.exports = PavingPage
