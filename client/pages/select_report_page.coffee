module.exports = class SelectReportPage extends pages.BasePage
    @pageId "selectReportPage"

    constructor: ->
        super
        @$(".reportList").click (e) =>
            store.dispatch Action.global.setLastSelectedReport
                url: $(e.target).closest("a")[0].hash.slice(1)
                label: $(e.target).closest("a").text()
            $("body").pagecontainer "change", "#reportPage"


    onPageShow: =>
        @renderLogo()

        $.mobile.loading "show"

        Uplink.get "reports/#{store.getState().project.id}"
        .then (reports) =>
            reportListHtml = R.map ((report) => """
                    <li><a class="reportButton" href="##{report.url}">#{report.label}</a></li>
                """)
                , reports

            @$(".reportList").html(reportListHtml).listview "refresh"
        .finally =>
            $.mobile.loading "hide"


    renderLogo: =>
        customerLogo = store.getState().customerLogo
        $(".customerLogo").html(customerLogo).enhanceWithin()
