reduxBatched = require "redux-batched-actions"
batch = reduxBatched.batchActions

USER_ROLES = ["Backhoe", "Community", "Concrete truck", "Engineer", "Environment", "Foreman", "Grader", "Paver", "Safety", "Surveyor", "Truck"]
VEHICLE_ABB =
    "Light vehicle": "LV"
    "Pool vehicle": "PV"
    "Tool of trade": "ToT"

class BaseLayer
    constructor: (options) ->
        {@map, @collection} = options
        @layers = []

        if store.getState().mapType == "satellite"
            if @collection.length > 0
                Tracer.log "Adding drone base layers"

                @addDroneImageDate()

                droneLayers = R.filter R.propEq("type", "drone"), @collection
                droneMaxZoom = R.reduce R.max, 0, (R.pluck "maxZoom", droneLayers)
                R.forEach (baseLayer) =>
                    layerMaxZoom = if baseLayer.type == "drone" then baseLayer.maxZoom else droneMaxZoom
                    layerMaxNativeZoom = R.min layerMaxZoom, baseLayer.maxNativeZoom
                    @addTileLayer baseLayer.id, {maxZoom: layerMaxZoom, maxNativeZoom: layerMaxNativeZoom, detectRetina: false, reuseTiles: true}
                , @collection
            else
                Tracer.log "Adding satellite base layer"
                @addTileLayer 'aoteastudios.gdb11pnh', {maxNativeZoom: 17, detectRetina: false, reuseTiles: true}

        else
            Tracer.log "Adding map base layer"
            @addTileLayer 'aoteastudios.map-ul9e086h', {maxZoom: 19, maxNativeZoom: 20, detectRetina: true, reuseTiles: true}

            lineworkLayers = R.filter R.propEq("type", "linework"), @collection
            R.forEach (baseLayer) =>
                Tracer.log "Adding linework layer to street map"
                @addTileLayer baseLayer.id, {maxZoom: 19, maxNativeZoom: baseLayer.maxNativeZoom, detectRetina: false, reuseTiles: true}
            , lineworkLayers


    addTileLayer: (id, options) =>
        Tracer.log "Adding tile layer"
        layer = L.mapbox.tileLayer id, options
        @map.addLayer layer
        @layers.push layer
        layer


    destroy: =>
        Tracer.log "Removing base layers"
        R.forEach ((layer) => @map.removeLayer layer), @layers
        @layers = []
        @map.attributionControl.setPrefix ""

    addDroneImageDate: =>
        droneLayers = R.filter R.propEq("type", "drone"), @collection
        if droneLayers.length > 0
            @map.attributionControl.setPrefix "Imagery: " + droneLayers[0].updatedAt.split(/\s/)[0]



# This is a pseudo-layer which creates GeometriesLayer's
class OverlaysLayer
    constructor: (options) ->
        {@map, @collection, @allowEditing, @$el} = options
        @layers = []
        R.forEach (overlay) =>
            Tracer.log "Adding geometry layer for #{overlay.id}"
            options =
                map: @map
                defaultStyle: overlay.properties
                overlayName: overlay.name
                geometries: overlay.geometries
                $el: @$el
            layer = if @allowEditing && overlay.mutable
                @easel = new MutableGeometriesLayer options
            else
                new GeometriesLayer options
            @layers.push layer
            layer
        , @collection


    hasChanges: => @easel?.changing


    destroy: =>
        R.forEach ((layer) => layer.destroy()), @layers
        @layers = []



