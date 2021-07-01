# User List Control
#
# Parameters:
#   @container - an element to render User List in
#   @page - name of the page the list lives on, used to defineattache to pro
#   @actions - set of actions to add to each user in the list. Omit if no action
#              required.
#              Each action must have following fields defined:
#                 - name - some descriptive name, will be on the button
#                 - handler - a function to handle the action taking userId as
#                   parameter
#   @sorting - an optional custom sorting configuration. Parameters are:
#                 - name - a label to display on a toggle (styling is not perfect, works for short names only for now)
#                 - order - sorting direction. Ascending by default, provide "desc" to reverse
#                 - by - a function to get a value to sort by from the user object, e.g.: R.prop("name")

module.exports =
    UsersList: class
        constructor: (options) ->
            {@container, @page, @actions, @sorting, @getUsers, @extraDetails} = options

            if @actions && @actions.length > 0
                @container.on "click", ".filterUserItemActions .ui-btn", (e) =>
                    userId = userId = parseInt $(e.target).closest(".filterUserItem").attr "data-user-id"

                    if @actions.length > 1
                        buttons = R.map ((a) => """<li data-icon="false" name="#{a.name}"><a href="">#{a.name}</a></li>"""), @actions

                        pop = $("""
                            <div data-role="popup" class="filterUserItemPopup">
                                <ul data-role="listview" class="ui-mini">#{buttons.join ""}</ul>
                            </div>
                        """)

                        listItem = $(e.target).closest(".filterUserItem")
                        offset = listItem.offset()
                        pop.appendTo $.mobile.activePage
                        .popup()
                        .enhanceWithin()
                        .popup "open",
                            x: offset.left + listItem.outerWidth(true) + pop.width() / 2
                            y: offset.top + listItem.outerHeight(true) / 2
                            transition: "turn"

                        pop.find("li").one "click", (e) =>
                            actionName = e.currentTarget.attributes.name.value
                            handler = R.find(R.propEq("name", actionName))(@actions).handler
                            handler(userId)
                            pop.popup("close")

                        $(document).one "popupafterclose", ".ui-popup", ->
                            $(this).remove()
                    else
                        actionName = e.currentTarget.name
                        handler = R.find(R.propEq("name", actionName))(@actions).handler
                        handler(userId)

                    $(e.currentTarget).css("box-shadow","none")
                    e.preventDefault()
                    e.stopPropagation()


            @container.on "click", ".filterUserItem", (e) =>
                userId = parseInt $(e.target).closest(".filterUserItem").attr "data-user-id"
                store.dispatch Action[@page].filters.toggleUser(userId)

            @container.on "click", ".ui-li-divider", (e) =>
                role = e.target.innerText
                roleUserIds = R.pluck("id", R.filter(R.propEq("role", role), @getUsers()))
                selectedUserIds = store.getState()[@page].filters.users
                selectedUserIds = R.pluck("id", @getUsers()) if selectedUserIds == "all"
                isWholeRoleSelected = R.all(R.contains(R.__, selectedUserIds)) roleUserIds
                newSelection = if isWholeRoleSelected
                    R.difference selectedUserIds, roleUserIds
                else
                    R.union selectedUserIds, roleUserIds
                store.dispatch Action[@page].filters.selectUsers newSelection

            @container.on "click", ".selectAllUsers", (e) =>
                store.dispatch Action[@page].filters.selectAllUsers()

            @container.on "click", ".selectNoUsers", (e) =>
                store.dispatch Action[@page].filters.clearAllUsers()

            @container.on "click", ".ui-flipswitch:has([name=trackingToggle])", (e) =>
                store.dispatch Action[@page].ui.toggleTracking()

            if @sorting
                @container.on "click", ".ui-flipswitch:has([name=sortingToggle])", (e) =>
                    store.dispatch Action[@page].ui.toggleSorting()

            sortingToggle = if @sorting
                """
                <div class="sortingToggle">
                    <label for="sortingToggle">Sort users by</label>
                    <select name="sortingToggle" id="sortingToggle" data-role="flipswitch" data-mini="true">
                        <option value="off">Role</option>
                        <option value="on">#{@sorting.name}</option>
                    </select>
                </div>
                """
            else ""
                
            controlsHeight = if @page == "pavingPage" then 200 else 165

            htmlContent = """
                    <div class="usersList">
                        <label for="trackingToggle">Track selected users</label>
                        <select name="trackingToggle" id="trackingToggle" data-role="flipswitch" data-mini="true">
                            <option value="off">Off</option>
                            <option value="on">On</option>
                        </select>

                        #{sortingToggle}

                        <div data-role="controlgroup" data-type="horizontal" data-mini="true">
                            <a href="#" class="selectAllUsers ui-btn ui-mini">Select all users</a>
                            <a href="#" class="selectNoUsers ui-btn ui-mini">Clear all users</a>
                        </div>

                        <form class="ui-filterable">
                            <input class="filterUserListFilter#{@page}" placeholder="Find users by name..."  data-type="search">
                        </form>

                        <ul class="filterUserList" data-role="listview" data-autodividers="true"
                             data-filter="true" data-input=".filterUserListFilter#{@page}" style="height: calc(100vh - #{controlsHeight}px);" >
                        </ul>
                    </div>
                """
            @container.html(htmlContent).enhanceWithin()

            @container.find(".ui-btn, .ui-input-search, .ui-controlgroup").removeClass("ui-corner-all")

            @stopObservingUsersTracking = observeStore (=> store.getState()[@page].ui.trackUsers), @onUsersTrackingChange
            @stopObservingCustomSorting = observeStore (=> store.getState()[@page].ui.customSorting), @onCustomSortingChange


        onUsersTrackingChange: (isTracking) =>
            @container.find "#trackingToggle"
            .val(if isTracking then "on" else "off")
            .flipswitch "refresh", true


        onCustomSortingChange: (customSort) =>
            @container.find "#sortingToggle"
            .val(if customSort then "on" else "off")
            .flipswitch "refresh", true


        customSortingEnabled: =>
            @sorting && store.getState()[@page].ui.customSorting


        destroy: =>
            clickables = [".filterUserItem", ".ui-li-divider", ".selectAllUsers", ".selectNoUsers", ".ui-flipswitch:has([name=trackingToggle])"]
            if @sorting
                clickables.push ".ui-flipswitch:has([name=sortingToggle])"
            R.forEach ((elem) => @container.off "click", elem), clickables
            @stopObservingUsersTracking()
            @stopObservingCustomSorting()


        redraw: (selected) =>
            users = @getUsers()
            htmlContent = if users.length > 0
                enrich = R.map (user) =>
                    position = R.find(R.propEq("id", user.id), store.getState().positions)
                    R.merge(user, R.pick(["lastPositionAt", "speed"], position ? {}))

                if @customSortingEnabled()
                    enrich = R.compose(R.sortBy(@sorting.by), enrich)
                    if @sorting.order == "desc"
                        enrich = R.compose(R.reverse, enrich)

                richUsers = enrich users
                
