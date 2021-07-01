module.exports = class BasePage
    @pageId: (id) ->
        @::id = id


    constructor: ->
        Tracer.log @
        @$el = $ "#" + @id

        #@setupHeader()
        @setTitle()


    $: (selector) ->
        @$el.find selector


    setupHeader: (skip) ->
        if skip != false
            pavingItem = if store.getState().permissions.paving
                """<li data-icon = "eye"><a href="#pavingPage">Paving</a></li>"""
            else
                ""

            usersPage = if store.getState().permissions.hr
                """<li data-icon="user"><a href="#usersPage">Users</a></li>"""
            else
                ""
                
            $("#menuPanel").html """
                <ul data-role = "listview">
                    <li data-role = "list-divider"></li>
                    <li data-icon = "location"><a href="#mapPage">Map</a></li>
                    <li data-icon = "video"><a href="#timelinePage">Timeline</a></li>
                    #{pavingItem}
                    <li data-icon = "clock"><a href="#selectReportPage">Reports</a></li>
                    <li data-icon = "bullets"><a href="#selectProjectPage">Project list</a></li>
                    #{usersPage}
                    <li data-icon = "gear"><a href="#settingsPage">Settings</a></li>
                    <li data-icon = "false"><a class = "logoutButton" href="#loginPage">Logout</a></li>
                    <li data-role = "list-divider"></li>
                </ul>
                <div class="info">Logged in as:<br/>#{store.getState().email}</div>
                <div class="info">Project time zone:<br/>#{store.getState().project.timezone}</div>
            """
            .enhanceWithin().trigger "updatelayout"

            $("#menuPanel a[href=##{@id}]").addClass "ui-state-disabled"

            leftButtonHtml =
                if !@HEADER_BUTTON?
                    ""
                else
                    if @HEADER_BUTTON.back?
                        backButton = 'data-rel="back"'
                        @HEADER_BUTTON.icon = "arrow-l"
                        @HEADER_BUTTON.label = "Back"
                        @HEADER_BUTTON.target = "#"

                    """
                        <a href="#{@HEADER_BUTTON.target}"
                            class = "ui-btn ui-btn-inline ui-btn-left ui-corner-all ui-btn-icon-left ui-icon-#{@HEADER_BUTTON.icon}"
                            data-transition = "fade" #{backButton}>#{@HEADER_BUTTON.label}</a>
                    """

            @$("[data-role=header]").html """
                #{leftButtonHtml}
                <h1 class = "ui-title"></h1>
                <a href="#menuPanel" class = "ui-btn ui-btn-inline ui-btn-right ui-corner-all ui-btn-icon-right ui-icon-bars"
                     data-transition = "fade">Menu</a>
            """
            .enhanceWithin()
            
        document.title = TITLE


    setTitle: ->
        @$("[data-role=header]").find("h1").text switch
            when R.is Function, @TITLE then @TITLE()
            when R.is String, @TITLE then @TITLE
            else store.getState().project.name


    onPageBeforeShow: ->
        @setupHeader()
        @setTitle()

