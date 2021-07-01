module.exports = (state, action) ->
    switch action.type
        when "usersPage.updateHQUsers" then R.merge state, hqUsers: R.clone action.hqUsers
        when "usersPage.updateUserAppConfigs" then R.merge state, userAppConfigs: R.clone action.userAppConfigs
        else state