#               Could look more like this, but has problems with scope.
#                mergePositionsIntoUsers = R.map (user) =>
#                    position = R.find(R.propEq("id", user.id), store.getState().positions)
#                    R.merge(user, R.pick(["lastPositionAt", "speed"], position ? {}))
#                sortUsers = if @customSortingEnabled() then R.sortBy(@sorting.by) else R.identity
#                sortUsersDesc = if @sorting.order == "desc" then R.reverse else R.identity
#                richUsers = R.pipe(mergePositionsIntoUsers, sortUsers, sortUsersDesc) users

                speedToText = (speed) =>
                    switch
                        when speed <= 0.10 then "stationary"
                        when speed <= 1.39 then "walking"
                        else "driving"

                dateToText = (dateStr) =>
                    zone = store.getState().project.timezone
                    date = moment(dateStr, TIME_FORMAT)
                    today = moment().tz(zone).clone().startOf("day")
                    yesterday = moment().tz(zone).clone().subtract(1, "days").startOf "day"

                    switch
                        when date.isSame(today, "d") then date.format "HH:mm"
                        when date.isSame(yesterday, "d") then "yesterday #{date.format "HH:mm"}"
                        else date.format "DD/MM/YY HH:mm"

                userItem = (user) =>
                    selectedClass = if selected == "all" || R.contains(user.id, selected) then "selected" else ""

                    lastRepText = if user.lastPositionAt? then "Last reported #{dateToText user.lastPositionAt}" else ""
                    
                    speedText = if user.speed? then speedToText(user.speed) else ""

                    actionsList = if @actions && @actions.length > 0
                        if @actions.length > 1
                            """<a data-rel="popup" class="ui-btn ui-icon-bars ui-btn-icon-notext ui-corner-all"/>"""
                        else
                            """<a name="#{@actions[0].name}" class="ui-btn ui-corner-all ui-mini">#{@actions[0].name}</a>"""
                    else
                        ""

                    extraDetails = if @extraDetails?
                        "<p>#{@extraDetails user}</p>"
                    else
                        ""

                    """
                    <li class="filterUserItem #{selectedClass}" data-icon="false"
                        data-user-id="#{user.id}"
                        data-user-role="#{user.role}">
                        <div class="filterUserItemInfos">
                            <h2>#{user.name}</h2>
                            <p>#{lastRepText}</p>
                            <p>#{speedText}</p>
                            #{extraDetails}
                        </div>
                        <div class="filterUserItemActions">#{actionsList}</div>
                    </li>
                    """
                R.map(userItem, richUsers).join "\n"
            else
                "No active users at the moment"

            @container.find(".filterUserList")
            .html(htmlContent).enhanceWithin()
            .listview
                autodividers: not @customSortingEnabled()
                autodividersSelector: (li) =>
                    li.attr("data-user-role")
            .filterable "refresh"