class GeometriesLayer
    constructor: (options) ->
        {@map, @geometries, @defaultStyle, @overlayName} = options
        @defaultStyle.clickable = false
        @editableAttributes = ['name', 'description', 'purpose']

        @render()
        @map.on "draw:drawstart", (e) => @drawStarted()
        @map.on "draw:drawstop",  (e) => @drawStopped()


    getLayerType: (layer) ->
        if layer instanceof L.Marker
            "marker"
        else if layer instanceof L.Polyline && !(layer instanceof L.Polygon)
            "polyline"
        else
            "polygon"

    drawStarted: =>
        # hide/disable popups upon starting edit mode, reinstate them after drawing completes
        @map.closePopup()
        R.forEach ((layer) => layer.unbindPopup()), @layer.getLayers()

    drawStopped: =>
        R.forEach @attachPopup, @layer.getLayers()

    attachPopup: (layer) =>
        layer.unbindPopup()
        type = @getLayerType layer
        desc = R.replace /\n/g, "<br/>\n", (layer.description || "")
        measurement = layer.measurement
        measureHTML = if measurement? then """
            #{measurement.description}: #{measurement.amount}
        """ else ""

        line =  """<hr style="border: 0; height: 1px; background: #e0e0e0" />"""

        purposeHTML =
            if layer.purpose? && layer.purpose != "none"
                purpose = R.find ((purpose) -> purpose[0] == layer.purpose), POLYGON_PURPOSES
                "Purpose: #{purpose[1]}<br>"
            else ""

        if type == "marker"
            photoButton = if layer.photoUrl?
                """<br/><a href="#{layer.photoUrl}" target="_blank">View photo</a>"""
            else ""

            assetTimeHtml = if layer.lastTimeDetected?
                lastTime = moment.tz(layer.lastTimeDetected * 1000, store.getState().project.timezone)
                """#{line} Last detected #{lastTime.format("D/M/YY")} at #{lastTime.format("H:mm")}"""
            else ""

            createdByHtml = if layer.feature.createdBy?
                """<br/>Made by: #{layer.feature.createdBy}"""
            else ""

            observationTypeAndDate =
                if layer.observationType?
                    """
                    <br/>Type: #{layer.observationType}
                    <br/>Created at: #{layer.feature.createdAt}
                    """
                else ""

            layer.bindPopup "<b>#{layer.name}</b><br/>#{desc}#{photoButton}#{createdByHtml}#{assetTimeHtml}#{observationTypeAndDate}"

        else if (type == "polygon" || type == "polyline") && layer.name?
            layer.bindPopup "<h2>#{layer.name}</h2>#{desc}#{line}#{purposeHTML}#{measureHTML}"


    applyStyleAndPopup: (feature, layer) =>
        layer.id ?= feature.id
        style = @featureStyle feature

        # Copy properties from the feature to the layer object
        attributesToCopy = R.concat @editableAttributes, ["photoUrl", "lastTimeDetected", "observationType"]
        R.forEach ((attribute) => layer[attribute] = feature.properties[attribute]), attributesToCopy

        layer.style = R.pick ["weight", "color"], style
        layer.measurement = window.measure layer.toGeoJSON()
        layer.options = R.merge layer.options, style

        if feature.geometry.type == "Point"
            layer.setIcon L.AwesomeMarkers.icon style
            layer.setZIndexOffset(-200)

        @attachPopup layer


    featureStyle: (feature) =>
        defStyle = switch feature.geometry.type
            when "Point"
                @defaultStyle.marker
            when "LineString", "Polygon"
                @defaultStyle.polygon
            else {}

        R.merge defStyle, (feature.properties ? {})


    render: =>
        # Smooth factor of 2.0 limits the display error to ~5-10m at 200m and
        # closer zoom levels; not using collection.toJSON() in a bid to avoid
        # cloning all the data
        @layer = L.geoJson @geometries,
            style: @featureStyle
            onEachFeature: @applyStyleAndPopup
            smoothFactor: 2.0

        #TODO: mutable part should be moved to MutableGeometriesLayer
        if @mutable
            R.forEach ((layer) => @map.userEasel.addLayer layer), @layer.getLayers()
        else
            @layer.addTo @map


    destroy: =>
        @map.removeLayer @layer if @layer?
        @map.off "draw:drawstart draw:drawstop"

        
    redraw: (geometries) =>
        @geometries = geometries
        @destroy()
        @render()


