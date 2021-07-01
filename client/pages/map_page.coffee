reduxBatched = require "redux-batched-actions"
reduxReselect = require "reselect"

batch = reduxBatched.batchActions
createSelector = reduxReselect.createSelector

class MapPage extends pages.BasePage
    @pageId "mapPage"
    HEADER_BUTTON: {label: "Users", icon: "user", target: "#usersList" }

    constructor: ->
        super
        Tracer.log "in mapPage constructor"


    getMapState: =>
        R.merge store.getState().mapPage, data: 
            users: store.getState().users
            positions: store.getState().positions
            vehicles: store.getState().vehicles


    onChange: (mapState) =>
        @clusteredMarkerLayer.redraw()
        @usersList.redraw mapState.filters.users


    onPageBeforeShow: =>
        super
        @setupMap()

        @usersSidebar = L.control.sidebar 'usersList',
            position: 'left'
            closeButton: false
        @map.addControl @usersSidebar
        @usersSidebar.show() if store.getState().project.showUsersPanel
        
        $(".ui-btn[href=#usersList]").on 'click', => @usersSidebar.toggle()

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
                allowEditing: true
                $el: @$el

        positionSelector = (state) =>
            state.data.positions
        filterSelector = (state) =>
            if state.filters.users == "all"
                R.pluck("id", state.data.users)
            else
                state.filters.users

        selectorImpl = createSelector positionSelector, filterSelector
        , (positions, filteredUsers) =>
            R.filter ((pos) -> R.contains(parseInt(pos.id), filteredUsers)), positions

        filteredPositionSelector = => selectorImpl @getMapState()

        @assetsLayer = new mapLayers.GeometriesLayer
            map: @map
            defaultStyle: marker: icon: "rss", iconColor: "white", markerColor: "purple", prefix: "fa"
            overlayName: "assetsLayer"
            geometries: store.getState().assets

        @clusteredMarkerLayer = new mapLayers.ClusteredMarkerLayer
            map: @map
            page: "mapPage"
            sources:
                user:
                    isTrackable: true
                    positionSelector: filteredPositionSelector
                    marker: mapLayers.markerBuilders.user
                vehicle:
                    isTrackable: false
                    positionSelector: -> store.getState().vehicles
                    marker: mapLayers.markerBuilders.vehicle

        @usersList = new controls.UsersList
            container: $("#usersList")
            page: "mapPage"
            getUsers: => store.getState().users

        @stopObservingMapPage = observeStore @getMapState, @onChange
        @stopObservingWeather = observeStore (=> store.getState().weather), weatherReport.redraw
        @stopObservingAssets = observeStore (=> store.getState().assets), @assetsLayer.redraw


    onPageBeforeChange: (e) =>
        if @overlaysLayer?.hasChanges()
            e.preventDefault()
            e.stopPropagation()

            $("#menuPanel").panel "close"
            $("#menuPanel a").removeClass "ui-btn-active"

            new controls.DynamicPopup
                content: """<h5>Please finish modifying overlays.</h5>"""
                buttons:
                    cancel:
                        title: "Close"


    onPageHide: =>
        Tracer.log "Stopping map updates"
        @baseLayersLayer?.destroy()
        @overlaysLayer?.destroy()
        @clusteredMarkerLayer.destroy()

        @usersSidebar.hide()
        @usersList.destroy()

        @stopObservingMapPage()
        @stopObservingWeather()


    onPageShow: =>
        @map.invalidateSize()

        # We should pan map to project bbox only if we're not tracking users
        mapState = @getMapState()
        trackingSomething =
            mapState.ui.trackUsers &&
            mapState.data.positions.length > 0 &&
            (mapState.filters.users == "all" ||
            R.find ((pos) => R.contains(pos.id, mapState.filters.users)), mapState.data.positions)

        if !trackingSomething
            @map.fitBounds L.latLngBounds store.getState().project.bboxPoints.coordinates


    setupMap: =>
        if @map?
            Tracer.log "map already set up, doing nothing"
            return

        @map = L.mapbox.map "mapContainer", null,
            minZoom: 8
            attributionControl: compact: true

        @map.addControl L.control.scale imperial: false, position: "bottomleft"

        weatherReport.create @map


module.exports = MapPage
