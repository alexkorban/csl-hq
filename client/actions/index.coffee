actions =
    global: require "./actions_global"
    mapPage: require "./actions_map_page"
    pavingPage: require "./actions_paving_page"
    timelinePage: require "./actions_timeline_page"
    usersPage: require "./actions_users_page"


duplicates = actionTypesChecker actions

if !R.isEmpty duplicates then alert "Check your actions types for uniqueness\n" + (R.keys duplicates).join("\n")
if !R.isEmpty duplicates then console.log "CHECK YOUR ACTIONS TYPES FOR UNIQUENESS",  R.keys duplicates


module.exports = actions



