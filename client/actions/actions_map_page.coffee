module.exports =
    filters:
        toggleUser: (userId) -> type: "mapPage.filters.toggleUsers", userId: userId
        selectUsers: (userIds) -> type: "mapPage.filters.selectUsers", userIds: userIds
        selectAllUsers: -> type: "mapPage.filters.selectAllUsers"
        clearAllUsers: -> type: "mapPage.filters.clearAllUsers"
        selectMarker: (marker) -> type: "mapPage.filters.selectMarker", selectedMarker: marker ? {}
    ui:
        toggleTracking: -> type: "mapPage.ui.toggleTracking"
        showMarkerPopup: (visible) -> type: "mapPage.ui.showPopup", showMarkerPopup: visible