class MutableGeometriesLayer extends GeometriesLayer
    constructor: (options) ->
        @mutable = true  #TODO: get rid of
        @changing = false
        @layerAttrBackup = {}

        @$el  = options.$el
        @map = options.map

        @map.userEasel = L.featureGroup().addTo @map
        L.drawLocal.edit.toolbar.actions.save.text = "Confirm"
        @map.draw = new L.Control.Draw(
            edit:
                featureGroup: @map.userEasel
                edit:
                    selectedPathOptions:
                        maintainColor: true
                        weight: 6
            draw:
                circle: false
                rectangle: false
                marker:
                    icon: @getMarkerIcon()
                polyline:
                    shapeOptions:
                        weight: 6
                polygon:
                    allowIntersection: false
                    shapeOptions:
                        weight: 6
                    showArea: true
        ).addTo @map

        @map.on "draw:created",     (e) => @createGeometry e.layer

        @map.on "draw:editstart",   (e) => @editStarted()
        @map.on "draw:edited",      (e) => @editGeometries e.layers
        @map.on "draw:editstop",    (e) => @editStopped()

        @map.on "draw:deletestart", (e) => @deleteStarted()
        @map.on "draw:deleted",     (e) => @deleteGeometries e.layers
        @map.on "draw:deletestop",  (e) => @deleteStopped()

        super options


    $: (selector) =>
        @$el.find selector


    createGeometry: (layer) =>
        @changing = true
        @map.removeControl @map.draw
        @map.userEasel.addLayer layer

        resurrectDraw = =>
            Tracer.log "Restoring drawing controls"
            @map.addControl @map.draw
            @map.userEasel.removeLayer layer
            @changing = false

        onSaveButton = (e) =>
            Tracer.log "Popup save button"
            @saveGeometry layer
            resurrectDraw()

        onCancelButton = (e) =>
            Tracer.log "Popup cancel button"
            resurrectDraw()

        new controls.GeometryForm
            layer: layer
            saveHandler: onSaveButton
            cancelHandler: onCancelButton


    getMarkerIcon: =>
        L.AwesomeMarkers.icon
            icon: 'exclamation'
            prefix: 'fa'
            markerColor: 'orange'
            iconColor: 'white'


    editStarted: =>
        @changing = true
        @map.closePopup()
        @geometryList = new mapLists.GeometryEditList layers: @layer.getLayers(), $el: @$el

        @layer.eachLayer (layer) =>
            # Backup layer name and desc
            @layerAttrBackup[L.Util.stamp layer] = R.pick @editableAttributes, layer
            layer.unbindPopup()


    editGeometries: (layers) =>
        @justEdited = true
        layers.eachLayer (layer) => @saveGeometry layer


    saveGeometry: (layer) =>
        feature = layer.toGeoJSON()
        feature.id ?= layer.id
        R.forEach ((attribute) => feature.properties[attribute] = layer[attribute]), @editableAttributes

        # Only record the purpose property for polygons!
        if (feature.geometry.type != "Polygon") then delete feature.properties['purpose']

        Uplink.post "projects/#{store.getState().project.id}/geometries/save", feature
        .then (created) =>
            @layer.addLayer layer if not layer.id?

            # Remove backup entry
            delete @layerAttrBackup[L.Util.stamp layer]
            Tracer.log "Layer saved #{L.Util.stamp layer} #{layer.name}"

            feature.id ?= parseInt created.id
            @applyStyleAndPopup feature, layer
            @map.userEasel.addLayer layer


    editStopped: =>
        @changing = false
        @geometryList.destroy()
        delete @geometryList
        if @justEdited
            # Save any layers that have been changed during the edit
            @layer.eachLayer (layer) =>
                # Check for changes by comparing our backup against the edited layer
                id = L.Util.stamp layer
                if @layerAttrBackup.hasOwnProperty id
                    arePropertiesEqual = R.reduce (accum, attribute) =>
                        accum and R.eqProps(attribute, @layerAttrBackup[id], layer)
                    , true, @editableAttributes

                    # Only save the geometry layer if any editable properties have changed
                    if (!arePropertiesEqual) then @saveGeometry layer
        else
            # Revert layers' attributes if edit was canceled
            @layer.eachLayer (layer) =>
                id = L.Util.stamp layer
                if @layerAttrBackup.hasOwnProperty id
                    # Revert changes made to the layer
                    R.forEach ((attribute) => layer[attribute] = @layerAttrBackup[id][attribute]), @editableAttributes

        @layerAttrBackup = {}
        @justEdited = false
        @layer.eachLayer (layer) => @attachPopup layer


    deleteStarted: =>
        @changing = true
        @map.closePopup()
        @layer.eachLayer (layer) =>
            layer.setStyle? weight: 6
            layer.unbindPopup()
        @geometryList = new mapLists.GeometryDeleteList layers: @layer.getLayers(), $el: @$el


    deleteGeometries: (layers) =>
        layers.eachLayer (layer) =>
            Uplink.get "projects/#{store.getState().project.id}/geometries/delete/#{layer.id}"
            .then () =>
                @layer.removeLayer layer


    deleteStopped: =>
        @changing = false
        @geometryList.destroy()
        @layer.eachLayer (layer) =>
            layer.setStyle? weight: layer.style.weight
            @attachPopup layer


    destroy: =>
        super
        @geometryList?.destroy()
        @map.off """
            draw:created
            draw:editstart draw:edited draw:editstop
            draw:deletestart draw:deleted draw:deletestop
        """
        @map.removeLayer @map.userEasel
        @map.removeControl @map.draw
        delete @map.userEasel
        delete @map.draw



