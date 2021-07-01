module.exports = class SettingsPage extends pages.BasePage
    @pageId "settingsPage"

    HEADER_BUTTON: {back: true}

    constructor: ->
        super

        # vclick doesn't work for radio buttons
        (@$ "input[type=radio]").on "click", (e) =>
            (@$ "input[type=radio]").prop("checked", false).checkboxradio("refresh")
            store.dispatch Action.global.setMapType ($ e.currentTarget).prop("checked", "checked").checkboxradio("refresh").val()

    onPageBeforeShow: =>
        super
        (@$ "input[value=#{store.getState().mapType}]").prop("checked", "checked").checkboxradio("refresh")
        currentYear = moment().format "YYYY"
        @$(".copyrightContent").html("Copyright #{currentYear} Cloudscape Ltd.")
