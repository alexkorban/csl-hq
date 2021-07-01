reduxBatched = require "redux-batched-actions"
batch = reduxBatched.batchActions

module.exports = class SelectProjectPage extends pages.BasePage
    @pageId "selectProjectPage"
    
    TITLE: "Select project"

    constructor: ->
        super
        @$(".projectList").click (e) =>
            project = $(e.target).closest("li").jqmData("project")

            Uplink.get "users-hq/#{project.id}/permissions"
            .then (permissions) =>
                actions = [ Action.global.setProject(project), Action.global.setPermissions(permissions) ]
                extra =
                    if project.id != store.getState().project.id
                        if project.showUsersPanel
                            [Action.mapPage.filters.selectAllUsers(), Action.pavingPage.filters.selectAllUsers()]
                        else
                            [Action.mapPage.filters.clearAllUsers(), Action.pavingPage.filters.clearAllUsers()]
                    else [] #no change to selected users

                store.dispatch batch R.concat extra, actions

                $("body").pagecontainer "change", "#mapPage"


    onPageShow: =>
        @renderLogo()

        $.mobile.loading "show"

        Uplink.get("projects").then (projects) =>
            @$(".projectList").html ""

            R.forEach ((project) ->
                tpl = "<li><a class = 'projectButton' href = '#'>#{project.name}</a></li>"
                $(tpl).appendTo(".projectList").jqmData("project", project)
                ), projects

            @$(".projectList").listview "refresh"
        .finally =>
            $.mobile.loading "hide"



    setupHeader: ->
        super false # don't add menu


    renderLogo: =>
        customerLogo = store.getState().customerLogo
        $(".customerLogo").html(customerLogo).enhanceWithin()
