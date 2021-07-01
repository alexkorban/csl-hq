window.$ = window.jQuery = require("jquery")
window.R = require "ramda"
global.Promise = require "bluebird"
window.inflector = require "inflection"
window.createStore = require("redux").createStore
window.flyd = require "flyd"
window.moment = require "moment-timezone"
window.turf = require "turf"
window.json2csv = require "json2csv"

window.L_PREFER_CANVAS = true  # Leaflet should use canvas for overlays if possible

require "mapbox.js"
require "leaflet-awesome-markers/dist/leaflet.awesome-markers"
require "leaflet.markercluster"
require "leaflet-draw"
require "date-utils"
require "moment-range"
require "./lib"
require "./pages"
require "./models"
window.Action = require "./actions"

window.TIME_FORMAT = "DD/MM/YY HH:mm:ss" # Main time format as on the server


Promise.longStackTraces()

window.exceptionator.initialise (e, stack, args) ->
    console.error "Caught an exception (from #{e?.source}): \"#{e?.message}\""
    console.error e
    if args?
        console.error "Args that triggered the exception:", args
    console.error stack
    alert "Error: #{e?.message}\n\n#{stack}"

    #TODO: post to Raygun or something





#HACK: fixes leaflet 0.7.7 bug with layer removal handling
L.Path.prototype.onRemove = (map) ->
    map.off('viewreset', @projectLatlngs, this).off 'moveend', @_updatePath, this
    if @options.clickable
        @_map.off 'click dblclick contextmenu', @_fireMouseEvent, this
        @_map.off 'mousemove', @_onMouseMove, this
    @_requestUpdate()
    @fire 'remove'
    @_map = null

L.mapbox.accessToken = "pk.eyJ1IjoiYW90ZWFzdHVkaW9zIiwiYSI6IjA0ODNkMzUwNjU4YjY1OWI0OGQ1YzhlYTZlODIzYzUwIn0.FJHPzX4P0NONeNVgbIWJiQ"

L.mapbox.TileLayer.prototype.scalePrefix = "."  # hack to force Mapbox not to use Retina tiles
                                                # which they made non-optional for some reason