markerBuilders =
    getDate: (p) =>
        timestamp = p.createdAt ? p.timestamp
        (p.lastPositionAt ?
            moment(timestamp).tz(store.getState().project.timezone).format(TIME_FORMAT)).slice 0, -3

    user:
        roleClass: (role) =>
            if R.contains role, USER_ROLES
                R.replace(/\s+/g, "", R.toLower(role)) + "Icon"
            else
                "personIcon"


        iconText: (p) =>
            Tracer.log "Icon text with", p
            switch p.role
                when "Truck"
                    p.truckNo
                when "Concrete truck"
                    p.truckWheelCount + if p.isLoaded? then (if p.isLoaded then "L" else "E") else ""
                else
                    # extract the initials
                    R.pipe(R.trim, R.split(" "), (R.map R.nth 0), R.join(""), R.toUpper, R.take(3)) p.name


        iconHtml: (p) =>
            headingIndicator = if p.speed > 0.01
                """<div class="headingIndicator" style="-webkit-transform: rotate(#{p.heading}deg)"></div>"""
            else
                ""

            """
            <div class="#{markerBuilders.user.roleClass p.role}" style="opacity: #{p.opacity}">
                #{headingIndicator}
                #{p.label}
            </div>
            """


        create: (options) ->
            params = R.merge {opacity: 1.0, riseOnHover: true, zIndexOffset: 0}, options
            params.label ?= markerBuilders.user.iconText params
            params.tooltip = options.name
            cssIcon = L.divIcon
                className: "iconContainer"
                iconSize: [60, 60]
                html: markerBuilders.user.iconHtml(params), markerBuilders.user.iconText(params)

            marker = L.marker L.latLng([params.lat, params.lon]), {
                icon: cssIcon
                title: params.tooltip
                riseOnHover: params.riseOnHover
                zIndexOffset: params.zIndexOffset
            }

            marker.id = params.id
            marker.trail = params.trail ? [] # Trail markers don't have a trail property!
            marker.type = "user"
            marker


        buildPopupContent: (p) =>
            date = markerBuilders.getDate p
            timeString = """<span style = "font-size: 0.8em">Last updated: #{date}</span>"""

            name = if p.role == "Truck" || p.role == "Concrete truck" then p.truckNo else p.name

            role = if p.role? && p.role.length > 0
                " - #{p.role}" + if p.role == "Truck" || p.role == "Concrete truck" then " (#{p.truckNo})" else ""
            else
                ""

            company = if p.company? && p.company.length > 0 then "<em>#{p.company}</em><br/>" else ""

            phoneDetails = if p.phoneNo? && p.phoneNo.length > 0
                "#{p.phoneNo}"
            else
                "unknown"

            "<b>#{p.name}</b>#{role}<br/>#{company}#{timeString}<br/>Phone: #{phoneDetails}"


    vehicle:
        iconText: (p) =>
            p.number


        iconHtml: (p) =>
            vehicleSvg = """
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 470 470" class="svgPickup">
                <g>
                    <path style="fill:#FFFFFF;" d="M253.281,140.703c4.142,0,7.5,3.358,7.5,7.5v38.32h95.562l-21.997-60.82h-81.065
                        C253.28,125.703,253.28,140.703,253.281,140.703z"/>
                    <path style="fill:#FD830C;" d="M215.312,201.523H15v84.583h8.026c8.159-38.721,42.581-67.879,83.693-67.879
                        s75.533,29.159,83.693,67.879h24.901V201.523z"/>
                    <path style="fill:#FFAD61;" d="M440.038,255.5H455v-11.367c0-13.202-10.924-26.603-23.855-29.263l-64.877-13.347H253.281
                        c-4.142,0-7.5-3.358-7.5-7.5v-45.82c0-4.142,3.357-7.499,7.499-7.5v-15c-12.664,0.001-22.968,10.304-22.968,22.969v45.351v92.083
                        h80.328c7.396-21.99,28.191-37.879,52.641-37.879s45.245,15.889,52.641,37.879H455V270.5h-14.962c-4.142,0-7.5-3.358-7.5-7.5
                        S435.896,255.5,440.038,255.5z M273.281,231.523h-20c-4.142,0-7.5-3.358-7.5-7.5s3.358-7.5,7.5-7.5h20c4.142,0,7.5,3.358,7.5,7.5
                        S277.423,231.523,273.281,231.523z"/>
                    <path style="fill:#4D3D36;" d="M434.167,200.178l-61.512-12.655l-25.994-71.871c-1.074-2.97-3.894-4.949-7.053-4.949h-86.328
                        c-20.936,0-37.969,17.033-37.969,37.969v37.851H7.5c-4.142,0-7.5,3.358-7.5,7.5v99.583c0,4.142,3.358,7.5,7.5,7.5h13.751
                        c-0.027,0.884-0.067,1.765-0.067,2.656c0,4.142,3.358,7.5,7.5,7.5s7.5-3.358,7.5-7.5c0-38.894,31.642-70.536,70.535-70.536
                        s70.535,31.642,70.535,70.536c0,4.142,3.358,7.5,7.5,7.5s7.5-3.358,7.5-7.5c0-0.891-0.04-1.772-0.067-2.656h30.626h85.001
                        c-0.042,0.881-0.067,1.765-0.067,2.656c0,30.622,24.913,55.535,55.535,55.535s55.535-24.913,55.535-55.535
                        c0-0.891-0.026-1.776-0.067-2.656H462.5c4.142,0,7.5-3.358,7.5-7.5v-49.473C470,223.961,453.926,204.243,434.167,200.178z
                         M440.038,270.5H455v15.605h-39.078c-7.396-21.99-28.191-37.879-52.641-37.879s-45.245,15.889-52.641,37.879h-80.328v-92.083
                        v-45.351c0-12.665,10.303-22.968,22.968-22.969c0.001,0,81.067,0,81.067,0l21.997,60.82h-95.562v-38.32c0-4.142-3.358-7.5-7.5-7.5
                        c-4.143,0.001-7.5,3.358-7.5,7.5v45.82c0,4.142,3.358,7.5,7.5,7.5h112.986l64.877,13.347C444.076,217.53,455,230.931,455,244.133
                        V255.5h-14.962c-4.142,0-7.5,3.358-7.5,7.5S435.896,270.5,440.038,270.5z M363.281,344.297c-22.351,0-40.535-18.184-40.535-40.535
                        c0-22.352,18.184-40.536,40.535-40.536s40.535,18.184,40.535,40.536C403.816,326.113,385.632,344.297,363.281,344.297z
                         M106.719,218.226c-41.112,0-75.533,29.159-83.693,67.879H15v-84.583h200.312v84.583h-24.901
                        C182.252,247.385,147.831,218.226,106.719,218.226z"/>
                    <path style="fill:#4D3D36;" d="M273.281,216.523h-20c-4.142,0-7.5,3.358-7.5,7.5s3.358,7.5,7.5,7.5h20c4.142,0,7.5-3.358,7.5-7.5
                        S277.423,216.523,273.281,216.523z"/>
                    <path style="fill:#5D734F;" d="M363.281,263.226c-22.351,0-40.535,18.184-40.535,40.536c0,22.351,18.184,40.535,40.535,40.535
                        s40.535-18.184,40.535-40.535C403.816,281.41,385.632,263.226,363.281,263.226z M363.281,329.297
                        c-14.08,0-25.535-11.455-25.535-25.535c0-14.081,11.455-25.536,25.535-25.536s25.535,11.455,25.535,25.536
                        C388.816,317.842,377.361,329.297,363.281,329.297z"/>
                    <path style="fill:#BCC987;" d="M363.281,293.226c-5.809,0-10.535,4.726-10.535,10.536c0,5.809,4.726,10.535,10.535,10.535
                        s10.535-4.726,10.535-10.535C373.816,297.952,369.09,293.226,363.281,293.226z"/>
                    <path style="fill:#4D3D36;" d="M363.281,278.226c-14.08,0-25.535,11.455-25.535,25.536c0,14.08,11.455,25.535,25.535,25.535
                        s25.535-11.455,25.535-25.535C388.816,289.681,377.361,278.226,363.281,278.226z M363.281,314.297
                        c-5.809,0-10.535-4.726-10.535-10.535c0-5.81,4.726-10.536,10.535-10.536s10.535,4.726,10.535,10.536
                        C373.816,309.571,369.09,314.297,363.281,314.297z"/>
                    <path style="fill:#5D734F;" d="M106.719,263.226c-22.351,0-40.535,18.184-40.535,40.536c0,22.351,18.184,40.535,40.535,40.535
                        s40.535-18.184,40.535-40.535C147.254,281.41,129.07,263.226,106.719,263.226z M106.719,329.297
                        c-14.08,0-25.535-11.455-25.535-25.535c0-14.081,11.455-25.536,25.535-25.536s25.535,11.455,25.535,25.536
                        C132.254,317.842,120.799,329.297,106.719,329.297z"/>
                    <path style="fill:#4D3D36;" d="M106.719,248.226c-30.622,0-55.535,24.913-55.535,55.536c0,30.622,24.913,55.535,55.535,55.535
                        s55.535-24.913,55.535-55.535C162.254,273.139,137.341,248.226,106.719,248.226z M106.719,344.297
                        c-22.351,0-40.535-18.184-40.535-40.535c0-22.352,18.184-40.536,40.535-40.536s40.535,18.184,40.535,40.536
                        C147.254,326.113,129.07,344.297,106.719,344.297z"/>
                    <path style="fill:#BCC987;" d="M106.719,293.226c-5.809,0-10.535,4.726-10.535,10.536c0,5.809,4.726,10.535,10.535,10.535
                        s10.535-4.726,10.535-10.535C117.254,297.952,112.528,293.226,106.719,293.226z"/>
                    <path style="fill:#4D3D36;" d="M106.719,278.226c-14.08,0-25.535,11.455-25.535,25.536c0,14.08,11.455,25.535,25.535,25.535
                        s25.535-11.455,25.535-25.535C132.254,289.681,120.799,278.226,106.719,278.226z M106.719,314.297
                        c-5.809,0-10.535-4.726-10.535-10.535c0-5.81,4.726-10.536,10.535-10.536s10.535,4.726,10.535,10.536
                        C117.254,309.571,112.528,314.297,106.719,314.297z"/>
                </g>
                </svg>
            """

            headingIndicator = if p.speed > 0.01
                """
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 216 216" width="11" height="11"
                    style="transform: rotate(#{p.heading}deg); fill: #333;">
                <g>
                <path stroke="none" fill-rule="nonzero" fill-opacity="1" d="M108.85471883422852,177.6378095998338
                    L30.22222883422853,215.5121424604228 L108.00001883422851,6.354060246849258e-7
                    L185.77776883422854,215.5121424604228 L108.85471883422852,177.6378095998338 z"/>
                </g>
                </svg>
                """
            else
                ""

            """
            <div class="vehicleMarker">
                <div class="truckPic">#{vehicleSvg}</div>
                <div class="info #{VEHICLE_ABB[p.role]}">
                    <spane class="block label">#{p.label}</span>
                    <span class="block">
                        #{headingIndicator}
                    </span>
                </div>
            </div>
            """


        create: (options) =>
            params = R.merge {opacity: 1.0, riseOnHover: true, zIndexOffset: 0}, options
            params.label ?= markerBuilders.vehicle.iconText params
            params.tooltip = options.name ? options.number
            cssIcon = L.divIcon
                className: "iconContainer"
                iconSize: [60, 60]
                html: markerBuilders.vehicle.iconHtml(params), markerBuilders.vehicle.iconText(params)

            marker = L.marker L.latLng([params.lat, params.lon]), {
                icon: cssIcon
                title: params.tooltip
                riseOnHover: params.riseOnHover
                zIndexOffset: params.zIndexOffset
            }

            marker.id = params.id
            marker.trail = params.trail ? [] # Trail markers don't have a trail property!
            marker.type = "vehicle"
            marker


        buildPopupContent: (p) =>
            date = markerBuilders.getDate p
            timeString = "<span style = 'font-size: 0.8em'>Last updated: #{date}</span>"
            "<b>#{p.number}</b> - #{p.role}<br/>Rego: #{p.rego}<br/>#{p.make} #{p.model}<br/>#{timeString}"



