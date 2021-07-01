module.exports =
    SpeedBandSelector: class
        # m/s
        SPEEDS:
            any: [0, 1000]
            "0": [0, 0.1]
            "1": [0.1, 1.39]
            "2": [1.39, 4.17]
            "3": [4.17, 11.11]
            "4": [11.11, 1000]

        constructor: (page, params) ->
            @speedRange = @SPEEDS["any"]
            id = params.id || "speed"

            @page = page
            @id = id

            page.$("." + params.containerClass).html """
                <a href = "##{id}Popup" id = "#{id}Button" data-rel = "popup" data-inline = "true"
                    class = "ui-btn ui-corner-all ui-shadow ui-btn-icon-right ui-icon-arrow-d"
                    data-transition = "flip" style = "width: 100%">Any speed</a>

                <div data-role = "popup" id = "#{id}Popup" class = "controlPopup" data-arrow = "t">
                    <div class = "#{id}List">
                        <ul data-role="listview" data-inset="true" data-filter-theme="b" data-divider-theme="b">
                            <li data-icon = "false"><a class = "speedItemButton" href="#any">Any speed</a></li>
                            <li data-icon = "false"><a class = "speedItemButton" href="#0">Stationary</a></li>
                            <li data-icon = "false"><a class = "speedItemButton" href="#1">0-5 km/h</a></li>
                            <li data-icon = "false"><a class = "speedItemButton" href="#2">6-15 km/h</a></li>
                            <li data-icon = "false"><a class = "speedItemButton" href="#3">16-40 km/h</a></li>
                            <li data-icon = "false"><a class = "speedItemButton" href="#4">40+ km/h</a></li>
                        </ul>
                    </div>
                </div>
            """
            .enhanceWithin()

            page.$(".#{id}List").on "click.#{page.id}", (e) =>
                @speedRange = @SPEEDS[$(e.target).attr("href").slice(1)]
                page.$("##{id}Button").text $(e.target).html()


        destroy: =>
            @page.$(".#{@id}List").off()
            @page.$("##{@id}Popup").popup "destroy"


        getValue: =>
            speedRange: @speedRange


    PersonSelector: class
        constructor: (page, params) ->
            id = params.id || "person"
            allLabel = params.allLabel || "Everyone"
            @userId = 0
            @roleId = 0

            @page = page
            @id = id

            page.$("." + params.containerClass).html """
                <a href = "##{id}Popup" id = "#{id}Button" data-rel = "popup" data-inline = "true"
                    class = "ui-btn ui-corner-all ui-shadow ui-btn-icon-right ui-icon-arrow-d"
                    data-transition = "flip" style = "width: 100%">#{allLabel}</a>

                <div data-role = "popup" id = "#{id}Popup" class = "controlPopup" data-arrow = "t">
                    <div class = "#{id}ListContainer" style = "padding: 10px; overflow-y: scroll;">
                        <ul class = "#{id}List" data-role = "listview" data-inset = "true" data-filter = "true"
                            data-filter-input="##{id}FilterInput" data-divider-theme="b">
                        </ul>
                    </div>
                </div>
            """
            .enhanceWithin()

            Promise.props [Uplink.get("projects/#{store.getState().project.id}/users/roles"),
                           Uplink.get("projects/#{store.getState().project.id}/users")]
            .then (results) =>
                # Filter down the results to a subset if required
                if params.roleFilter then results[0] = R.filter params.roleFilter, results[0]
                if params.userFilter then results[1] = R.filter params.userFilter, results[1]

                # Everyone (always add)
                @users = [{type:"user", icon:"user", id:0, name:allLabel}]

                # Add roles with the word "group" appended
                R.forEach ((role) => @users.push {type:"role", icon:"user", id:role.id, name:(role.name + " group")}), results[0]

                # Individual users
                R.forEach ((user) => @users.push {type:"user", icon:"false", id:user.id, name:user.name}), results[1]

                itemsHtml = R.reduce ((html, user) ->
                    html + "<li data-icon = '#{user.icon}'><a href = '\##{user.type}-#{user.id}'>#{user.name}</a></li>\n"
                ), "", @users

                page.$(".#{@id}List").html(itemsHtml).listview("refresh").on "click.#{page.id}", (e) =>
                    [type, selectedId] = $(e.target).attr("href").slice(1).split "-"
                    selectedId = parseInt(selectedId)
                    user = R.find ((item) -> (item.id == selectedId and item.type == type)), @users
                    @userId = (if (user.type == "user") then user.id else 0)
                    @roleId = (if (user.type == "role") then user.id else 0)
                    page.$("##{@id}Button").text user.name


            page.$("##{id}Popup").on popupbeforeposition: =>
                page.$(".#{id}ListContainer").css "height", $(window).height() * 0.6

            # prevent scrolling in the person list from bubbling to the main window
            page.$(".#{id}ListContainer").on "DOMMouseScroll.#{page.id} mousewheel.#{page.id}", (ev) ->
                $this = $(this)
                scrollTop = @scrollTop
                scrollHeight = @scrollHeight
                height = $this.height()
                delta = ((if ev.type is "DOMMouseScroll" then ev.originalEvent.detail * -40 else ev.originalEvent.wheelDelta))
                up = delta > 0
                prevent = ->
                    ev.stopPropagation()
                    ev.preventDefault()
                    ev.returnValue = false
                    false

                if !up && -delta > scrollHeight - height - scrollTop - parseInt($(this).css "padding-top") - parseInt($(this).css "padding-bottom")
                    # Scrolling down, but this will take us past the bottom.
                    $this.scrollTop scrollHeight
                    prevent()
                else if up && delta > scrollTop
                    # Scrolling up, but this will take us past the top.
                    $this.scrollTop 0
                    prevent()


        destroy: =>
            @page.$(".#{@id}List, ##{@id}Popup, .#{@id}ListContainer").off()
            @page.$("##{@id}Popup").popup "destroy"


        getValue: =>
            userId: @userId
            roleId: @roleId


    VehicleSelector: class
        constructor: (page, params) ->
            id = params.id || "vehicle"
            allLabel = params.allLabel || "All vehicles"
            @vehicleId = 0
            @roleId = 0

            @page = page
            @id = id

            page.$("." + params.containerClass).html """
                <a href = "##{id}Popup" id = "#{id}Button" data-rel = "popup" data-inline = "true"
                    class = "ui-btn ui-corner-all ui-shadow ui-btn-icon-right ui-icon-arrow-d"
                    data-transition = "flip" style = "width: 100%">#{allLabel}</a>

                <div data-role = "popup" id = "#{id}Popup" class = "controlPopup" data-arrow = "t">
                    <div class = "#{id}ListContainer" style = "padding: 10px; overflow-y: scroll;">
                        <ul class = "#{id}List" data-role = "listview" data-inset = "true" data-filter = "true"
                            data-filter-input="##{id}FilterInput" data-divider-theme="b">
                        </ul>
                    </div>
                </div>
            """
            .enhanceWithin()

            Promise.props
                roles: Uplink.get("projects/#{store.getState().project.id}/vehicles/roles")
                vehicles: Uplink.get("projects/#{store.getState().project.id}/vehicles")
            .then (result) =>
                # Filter down the results to a subset if required
                if params.roleFilter
                    result.roles = R.filter params.roleFilter, result.roles
                if params.vehicleFilter
                    result.vehicles = R.filter params.vehicleFilter, result.vehicles

                # All vehicles (always add)
                @vehicles = [{type: "vehicle", icon: "star", id: 0, description: allLabel}]

                # Add roles with the word "group" appended
                R.forEach (role) =>
                    @vehicles.push {type: "role", icon: "star", id: role.id, description: role.name + " group"}
                , result.roles

                # Individual vehicles
                R.forEach (vehicle) =>
                    @vehicles.push {type: "vehicle", icon: "false", id: vehicle.id
                        , description: "#{vehicle.number} - #{vehicle.make} #{vehicle.model}"}
                , result.vehicles

                itemsHtml = R.reduce ((html, vehicle) ->
                    html + """<li data-icon = "#{vehicle.icon}"><a
                        href = "\##{vehicle.type}-#{vehicle.id}">#{vehicle.description}</a></li>\n"""
                ), "", @vehicles

                page.$(".#{@id}List").html(itemsHtml).listview("refresh").on "click.#{page.id}", (e) =>
                    [type, selectedId] = $(e.target).attr("href").slice(1).split "-"
                    selectedId = parseInt(selectedId)
                    vehicle = R.find ((item) -> item.id == selectedId && item.type == type), @vehicles
                    @vehicleId = if vehicle.type == "vehicle" then vehicle.id else 0
                    @roleId = if vehicle.type == "role" then vehicle.id else 0
                    page.$("##{@id}Button").text vehicle.description


            page.$("##{id}Popup").on popupbeforeposition: =>
                page.$(".#{id}ListContainer").css "height", $(window).height() * 0.6

            # prevent scrolling in the vehicle list from bubbling to the main window
            page.$(".#{id}ListContainer").on "DOMMouseScroll.#{page.id} mousewheel.#{page.id}", (ev) ->
                $this = $(this)
                scrollTop = @scrollTop
                scrollHeight = @scrollHeight
                height = $this.height()
                delta = if ev.type == "DOMMouseScroll"
                    ev.originalEvent.detail * -40
                else
                    ev.originalEvent.wheelDelta
                up = delta > 0
                prevent = ->
                    ev.stopPropagation()
                    ev.preventDefault()
                    ev.returnValue = false
                    false

                if !up && -delta > scrollHeight - height - scrollTop - parseInt($(this).css "padding-top") - parseInt($(this).css "padding-bottom")
                    # Scrolling down, but this will take us past the bottom.
                    $this.scrollTop scrollHeight
                    prevent()
                else if up && delta > scrollTop
                    # Scrolling up, but this will take us past the top.
                    $this.scrollTop 0
                    prevent()


        destroy: =>
            @page.$(".#{@id}List, ##{@id}Popup, .#{@id}ListContainer").off()
            @page.$("##{@id}Popup").popup "destroy"


        getValue: =>
            vehicleId: @vehicleId
            roleId: @roleId


    AreaSelector: class
        constructor: (page, params) ->
            id = params.id || "area"
            allLabel = params.allLabel || "All areas"
            @geometryId = 0
            @page = page
            @id = id
            @areaName = params.id ? "geometry"

            page.$("." + params.containerClass).html """
                <a href = "##{id}Popup" id = "#{id}Button" class = "ui-btn ui-corner-all ui-shadow ui-btn-icon-right ui-icon-arrow-d"
                    data-rel = "popup" data-inline = "true" data-transition = "flip" style = "width: 100%">#{allLabel}</a>

                <div data-role = "popup" id = "#{id}Popup" class = "controlPopup" data-arrow = "t">
                    <div class = "#{id}ListContainer" style = "padding: 10px; overflow-y: scroll;">
                        <ul class = "#{id}List" data-role = "listview" data-inset = "true" data-filter = "true"
                            data-filter-input="##{id}FilterInput" data-divider-theme="b">
                        </ul>
                    </div>
                </div>
            """
            .enhanceWithin()

            Uplink.get("projects/#{store.getState().project.id}/data/areas").then (geometries) =>
                @geometries = "0": properties: name: allLabel
                R.forEach ((geom) => @geometries[geom.id] = geom), geometries

                itemsHtml = ["<li data-icon = 'false'><a href = '#0'>#{allLabel}</a></li>"]
                .concat R.map ((geom) ->
                    "<li data-icon = 'false'><a href = '\##{geom.id}'>#{geom.properties.name || ""}</a></li>"
                    ), geometries
                .join "\n"

                page.$(".#{id}List").html(itemsHtml).listview("refresh").on "click.#{page.id}", (e) =>
                    @geometryId = $(e.target).attr("href").slice(1)
                    page.$("##{id}Button").text @geometries[@geometryId].properties.name



            page.$("##{id}Popup").on popupbeforeposition: =>
                page.$(".#{id}ListContainer").css "height", $(window).height() * 0.6

            # prevent scrolling in the person list from bubbling to the main window
            page.$(".#{id}ListContainer").on "DOMMouseScroll.#{page.id} mousewheel.#{page.id}", (ev) ->
                $this = $(this)
                scrollTop = @scrollTop
                scrollHeight = @scrollHeight
                height = $this.height()
                delta = ((if ev.type is "DOMMouseScroll" then ev.originalEvent.detail * -40 else ev.originalEvent.wheelDelta))
                up = delta > 0
                prevent = ->
                    ev.stopPropagation()
                    ev.preventDefault()
                    ev.returnValue = false
                    false

                if !up && -delta > scrollHeight - height - scrollTop - parseInt($(this).css "padding-top") - parseInt($(this).css "padding-bottom")
                    # Scrolling down, but this will take us past the bottom.
                    $this.scrollTop scrollHeight
                    prevent()
                else if up && delta > scrollTop
                    # Scrolling up, but this will take us past the top.
                    $this.scrollTop 0
                    prevent()


        destroy: =>
            @page.$(".#{@id}List, ##{@id}Popup, .#{@id}ListContainer").off()
            @page.$("##{@id}Popup").popup "destroy"


        getValue: =>
            "#{@areaName}Id": @geometryId



    DateRangeSelector: class
        constructor: (page, params) ->
            Tracer.log "Constructing date range selector"
            getDateRanges = ->
                # initially calculate all ranges in the user's time zone
                zone = store.getState().project.timezone

                today = moment().tz(zone).clone().startOf("day")
                yesterday = today.clone().subtract(1, "days").startOf "day"
                #endOfToday = Date.tomorrow().addSeconds(-1)
                weekStart = weekStart = today.clone().add (if today.day() == 0 then -6 else -today.day() + 1), "days"
                monthStart = monthStart = today.clone().date(1)

                dateRanges =
                    today: [today, today]
                    yesterday: [yesterday, yesterday]
                    thisWeek: [weekStart, today]
                    lastWeek: [weekStart.clone().add(-7, "d"), weekStart.clone().add(-1, "d")]
                    thisMonth: [monthStart, today]
                    lastMonth: [monthStart.clone().add(-1, "months"), monthStart.clone().add(-1, "d")]

                # convert dates into strings
                for key, value of dateRanges
                    dateRanges[key] = R.map ((item) -> item.format "YYYY-MM-DD"), value

                dateRanges

            @dateRanges = getDateRanges()

            @dateRange = @dateRanges.today

            @isCustomRangeShown = false

            id = params.id || "date"

            @page = page
            @id = id

            page.$("." + params.containerClass).html """
                <a href = "##{id}Popup" id = "#{id}Button" class = "ui-btn ui-corner-all ui-shadow ui-btn-icon-right ui-icon-arrow-d"
                   data-rel = "popup" data-inline = "true" data-transition = "flip" style = "width: 100%">Today</a>

                <div data-role = "popup" id = "#{id}Popup" class = "controlPopup" data-arrow = "t">
                    <div data-role="collapsible-set" style="margin:0; width:600px;">
                        <div data-role = "collapsible" data-collapsed="false">
                            <h3>Predefined period:</h3>
                            <ul class = "#{id}List" data-role="listview" data-filter-theme="b" data-divider-theme="b">
                                <li data-icon = "false"><a href="#today">Today</a></li>
                                <li data-icon = "false"><a href="#yesterday">Yesterday</a></li>
                                <li data-icon = "false"><a href="#thisWeek">This week</a></li>
                                <li data-icon = "false"><a href="#lastWeek">Last week</a></li>
                                <li data-icon = "false"><a href="#thisMonth">This month</a></li>
                                <li data-icon = "false"><a href="#lastMonth">Last month</a></li>
                            </ul>
                        </div>
                        <div data-role = "collapsible" class = "#{id}CustomRange">
                            <h3>Or dates between...</h3>
                            <input id = '#{id}fromDate' class = "date" type = "text" data-role = "datebox"
                                data-options = '{"mode":"calbox", "showInitialValue": true, "useNewStyle":true,
                                "useInline": true, "hideInput": true, "calHighToday": false,
                                "beforeToday": false, "useHeader": false, "overrideCalStartDay": 1}' />
                            <input id = '#{id}toDate' class = "date" type = "text" data-role = "datebox"
                                data-options = '{"mode":"calbox", "showInitialValue": true, "useNewStyle":true,
                                "useInline": true, "hideInput": true, "calHighToday": false,
                                "beforeToday": false, "useHeader": false, "overrideCalStartDay": 1}' />
                        </div>
                    </div>

                </div>
            """
            .enhanceWithin()

            control = this
            page.$("##{id}Popup [data-role='collapsible']").collapsible
                collapse: (event, ui) ->
                    $(@).children().next().slideUp(150)
                expand: (event, ui) ->
                    console.log "Target is CustomRange: ", $(event.target).hasClass "#{id}CustomRange"
                    control.isCustomRangeShown = $(event.target).hasClass "#{id}CustomRange"
                    $(@).children().next().hide()
                    $(@).children().next().slideDown(150)

            page.$(".#{id}CustomRange").collapsible "collapse"  # work around a problem with dateboxes
                                                                # which refuse to be hidden when the collapsible is created

            page.$("##{id}Popup .ui-datebox-container").removeClass("ui-overlay-shadow")

            page.$(".#{id}List").on "click.#{page.id}", (e) =>
                @dateRanges = getDateRanges()
                @dateRange = @dateRanges[page.$(e.target).attr("href").slice(1)]
                page.$("##{id}Button").text $(e.target).html()
                page.$("##{id}fromDate").datebox("setTheDate", new Date @dateRange[0]) #Date is left here, as Datebox doesn't work with Moment
                page.$("##{id}toDate").datebox("setTheDate", new Date @dateRange[1])

            page.$("##{id}fromDate").datebox("setTheDate", new Date @dateRange[0])
            page.$("##{id}toDate").datebox("setTheDate", new Date @dateRange[1])

            page.$("##{id}fromDate").on "change.#{page.id}", (e) =>
                toDate = moment(page.$("##{id}toDate").datebox("getTheDate"))
                fromDate = moment(page.$("##{id}fromDate").datebox("getTheDate"))
                if fromDate > toDate
                    page.$("##{id}toDate").datebox("setTheDate", fromDate.toDate())
                else
                    # do nothing: toDate is already >= fromDate

            page.$("##{id}toDate").on "change.#{page.id}", (e) =>
                toDate = moment(page.$("##{id}toDate").datebox("getTheDate"))
                fromDate = moment(page.$("##{id}fromDate").datebox("getTheDate"))
                if toDate < fromDate
                    page.$("##{id}fromDate").datebox("setTheDate", toDate.toDate())
                else
                    # do nothing: fromDate is already <= toDate

            page.$("##{id}fromDate, ##{id}toDate").on "change.#{page.id}", (e) =>
                return if !@isCustomRangeShown
                @dateRange = [moment(page.$("##{id}fromDate").datebox("getTheDate")).format("YYYY-MM-DD"),
                              moment(page.$("##{id}toDate").datebox("getTheDate")).format ("YYYY-MM-DD")]
                page.$("##{id}Button").text "Between " + moment(page.$("##{id}fromDate").datebox("getTheDate")).format("DD/MM/YY") +
                    " and " + moment(page.$("##{id}toDate").datebox("getTheDate")).format("DD/MM/YY")


        destroy: =>
            Tracer.log "Destroying date range selector"
            @page.$(".#{@id}List, ##{@id}fromDate, ##{@id}toDate").off()
            Tracer.log "Popup:", @page.$("##{@id}Popup")
            @page.$("##{@id}Popup").popup "destroy"
            #@page.$("##{@id}Popup-popup, ##{@id}Popup-screen").remove()


        getValue: =>
            dateRange: @dateRange



    DynamicPopup: class
        constructor: (options) ->
            {@content, @buttons} = options

            # No content - no popup
            return if not @content?

            confirmButton = if @buttons?.confirm
                """
                    <a class="pop-confirm-btn ui-btn ui-icon-save ui-corner-all ui-mini">
                        #{@buttons.confirm.title ? "Confirm"}
                    </a>
                """
            else
                ""

            cancelButton = if @buttons?.cancel?.title == "X"
                """
                    <a data-rel="back" class="pop-cancel-btn ui-btn ui-corner-all ui-mini ui-shadow ui-icon-delete ui-btn-icon-notext ui-btn-right">
                        X
                    </a>
                """
            else if @buttons?.cancel
                """
                    <a data-rel="back" class="pop-cancel-btn ui-btn ui-corner-all ui-mini ui-shadow ui-btn-inline">
                        #{@buttons.cancel.title ? "Cancel"}
                    </a>
                """
            else
                ""

            pop = $("""
                <div data-role="popup" class="dynamic-popup" name="popupBasic" data-dismissible="false" style="text-align: center">
                    #{@content}
                    <div class="ui-controlgroup ui-controlgroup-horizontal" data-role="controlgroup" data-type="horizontal" data-mini="true">
                        <div class="ui-controlgroup-controls">
                            #{confirmButton}
                            #{cancelButton}
                        </div>
                    </div>
                </div>
            """)

            buttonsCount = (if confirmButton then 1 else 0) + (if cancelButton then 1 else 0)
            pop.find(".ui-btn").css "width", "#{100 / buttonsCount}%"

            pop.appendTo $.mobile.activePage
                .popup()
                .enhanceWithin()
                .popup "open"

            pop.find(".pop-confirm-btn").one "click", (e) =>
                e.popupel = pop
                e.preventDefault()
                e.stopPropagation()

                @buttons.confirm.handler?(e)
                pop.popup("close")

            pop.find(".pop-cancel-btn").one "click", (e) =>
                e.preventDefault()
                e.stopPropagation()

                Tracer.log "DynamicPopup cancel handler"
                @buttons?.cancel?.handler?()
                Tracer.log "Closing the popup"
                pop.popup("close")


            # Remove the popup after it has been closed to manage DOM size
            $(document).one "popupafterclose", ".ui-popup", ->
                $(this).remove()

            @popupObj = pop


        popup: =>
            @popupObj


    DynamicAlert: (message) =>
        new controls.DynamicPopup
            content: "<h5>#{message}</h5>"
            buttons:
                cancel:
                    title: "Close"


    GeometryForm: class
        constructor: (options) ->
            {@layer, @saveHandler, @cancelHandler} = options

            geoJSON = @layer.toGeoJSON()
            @isPolygon = geoJSON.geometry.type == "Polygon"
            measurement = measure geoJSON

            measureHTML = if measurement then """
                    <label>#{measurement.description}</label>
                    <span class="information ui-corner-all">#{measurement.amount}</span>
            """ else ""

            if (!@layer.name?) then @layer.name = ''
            if (!@layer.description?) then @layer.description = ''
            if (@isPolygon && !@layer.purpose?) then @layer.purpose = 'none'

            onSave = (e) =>
                @layer.name        = @popup.popup().find("[name=inputName]").val() # $(e.target).find("[name=inputName]").val()
                @layer.description = @popup.popup().find("[name=inputDesc]").val() # $(e.target).find("[name=inputDesc]").val()
                if @isPolygon then @layer.purpose = @popup.popup().find("[name=inputPurpose]").val()
                if @layer.name == "" then @layer.name = "Unnamed"
                @saveHandler e

            purposeHTML = if @isPolygon
                optionsHtml = R.map (purpose) =>
                    selected = if @layer.purpose == purpose[0] then "selected " else ""
                    """<option #{selected}value="#{purpose[0]}">#{purpose[1]}</option>"""
                , POLYGON_PURPOSES


                """
                <label for="inputPurpose">Purpose</label>
                <select  data-mini="true" name="inputPurpose">#{optionsHtml.join "\n"}</select>
                """
            else
                ""

            @popup = new controls.DynamicPopup
                content: """
                    <div class="form-container">
                        <label for="inputName">Name</label>
                        <input type="text" name="inputName" id="inputName" placeholder="Enter a name (required)"
                            value="#{@layer.name}" data-mini="true">
                        <label for="inputDesc">Description</label>
                        <textarea cols="25" rows="3" name="inputDesc" id="inputDesc" placeholder="Add a description" data-mini="true">
                            #{@layer.description}
                        </textarea>
                        #{purposeHTML}
                        #{measureHTML}
                    </div>
                """
                buttons:
                    confirm:
                        title: "Save"
                        handler: onSave
                    cancel:
                        title: "Cancel"
                        handler: @cancelHandler

            @popup.popup().on "input", "input[Name=inputName]", (e) => @setSaveButtonState()
            @setSaveButtonState()


        setSaveButtonState: () ->
            emptyName = $("input[Name=inputName]").val() == ""
            @popup.popup().find(".pop-confirm-btn").toggleClass("ui-state-disabled", emptyName)


