# Browserify isn't able to process expressions in require() calls,
# so the following doesn't work; it could work under Webpack.
#pages = ["base_page", "login_page", "select_project_page",
#         "select_report_page", "report_page", "map_page",
#         "settings_page", "timeline_page", "paving_page"]
#
#window.pages = R.fromPairs R.map ((fileName) =>
#    [inflector.camelize(fileName), require("./#{fileName}")]), pages

window.pages =
    BasePage: require "./base_page"

window.pages = R.merge window.pages,
    LoginPage: require "./login_page"
    SelectProjectPage: require "./select_project_page"
    SelectReportPage: require "./select_report_page"
    ReportPage: require "./report_page"
    MapPage: require "./map_page"
    SettingsPage: require "./settings_page"
    TimelinePage: require "./timeline_page"
    PavingPage: require "./paving_page"
    UsersPage: require "./users_page"
