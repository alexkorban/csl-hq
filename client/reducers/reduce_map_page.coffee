module.exports =     
    reduceFilters: (state, action) ->
        switch action.type
            when "mapPage.filters.toggleUsers"
                users = if state.users == "all"
                    R.pluck "id", store.getState().users
                else
                    state.users

                if R.contains action.userId, users
                    R.merge state,
                        users: R.reject(R.equals(action.userId), users)
                        selectedMarker: if toString(action.userId) == state.selectedMarker.id then {} else state.selectedMarker
                else
                    R.merge state, users: R.append(action.userId, state.users)
            when "mapPage.filters.selectUsers"
                R.merge state, users: R.clone action.userIds
            when "mapPage.filters.selectAllUsers"
                R.merge state, users: "all"
            when "mapPage.filters.clearAllUsers"
                R.merge state,
                    users: []
                    selectedMarker: {}
            when "mapPage.filters.selectMarker"
                R.merge state, selectedMarker: R.clone action.selectedMarker
            else
                state


    reduceUi: (state, action) ->
        switch action.type
            when "mapPage.ui.toggleTracking"
                R.merge state,
                    trackUsers: !state.trackUsers
            when "mapPage.ui.showPopup"
                R.merge state, showMarkerPopup: action.showMarkerPopup
            else
                state
