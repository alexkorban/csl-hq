module.exports =
    reduceData: (state, action) ->
        switch action.type
            when "timelinePage.data.setUsers" then R.merge state, users: R.clone action.users
            when "timelinePage.data.setPositions" then R.merge state, positions: R.map R.identity, action.positions
            else state
    reduceFilters: (state, action) ->
        switch action.type
            when "timelinePage.filter.setDate"
                if action.date - state.date != 0
                    R.merge state, date: R.clone action.date
                else state
            when "timelinePage.filter.addUser"
                if !R.contains action.userId, state.users
                    R.merge state, users: R.append(action.userId, state.users)
                else state
            when "timelinePage.filter.removeUser"
                R.merge state, users: R.reject(R.equals(action.userId), state.users)
            when "timelinePage.filter.reconcileUsers"
                Tracer.log "Reconciled filters:", R.filter ((id) => R.any R.propEq("id", id), action.users), state.users
                R.merge state, users: R.filter ((id) => R.any R.propEq("id", id), action.users), state.users
            when "timelinePage.filter.resetUsers"
                R.merge state, users: []
            else state
    reduceTimeline: (state, action) ->
        switch action.type
            when "timelinePage.timeline.movePlayhead"
                newTime = clamp state.start, state.finish,
                    Math.floor(state.start + (state.finish - state.start) * action.timePercentage)
                R.merge state, time: newTime
            when "timelinePage.timeline.advancePlayhead"
                newTime = clamp state.start, state.finish, state.time + action.increment
                R.merge state, time: newTime
            when "timelinePage.timeline.setTimelineParams" then R.merge state,
                start: action.start * 1000
                finish: action.finish * 1000
                time: clamp(action.start * 1000, action.finish * 1000, action.start * 1000 + (state.time - state.start))
                timeZone: action.timeZone
                userCounts: R.clone action.userCounts
            else state
    reduceUi: (state, action) ->
        switch action.type
            when "timelinePage.ui.play" then R.merge state, isPlaying: true
            when "timelinePage.ui.pause" then R.merge state, isPlaying: false
            when "timelinePage.ui.playToggle" then R.merge state, isPlaying: !state.isPlaying
            when "timelinePage.ui.selectTime" then R.merge state, selectedTime: action.selectedTime
            when "timelinePage.ui.unselectTime" then R.merge state, selectedTime: null
            when "timelinePage.ui.setPlaybackSpeed" then R.merge state, playbackSpeed: action.speed
            when "timelinePage.ui.dateControlReady" then R.merge state, dateControlReady: true
            when "timelinePage.ui.startDataRequest" then R.merge state, dataRequestIsInProgress: true
            when "timelinePage.ui.finishDataRequest" then R.merge state, dataRequestIsInProgress: false
            else state
    postReduce: (state, action) ->
        switch action.type
            when "timelinePage.filter.selectAllUsers"
                R.assocPath ["filters", "users"], R.pluck("id", state.data.users), state
            else state
