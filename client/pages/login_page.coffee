reduxBatched = require "redux-batched-actions"
batch = reduxBatched.batchActions

module.exports = class LoginPage extends pages.BasePage
    @pageId "loginPage"

    TITLE: "Please login"

    constructor: ->
        super

        @$(".loginButton").on "click", (e) =>
            e.stopPropagation()
            e.preventDefault()
            Tracer.log "Login button pressed"

            input = R.mergeAll (R.map (id) ->
                input = (@$ "#" + id).val().trim()
                if input.length == 0
                    alert "Please enter your #{id}."
                    return
                else 
                    "#{id}": input
            , ["email", "password"])

            params = R.merge input, projectId: store.getState().project.id

            Uplink.post("users-hq/login", params).then (result) =>
                store.dispatch batch [
                    Action.global.login()
                    Action.global.setEmail(input.email)
                    Action.global.setSessionId result.sessionId
                    Action.global.setPermissions result.permissions
                    Action.global.setCustomerLogo result.customerLogo
                ]

                $("body").pagecontainer "change", if R.isEmpty store.getState().project then "#selectProjectPage" else "#mapPage"
            .catch (error) =>
                if error.status == 401
                    alert "Your email or password is incorrect, please try again."
                else
                    alert "Couldn't login: #{JSON.stringify error}"


    setupHeader: ->
        super false # do nothing

