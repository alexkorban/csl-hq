module.exports =
    data:
        setTruckInfo: (trucks) -> type: "pavingPage.data.setTruckInfo", truckInfo: trucks
        setBatchPlantInfo: (batchPlantInfo) -> type: "pavingPage.data.setBatchPlantInfo", batchPlantInfo: batchPlantInfo
        setProduction: (productionData) -> type: "pavingPage.data.setProductionData", productionData: productionData
        setPaverInfo: (paverInfo) -> type: "pavingPage.data.setPaverInfo", paverInfo: paverInfo
    ui:
        panelToggle: -> type: "pavingPage.ui.panelToggle"
        toggleTracking: -> type: "pavingPage.ui.toggleTracking"
        toggleSorting: -> type: "pavingPage.ui.toggleSorting"
        showMarkerPopup: (visible) -> type: "pavingPage.ui.showPopup", showMarkerPopup: visible

    filters:
        toggleUser: (userId) -> type: "pavingPage.filters.toggleUser", userId: userId
        selectUsers: (userIds) -> type: "pavingPage.filters.selectUsers", userIds: userIds
        selectAllUsers: -> type: "pavingPage.filters.selectAllUsers"
        clearAllUsers: -> type: "pavingPage.filters.clearAllUsers"
        selectMarker: (marker) -> type: "pavingPage.filters.selectMarker", selectedMarker: marker ? {}