class App

    constructor: ->
        # The current strategy is to cache all page objects when they are loaded. This works while
        # the number of pages is low. Note that there are two different caching mechanisms: the
        # jQM mechanism which caches the DOM elements of a page, and our own app mechanism which
        # caches page *objects* associated with jQM DOM pages. Currently, jQM caching isn't used
        # as all DOM pages are defined in index.ejs rather than loaded via AJAX. This may need to
        # be revisited as the number of pages grows, or if we start explicitly supporting mobile
        # devices.

        # A related issue is event handlers. Currently event handlers are never removed. If we
        # start removing page objects, then event handlers will need to be removed. Consider
        # using jQuery namespaces for that. Something like $("<pageId>").off(".<pageNamespaceName>")
        # should remove all the event handlers in the page namespace.

        @cachedPages = {}

        @WATCHERS =
            assets:
                name: "Assets"
                period: 10 * 60 * 1000
                url: "projects/$projectId/data/assets"
                action: Action.global.updateAssets
            hqUsers:
                name: "HQ users"
                period: 10 * 60 * 1000
                url: "users-hq/$projectId/users"
                action: Action.usersPage.updateHQUsers
                predicate: -> store.getState().permissions.hr
            pavingUsers:
                name: "Paving users"
                period: 2 * 60 * 1000
                url: "projects/$projectId/users/paving"
                action: Action.global.updatePavingUsers
                params: sort: "role"
                predicate: -> store.getState().permissions.paving
            positions:
                name: "Positions"
                period: 10 * 1000
                url: "projects/$projectId/users/positions"
                action: Action.global.updatePositions
            users:
                name: "Users"
                period: 10 * 1000
                url: "projects/$projectId/users"
                action: Action.global.updateUsers
                params: sort: "role"
            userAppConfigs:
                name: "User app configs"
                period: 30 * 60 * 1000
                url: "projects/$projectId/users/app-configs"
                action: Action.usersPage.updateUserAppConfigs
                predicate: -> store.getState().permissions.hr
            vehicles:
                name: "Vehicles"
                period: 10 * 1000
                url: "projects/$projectId/vehicles/positions"
                action: Action.global.updateVehicles
            weather:
                name: "Weather"
                period: 5 * 60 * 1000
                url: "weather/$projectId"
                action: Action.global.updateWeather


        $(document).on "pagecreate", @onPageCreate
        $(document).on "pagebeforeshow", @onPageBeforeShow
        $(document).on "pageshow", @onPageShow
        $(document).on "pagebeforechange", @onPageBeforeChange
        $(document).on "pagecontainerhide", @onPageHide

        $(document).on "click", ".logoutButton", (e) =>
            @logout()


        $("#menuPanel").panel()

        @loadInitialPage()

        Tracer.log "Project ID: ", store.getState().project.id

        destroyWatchers = () ->
            Tracer.log "Destroying watchers"
            R.forEach (intervalId) ->
                clearInterval intervalId
            , R.values store.getState().watchers
            store.dispatch Action.global.destroyWatchers()

        createWatchers = (WATCHERS) ->
            Tracer.log "Creating watchers"
            R.mapObjIndexed (watcher, key, obj) ->
                if !watcher.predicate? || watcher.predicate()
                    intervalId = watchers.create watcher
                    store.dispatch Action.global.updateWatchers ("#{key}": intervalId)
                else
                    # Don't create if the watcher's condition isn't fulfilled
            , WATCHERS

        observeStore (->  R.pick ["project", "isLoggedIn"], store.getState()), (state) =>
            if state.project.id? and state.isLoggedIn
                destroyWatchers()
                createWatchers @WATCHERS
            else
                destroyWatchers()


    onPageCreate: (e) =>
        pageClassName = inflector.classify(e.target.id)

        if window.pages[pageClassName]?
            @cachedPages[e.target.id] ?= new window.pages[pageClassName]
        else
            Tracer.log "Unknown view class #{pageClassName}"
        true


    onPageBeforeShow: (e) =>
        @prevPage = @page
        @page = @cachedPages[e.target.id]
        @page.onPageBeforeShow?()


    onPageShow: (e) =>
        @page.onPageShow?()


    onPageBeforeChange: (e, data) =>
        if typeof data.toPage is "string"
            @page?.onPageBeforeChange?(e)


    onPageHide: (e, ui) =>
        @prevPage?.onPageHide?()


    logout: =>
        Uplink.post("users-hq/logout", {}).then =>
            store.dispatch Action.global.logout()
            location.reload()

        
    loadInitialPage: =>
        page = if store.getState().isLoggedIn
            if store.getState().project.id? then "mapPage" else "selectProjectPage"
        else "loginPage"

        window.location.hash = "#" + page
        $.mobile.initializePage()

        $("body").pagecontainer "change", "#" + page

    #    ($.mobile.loadPage page, pageContainer: $ "body")
    #    .then =>
    #      $.mobile.initializePage()
    #      $.mobile.changePage page
    #    .fail =>
    #      console.error "Could not load initial page"


# Kick off the action when jQuery Mobile is ready
($ document).on "mobileinit", (e) ->
    $.mobile.pushStateEnabled = false     # don't replace hash fragments with page names
    $.mobile.hashListeningEnabled = false # don't listen for hash changes, only act when user presses on links
    $.mobile.autoInitializePage = false   # the page needs to be selected based on stored params, so don't load default

    ($ document).ready (e) =>
        Tracer.log "DOM ready"
        $.ajaxSetup cache: true # don't append timestamp param to AJAX requests
                                # because that interferes with the offline cache

        window.app = new App

