module.exports =
    data:
        setUsers: (users) -> type: "timelinePage.data.setUsers", users: users
        setPositions: (positions) -> type: "timelinePage.data.setPositions", positions: positions
    filter:
        setDate: (date) -> type: "timelinePage.filter.setDate", date: date
        addUser: (userId) -> type: "timelinePage.filter.addUser", userId: userId
        removeUser: (userId) -> type: "timelinePage.filter.removeUser", userId: userId
        resetUsers: -> type: "timelinePage.filter.resetUsers"
        selectAllUsers: -> type: "timelinePage.filter.selectAllUsers"
        reconcileUsers: (users) -> type: "timelinePage.filter.reconcileUsers", users: users
    timeline:
        movePlayhead: (timePercentage) -> type: "timelinePage.timeline.movePlayhead", timePercentage: timePercentage
        advancePlayhead: (increment) -> type: "timelinePage.timeline.advancePlayhead", increment: increment
        setTimelineParams: (params) -> R.merge type: "timelinePage.timeline.setTimelineParams", params
    ui:
        dateControlReady: -> type: "timelinePage.ui.dateControlReady"
        play: -> type: "timelinePage.ui.play"
        pause: -> type: "timelinePage.ui.pause"
        playToggle: -> type: "timelinePage.ui.playToggle"
        selectTime: (selectedTime) -> type: "timelinePage.ui.selectTime", selectedTime: selectedTime
        setPlaybackSpeed: (speed) -> type: "timelinePage.ui.setPlaybackSpeed", speed: speed
        unselectTime: -> type: "timelinePage.ui.unselectTime"
        startDataRequest: -> type: "timelinePage.ui.startDataRequest"
        finishDataRequest: -> type: "timelinePage.ui.finishDataRequest"