class ClusteredMarkerLayer
    constructor: (options) ->
        {@map, @page, @sources} = options
        @render()
        @map.on "click", (e) => @deselectMarker()


    destroy: =>
        @map.closePopup()

        if @cluster?
            @clearCluster()
            @map.removeLayer @cluster

            @clearSelectedMarkers()
            @map.removeLayer @selectedMarkers
        else
            # Do nothing - cluster not created yet or already destroyed


    createMarkers: (type, positions) =>
        R.map (item) ->
            markerBuilders[type].create item
        , positions


    handleSelection: (marker) =>
        showingPopup = store.getState()[@page].ui.showMarkerPopup
        selectedMarker = store.getState()[@page].filters.selectedMarker
        reClicking = selectedMarker.id == marker.id && selectedMarker.type == marker.type
        hasTrail = !R.isEmpty marker.trail

        # A user marker has been clicked on, cycle through 3 states
        #
        # 1st click = show popup + show trail for users
        # 2nd click = hide popup + deselect for vehicles
        # 3rd click = hide trail and deselect for users

        action =
            if !reClicking || !(showingPopup || hasTrail)
                "select"
            else if showingPopup && hasTrail
                "hide-popup"
            else
                "hide_all"

        Tracer.log "Handling marker click with action = ", action

        switch action
            when "select"
                store.dispatch batch [
                    Action[@page].ui.showMarkerPopup true
                    Action[@page].filters.selectMarker R.pick ["id", "type"], marker
                ]
            when "hide-popup"
                store.dispatch Action[@page].ui.showMarkerPopup false
            when "hide-all"
                @deselectMarker()


    deselectMarker: () =>
        # Next time we select a user we want the popup to appear again so set this to true
        store.dispatch batch [
            Action[@page].ui.showMarkerPopup true
            Action[@page].filters.selectMarker undefined
        ]


    addMarkersToCluster: (markers) =>
        R.forEach (marker) =>
            marker.on "click", =>
                @handleSelection marker
        , markers

        @cluster.addLayers markers


    clearCluster: =>
        R.forEach ((marker) => marker.clearAllEventListeners()), @cluster.getLayers()
        @cluster.clearLayers()


    clearSelectedMarkers: =>
        R.forEach (marker) =>
            marker.clearAllEventListeners()
        , @selectedMarkers.getLayers()

        @selectedMarkers.clearLayers()


    createMarkerWithPopup: (type, item) =>
        marker = markerBuilders[type].create item
        marker.bindPopup markerBuilders[type].buildPopupContent(item), {autoPan: false, keepInView: false}
        marker.on "mousedown", =>
            @handleSelection marker
        marker.on "popupclose", =>
            store.dispatch Action[@page].ui.showMarkerPopup false
        marker


    drawSelectedMarker: (type, selectedItem) =>
        selectedMarker = @createMarkerWithPopup type, selectedItem

        @selectedMarkers.addLayer selectedMarker

        if store.getState()[@page].ui.showMarkerPopup
            selectedMarker.openPopup()

        R.forEach ((marker) => @selectedMarkers.addLayer marker), @createTrailMarkers(type, selectedItem)


    createTrailMarkers: (type, marker) =>
        makeMarker = (marker, p) =>
            params = R.mergeAll marker, p,
                label: ""
                opacity: Math.max(0.9 - 0.1 * p.index, 0.4)
                tooltip: "#{marker.name}\n#{markerBuilders.getDate(p)}"
                riseOnHover: false
                zIndexOffset: -100

            markerBuilders[type].create params

        class Dist
            constructor: (@origin) ->
            isFarEnough: (pos) =>
                if L.latLng(@origin).distanceTo(pos) > 20
                    @origin = pos
                    true
                else
                    false

        filteredTrail = R.filter (new Dist marker).isFarEnough, marker.trail
        if R.isEmpty filteredTrail
            filteredTrail = R.tail marker.trail  # include at least one position in the trail, even if it's too close

        R.map ((pos) => makeMarker marker, pos), filteredTrail


    render: =>
        @cluster = new L.MarkerClusterGroup
            showCoverageOnHover: false
            maxClusterRadius: 50
            polygonOptions:
                fillColor: "#3887be"
                color: "#3887be"
                weight: 2
                opacity: 1
                fillOpacity: 0.5
        @map.addLayer @cluster

        @selectedMarkers = L.layerGroup []
        @map.addLayer @selectedMarkers


    redraw: =>
        selectedMarker = store.getState()[@page].filters.selectedMarker
        trackMarkers = store.getState()[@page].ui.trackUsers

        # The code to re-spiderfy on redraw is hacky but the cluster doesn't expose the methods to do it otherwise
        spiderfiedBounds = if @cluster._spiderfied?
            R.clone @cluster._spiderfied.getBounds()
        else
            undefined

        trackedMarkersPositions = R.pipe(
            R.values,
            R.filter(R.prop "isTrackable"),
            R.map((source) -> source.positionSelector()),
            R.reduce(R.concat, [])
        ) @sources

        if trackMarkers && trackedMarkersPositions?.length > 0
            bounds = L.latLngBounds R.map(R.pick(['lat','lon']), trackedMarkersPositions)
            @map.fitBounds bounds,
                padding: [50, 200]
                animate: true
                pan:
                    duration: 2
                    easeLinearity: 0.5

        @clearCluster()
        @clearSelectedMarkers()

        @map.closePopup()

        R.mapObjIndexed (source, type) =>
            nonSelectedMarkers = if selectedMarker.type == type
                R.reject R.propEq("id", selectedMarker.id), source.positionSelector()
            else
                source.positionSelector()
            @addMarkersToCluster @createMarkers type, nonSelectedMarkers
        , @sources

        if spiderfiedBounds?
            marker = R.find ((layer) => spiderfiedBounds.contains(layer.getLatLng())), @cluster.getLayers()
            if marker?
                marker.__parent.spiderfy()

        if !R.isEmpty selectedMarker
            selectedItem = R.find R.propEq("id", selectedMarker.id), @sources[selectedMarker.type].positionSelector()

            if selectedItem?
                @drawSelectedMarker selectedMarker.type, selectedItem
            else
                @map.closePopup()
        else
            # Do nothing, no marker selected



module.exports =
    BaseLayer: BaseLayer
    OverlaysLayer: OverlaysLayer
    markerBuilders: markerBuilders
    ClusteredMarkerLayer: ClusteredMarkerLayer
    GeometriesLayer: GeometriesLayer
