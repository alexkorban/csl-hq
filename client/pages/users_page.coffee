class UsersPage extends pages.BasePage
    @pageId "usersPage"

    HEADER_BUTTON: {back: true}
    TITLE: ->
        store.getState().project.name + " users"


    constructor: ->
        Tracer.log "In usersPage constructor"
        super

        @$(".usersPageContent")
        .on "click", ".permitBtnMobile", (e) =>
            e.preventDefault()
            e.stopPropagation()

            $(e.target).toggleClass("approved")
            @updatePermission e, if $(e.target).hasClass "approved" then "create" else "delete"


        .on "click", ".permitBtnStandHours", (e) =>
            e.preventDefault()
            e.stopPropagation()

            $(e.target).toggleClass("checked")
            $(e.target).siblings().toggleClass("checked")
            @updatePermission e, if $(e.target).hasClass "checked" then "delete" else "create"

        .on "click", ".permitBtnExtHours", (e) =>
            e.preventDefault()
            e.stopPropagation()

            $(e.target).toggleClass("checked")
            $(e.target).siblings().toggleClass("checked")
            @updatePermission e, if $(e.target).hasClass "checked" then "create" else "delete"


    updatePermission: (e, action) =>
        idData = $(e.target).attr("href").match /(\d+)-(\w+)/
        projectId = store.getState().project.id
        Uplink.post "users/#{projectId}/#{idData[1]}/permissions/#{action}", { permission: idData[2] }
        #.then =>
            #@updateMobileUsers store.getState().users

    updateNotificationStatus: (e, action) =>
        idData = $(e.target).attr("href").match /(\d+)/
        notificationId = idData[1]
        projectId = store.getState().project.id
        Uplink.post "projects/#{projectId}/notifications/#{notificationId}/#{action}"


    onChange: (usersPageState) =>
        mainOffice = @officeHtml usersPageState.hqUsers
        $("#usersPageOfficeTab .officeList").html(mainOffice).enhanceWithin()


    onPageBeforeShow: =>
        super

        @stopObservingUsersPage = observeStore (-> store.getState().usersPage), @onChange


    onPageShow: =>
        projectId = store.getState().project.id
        users = store.getState().users
        hqUsers = store.getState().usersPage.hqUsers
        Uplink.get "projects/#{projectId}/notifications"
        .then (notifications) =>
            @render users, hqUsers, notifications


    onPageHide: =>
        @stopObservingUsersPage()


    mobileHtml: (users) =>
        onOff = (statusOn) ->
            return if !statusOn?
            if statusOn
                "on"
            else
                "off"

        details = (config) ->
            if config?
                """
                <div data-role="collapsible" data-mini="true" data-inset="false" data-iconpos="right"
                    data-collapsed-icon="carat-d" data-expanded-icon="carat-u">
                    <h4>App version: #{config.version}</h4>
                    Location services status: #{(onOff config.gpsOn) ? "N/A"}<br/>
                    Position frequency: #{config.positionFreq ? "N/A"}<br/>
                    Position frequency/AC: #{(onOff config.positionFreqACEnabled) ? "N/A"}<br/>
                    Bluetooth status: #{(onOff config.bluetoothOn) ? "N/A"}<br/>
                    Bluetooth scan frequency: #{config.beaconScanFreq ? "N/A"}<br/>
                    Push notifications: #{if config.hasPushId then "Registered" else "Not registered"}<br/>
                    OS: #{config.os ? "N/A"}
                </div>
                """
            else
                "N/A"

        template = (user) ->
            overlaysApproved = if R.contains "view_overlays", user.permissions then "approved" else ""
            droneApproved = if R.contains "view_drone_imagery", user.permissions then "approved" else ""
            beaconsApproved = if R.contains "configure_beacons", user.permissions then "approved" else ""
            userAppConfig = store.getState().usersPage.userAppConfigs[user.id]
            """
            <tr>
                <td>#{user.name}</td>
                <td>#{user.role}</td>
                <td>#{user.company}</td>
                <td>#{user.lastPositionAt}</td>
                <td><a data-role="button" href="##{user.id}-viewOverlays" class="permitBtnMobile #{overlaysApproved}">View overlays</a></td>
                <td><a data-role="button" href="##{user.id}-viewDroneImagery" class="permitBtnMobile #{droneApproved}">View drone imagery</a></td>
                <td><a data-role="button" href="##{user.id}-configureBeacons" class="permitBtnMobile #{beaconsApproved}">Configure beacons</a></td>
                <td>#{details userAppConfig}</td>
            </tr>
            """
        mobileList = R.map(template, users).join "\n"

        """
        <table data-role="table" class="ui-table ui-responsive table-stripe">
            <thead>
                <tr>
                    <th>Person</th>
                    <th>Role</th>
                    <th>Company</th>
                    <th>Last reported at</th>
                    <th>Overlays permission</th>
                    <th>Drone imagery permission</th>
                    <th>Configure beacons permission</th>
                    <th>App configuration</th>
                </tr>
             </thead>
            <tbody>
                #{mobileList}
            </tbody>
        </table>
        <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
        """


    trucksHtml: (users) =>
        template = (user) =>
            if R.contains "extended_hours", user.permissions
                extendedHours = "checked"
                standardHours = ""
            else
                extendedHours = ""
                standardHours = "checked"

            """
            <li>
                #{user.name}
                <div class="permitBtnTrucks">
                    <a data-role="button" href="##{user.id}-extendedHours" class="permitBtnStandHours #{standardHours}">Standard hours</a>
                    <a data-role="button" href="##{user.id}-extendedHours" class="permitBtnExtHours #{extendedHours}">Advanced hours</a>
                </div>
            </li>
            """

        createList = (template, role) ->
            items = R.filter R.propEq("role", role), users
            R.map(template, items).join "\n"

        """
        <ul data-role="listview" data-divider-theme="a">
            <li data-role="list-divider">Trucks</li>
            #{createList template, "Truck"}
            <li data-role="list-divider">Concrete trucks</li>
            #{createList template, "Concrete truck"}
        </ul>
        <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
        """


    officeHtml: (users) =>
        processReports = (reports) ->
            permittedReports = R.pipe(R.filter((report) -> report == "true"), R.keys, R.map((name) -> name[0].toUpperCase() + name.slice 1)) reports
            switch permittedReports.length
                when R.keys(reports).length then "All"
                when 0 then "None"
                else permittedReports.sort().join ", "

        processProjects = (projects) ->
            if R.isArrayLike projects
                projects = R.map (project) ->
                    project[0].toUpperCase() + project.slice 1
                , projects
                projects.join ", "
            else projects

        template = (user) =>
            """
            <li>
                #{user.email}<br><br>
                Projects: #{if user.projects then processProjects user.projects else ""}
                &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                Reports: #{if user.reports then processReports user.reports else ""}
            </li>
            """

        officeList = R.map(template, users).join "\n"

        """
        <ul data-role="listview" data-divider-theme="a">
            #{officeList}
        </ul>
        <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
        """


    itemsListHtml: (type, items, notification) =>
        itemsList = (R.map (item) ->
            notificationItems = if type == "role" || type == "type" then [notification[type]] else notification[type]
            checked = if R.contains(type, ["users", "recipients", "role"]) && R.contains(item.id, notificationItems) then "checked" else ""
            typeClass = if R.contains(type, ["type", "area"]) then "control" else "list"
            """
            <li class="notificationChecklistItem #{checked} #{typeClass}" id="#{notification.id}-#{type}-#{item.id}">
                #{item.name}
            </li>
            """
        , items).join "\n"

        header = if type == "type" || type == "area" then 200 else 150

        """
        <ul data-role="listview" data-filter="true" style="overflow-y: scroll; height: calc(400px - #{header}px")">
            #{itemsList}
        </ul>
        """


    notificationControl: (controlName, items, notification) ->
        checkedItem = notification[controlName]
        """
        <div class="notificationControl-#{controlName}-#{notification.id} notificationControl">
            <div class="controlLabel">#{controlName.charAt(0).toUpperCase() + controlName.slice(1)}</div>
            <a href = "#notification-#{controlName}-popup-#{notification.id}" id = "#{notification.id}-#{controlName}"
                class = "ui-btn ui-corner-all ui-shadow ui-btn-icon-right ui-icon-arrow-d" style="width:200px"
                data-rel = "popup" data-inline = "true" data-transition = "flip">#{checkedItem}</a>

            <div data-role = "popup" id = "notification-#{controlName}-popup-#{notification.id}" data-arrow = "t">
                <div style = "padding: 10px; ">
                    #{@itemsListHtml(controlName, items, notification)}
                </div>
            </div>
        </div>
        """


    observeesListHtml: (observeesType, observees, notification) =>
        observeesLabel = if observeesType == "role" then "Roles" else "Names"
        """
        <div class="controlLabel">#{observeesLabel}</div>
        #{@itemsListHtml observeesType, observees, notification}
        """


    notificationDetails: ({notification, areas, roles, recipients}) =>
        users = store.getState().users
        addEmailHtml = (id) ->
            """
            <div style="display:inline-block">
                <input type="text" name="newRecipient" value = "">
                <a href="##{id}-add-recipient" class="addNewRecipientBtn ui-shadow ui-btn ui-corner-all ui-btn-inline"
                    style="display:inline-block">Add</a>
            </div>
            """

        notificationTypes = [{id: "entry", name: "Notify on entry"}, {id: "exit", name: "Notify on exit"}]
        areasTransformed = R.map ((area) -> { id: area.id, name: area.properties.name}), areas

        [observeesType, observees, roleBtnChecked, usersBtnChecked] =
            if notification.role?
                ["role", roles, "checked", ""]
            else
                ["users", users, "", "checked"]

        """
        <td colspan="10" style="background: none">
            <div class="notificationDetails">
                <div class="detailsItem">
                   #{@notificationControl("type", notificationTypes, notification)}
                   #{@notificationControl("area", areasTransformed, notification)}
                </div>
                <div class="detailsItem">
                    <div style="display: inline; margin-right: 10px;">Observe by</div>
                    <div data-role="controlgroup" data-type="horizontal" style="display: inline">
                        <a href="#role-#{notification.id}" class="ui-btn ui-corner-all observeesBtn #{roleBtnChecked}">Role</a>
                        <a href="#users-#{notification.id}" class="ui-btn ui-corner-all observeesBtn #{usersBtnChecked}">Users</a>
                    </div>
                    <div class="notificationItemsList" id="notificationObserveesList-#{notification.id}">
                        #{@observeesListHtml observeesType, observees, notification}
                    </div>
                </div>
                <div class="detailsItem">
                    <div class="notificationControl">#{addEmailHtml(notification.id)}</div>
                    <div class="controlLabel">Recipients</div>
                    <div class="notificationItemsList" id="notificationRecipientsList-#{notification.id}">#{@itemsListHtml("recipients", recipients, notification)}</div>
                </div>
            </div>
        </td>
        """

    showNotificationDetails: (notificationId) =>
        projectId = store.getState().project.id
        Promise.props
            notification: Uplink.get "projects/#{projectId}/notifications/get/#{notificationId}"
            areas: Uplink.get "projects/#{projectId}/data/areas"
            roles: Uplink.get "projects/#{projectId}/users/roles", {getAll: true}
            recipients: Uplink.get "projects/#{projectId}/notifications/recipients"
        .then (data) =>
            $.mobile.loading "hide"
            notificationDetailsHtml = @notificationDetails data
            @$("#notificationDetails-#{data.notification.id}").html(notificationDetailsHtml).enhanceWithin()
            @setupNotificationDetailsHandlers()



    rowTemplate: (notification) =>
        notificationStatusBtn = if notification.isActive then "Stop" else "Start"
        status = if notification.isActive then "active" else ""
        notificationType = if notification.type == "entry" then "Notify on entry" else "Notify on exit"

        """
        <tr id="notification-#{notification.id}">
            <td id = "#{notification.id}-area-main" style="width: 25%">#{notification.area}</td>
            <td id = "#{notification.id}-type-main">#{notificationType}</td>
            <td><a data-role="button" href="##{notification.id}" class="notificationStatusBtn #{status}"
                id="notificationStatusBtn-#{notification.id}">
                #{notificationStatusBtn}</a></td>
            <td><a data-role="button" href="##{notification.id}" class="notificationDeleteBtn">Delete</a></td>
            <td><span id = "details-#{notification.id}" class="notificationDetailsArrow ui-icon-carat-d ui-btn-icon-left" style="position: relative;"/><td>
        <tr>
        <tr id="notificationDetails-#{notification.id}" class="notificationDetails">
        </tr>
        """

        
    notificationsHtml: (notifications) =>
        rowTemplate = @rowTemplate

        notificationsList = (notifications) ->
            (R.map (notification) ->
                rowTemplate notification
            , notifications).join "\n"

        """
        <div class="notificationsBody">
            <table data-role="table" class="ui-table ui-responsive table-stripe">
                <thead>
                    <tr>
                        <th>Area</th>
                        <th>Type</th>
                        <th>Status</th>
                        <th></th><th></th><th></th>
                    </tr>
                 </thead>
                <tbody>
                    #{notificationsList notifications}
                </tbody>
            </table>
            <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
        </div>
        """


    render: (users, hqUsers, notifications) =>
        mainMobile = @mobileHtml users
        mainOffice = @officeHtml hqUsers
        mainNotifications = @notificationsHtml notifications
        mainTrucks = @trucksHtml users

        main =  """
            <div data-role = "tabs" class="usersPageContent">
                <div data-role = "navbar">
                    <ul>
                        <li><a href="#usersPageMobileTab" data-theme="a" data-ajax="false" class="ui-btn-active tab-button">Mobile users</a></li>
                        <li><a href="#usersPageOfficeTab" data-theme="a" data-ajax="false" class="tab-button">Office users</a></li>
                        <li><a href="#usersPageTrucksTab" data-theme="a" data-ajax="false" class="tab-button">Trucks</a></li>
                        <li><a href="#usersPageNotificationsTab" data-theme="a" data-ajax="false" class="tab-button">Notifications</a></li>
                    </ul>
                </div>
                <div id = "usersPageMobileTab" class="ui-content" role="main">
                    <div class="mobileList" >
                        #{mainMobile}
                    </div>
                </div>
                <div id = "usersPageOfficeTab" class="ui-content" role="main">
                    <div class="usersPageUserForm ui-body ui-body-a ui-corner-all">
                        <div class="ui-grid-b">
                            <div class="ui-block-a"><div class="ui-field-contain"
                                ><label for="user-hq-email">Login:</label
                                ><input type="email" name="user-hq-email" id="user-hq-email" placeholder="Email">
                            </div></div>
                            <div class="ui-block-b"><div class="ui-field-contain"
                                ><label for="user-hq-pass">Password:</label
                                ><input type="text" name="user-hq-pass" id="user-hq-pass" placeholder="Password">
                            </div></div>
                            <div class="ui-block-c">
                                <button class="user-hq-create ui-shadow ui-btn ui-corner-all ui-mini">Create</button>
                            </div>
                        </div>
                    </div>
                    <div class="officeList">
                        #{mainOffice}
                    </div>
                </div>
                <div id = "usersPageTrucksTab" class="ui-content" role="main">
                    <div class="trucksList" >
                        #{mainTrucks}
                    </div>
                </div>
                <div id = "usersPageNotificationsTab" class="ui-content" role="main">
                     <a data-role="button" href="#" class="newNotificationBtn">Create a new notification</a>
                    #{mainNotifications}
                </div>
            </div>
        """
        @$(".usersPageContent").html(main).enhanceWithin()

        @setupNotificationsHandlers()

        @$(".user-hq-create").on "click", () =>
            email = @$("#user-hq-email").val().toLowerCase()
            pass = @$("#user-hq-pass").val()

            # Very basic validation
            if !isEmail email
                controls.DynamicAlert "Please enter a valid email address."
                return
            if pass.length < 4
                controls.DynamicAlert "Please use a password that's longer than 3 characters."
                return

            user =
                email: email
                password: pass

            $.mobile.loading "show",
                text: "Creating the user..."
                textVisible: true

            Uplink.post "users-hq/#{store.getState().project.id}/create", user
            .then (res) =>
                controls.DynamicAlert res.msg
                @$("#user-hq-email").val ""
                @$("#user-hq-pass").val ""
                watchers.update app.WATCHERS.hqUsers
                $.mobile.loading "hide"
            .catch () =>
                $.mobile.loading "hide"
                controls.DynamicAlert "Failed to create new user."

        @$(".newNotificationBtn").on "click", (e) =>
            projectId = store.getState().project.id
            Uplink.post "projects/#{projectId}/notifications/create"
            .then (notifications) =>
                notificationsHtml = @notificationsHtml notifications
                newNotificationId = R.head(notifications).id
                $(".notificationsBody").html(notificationsHtml).enhanceWithin()
                @setupNotificationsHandlers()
                $(".notificationDetailsArrow").removeClass("active ui-icon-carat-u").addClass("ui-icon-carat-d")
                $(".notificationDetails").html("")
                $("#details-#{newNotificationId}").addClass("ui-icon-carat-u active")
                @showNotificationDetails newNotificationId


    getNotificationIdFromHref: (e) =>
        idData = $(e.target).attr("href").match /(\d+)/
        idData[1]


    setupNotificationsHandlers: =>
        projectId = store.getState().project.id

        @$(".notificationStatusBtn").on "click", (e) =>
            e.stopPropagation()
            notificationId = @getNotificationIdFromHref e
            $(e.target).toggleClass("active")
            $(e.target).html(if $(e.target).hasClass "active" then "Stop" else "Start")
            action = if $(e.target).hasClass "active" then "start" else "stop"
            Uplink.post "projects/#{projectId}/notifications/#{notificationId}/status/#{action}"

        @$(".notificationDeleteBtn").on "click", (e) =>
            e.stopPropagation()
            if confirm("Are you sure you would like to delete this notification?")
                notificationId = @getNotificationIdFromHref e
                $("#notification-#{notificationId}").html("")
                $("#notificationDetails-#{notificationId}").html("")
                Uplink.post "projects/#{projectId}/notifications/#{notificationId}/delete"
            else
        #do nothing

        @$(".notificationDetailsArrow").on "click", (e) =>
            input = R.split "-", $(e.target.id).selector
            notificationId = input[1]
            if $(e.target).hasClass("active")
                $(".notificationDetailsArrow").removeClass("active ui-icon-carat-u").addClass("ui-icon-carat-d")
                $("#notificationDetails-#{notificationId}").html("")
            else
                $.mobile.loading "show"
                $(".notificationDetailsArrow").removeClass("active ui-icon-carat-u").addClass("ui-icon-carat-d")
                $(".notificationDetails").html("")
                $(e.target).addClass("active ui-icon-carat-u")
                @showNotificationDetails notificationId


    setupNotificationDetailsHandlers: =>
        projectId = store.getState().project.id
        itemsListHtml = @itemsListHtml
        observeesListHtml = @observeesListHtml

        setupListItemsHandler = (selector) ->
            @$("#{selector} .notificationChecklistItem.list").on "click", (e) =>
                e.stopPropagation()
                input = R.split "-", $(e.target.id).selector
                [notificationId, listName, itemId] = [input[0], input[1], input[2]]
                action =
                    if listName == "role"
                        "replace"
                    else
                        if $(e.target).hasClass("checked")
                            "remove"
                        else "append"
                $(e.target).siblings().removeClass("checked") if listName == "role"
                $(e.target).toggleClass("checked")
                stopNotification notificationId

                Uplink.post "projects/#{projectId}/notifications/#{notificationId}/update", {action: action, type: listName, itemId: itemId}

        stopNotification = (notificationId) ->
            if @$("#notificationStatusBtn-#{notificationId}").hasClass("active")
                @$("#notificationStatusBtn-#{notificationId}").toggleClass("active").html("Start")
                Uplink.post "projects/#{projectId}/notifications/#{notificationId}/status/stop"
            else
                #do nothing

        @$(".addNewRecipientBtn").on "click", (e) =>
            e.stopPropagation()
            email = $(e.target).prev().find("input").val()
            notificationId = @getNotificationIdFromHref e
            Uplink.post "projects/#{projectId}/notifications/recipients/create", {email: email, notificationId: notificationId}
            .then (result) ->
                if !R.isEmpty result
                    recipientsHtml = itemsListHtml "recipients", result.recipients, result.notification
                    @$("#notificationRecipientsList-#{notificationId}").html(recipientsHtml).enhanceWithin()
                    $(e.target).prev().find("input").val("")
                    setupListItemsHandler "#notificationRecipientsList-#{notificationId}"
                else
                    #do nothing

        @$(".notificationChecklistItem.control").on "click", (e) =>
            e.stopPropagation()
            input = R.split "-", $(e.target.id).selector
            [notificationId, controlName, itemId] = input
            $("##{notificationId}-#{controlName}").text $(e.target).text()
            $("##{notificationId}-#{controlName}-main").text $(e.target).text()
            stopNotification notificationId
            $("#notification-#{controlName}-popup-#{notificationId}").popup("close")
            Uplink.post "projects/#{projectId}/notifications/#{notificationId}/update", {action: "replace", type: controlName, itemId: itemId}

        @$(".observeesBtn").on "click", (e) =>
            e.stopPropagation()
            idData = $(e.target).attr("href").match /(role|users)-(\d+)/
            observeesType = idData[1]
            notificationId = idData[2]
            $(e.target).addClass("checked")
            $(e.target).siblings().removeClass("checked")

            Uplink.post "projects/#{projectId}/notifications/#{notificationId}/role/update", {observeesType: observeesType }
            .then (result) ->
                observees = if observeesType == "role" then result.roles else store.getState().users
                observeesList = observeesListHtml observeesType, observees, result.notification
                $("#notificationObserveesList-#{notificationId}").html(observeesList).enhanceWithin()
                setupListItemsHandler "#notificationObserveesList-#{notificationId}"

        setupListItemsHandler ".notificationItemsList"

    updateMobileUsers: (users) =>
        mainMobile = @mobileHtml users
        $("#usersPageMobileTab .mobileList").html(mainMobile).enhanceWithin()

        mainTrucks = @trucksHtml users
        $("#usersPageTrucksTab .trucksList").html(mainTrucks).enhanceWithin()


module.exports = UsersPage
