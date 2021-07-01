module.exports =
    reduceData: (state, action) ->
        switch action.type
            when "pavingPage.data.setTruckInfo" then R.merge state, truckInfo: R.clone action.truckInfo
            when "pavingPage.data.setBatchPlantInfo" then R.merge state, batchPlantInfo: R.clone action.batchPlantInfo
            when "pavingPage.data.setProductionData" then R.merge state, production: R.clone action.productionData
            when "pavingPage.data.setPaverInfo" then R.merge state, paverInfo: R.clone action.paverInfo
            else state


    reduceUi: (state, action) ->
        switch action.type
            when "pavingPage.ui.panelToggle" then R.merge state, showControlPanel: !state.showControlPanel
            when "pavingPage.ui.toggleTracking" then R.merge state, trackUsers: !state.trackUsers
            when "pavingPage.ui.toggleSorting" then R.merge state, customSorting: !state.customSorting
            when "pavingPage.ui.showPopup" then R.merge state, showMarkerPopup: action.showMarkerPopup
            else state


    reduceFilters: (state, action) ->
        switch action.type
            when "pavingPage.filters.toggleUser"
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
            when "pavingPage.filters.selectUsers"
                R.merge state, users: R.clone action.userIds
            when "pavingPage.filters.selectAllUsers"
                R.merge state, users: "all"
            when "pavingPage.filters.clearAllUsers"
                R.merge state,
                    users: []
                    selectedMarker: {}
            when "pavingPage.filters.selectMarker"
                R.merge state, selectedMarker: R.clone action.selectedMarker
            else
                state
