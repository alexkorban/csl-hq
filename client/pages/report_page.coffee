noRecordsMessage = "There are no records for this time period."

positionLink = (position, text) ->
    if position?
        """
        <a href = 'http://maps.google.com/maps?q=#{text}+(location)+%40#{position.lat},#{position.lon}'
            target = '_blank'>#{text}</a>
        """
    else
        text ? 'No record'


speedBandFromIndex = (index) ->
    switch index
        when 0 then "Stationary"
        when 1 then "0-5 km/h"
        when 2 then "6-15 km/h"
        when 3 then "16-40 km/h"
        when 4 then "40+ km/h"
        else "//unknown speed band//"


vehicleDueTime = (record) ->
    if !R.isEmpty record.signons
        lastSignon = R.last record.signons
        timestamp = moment.tz("#{record.date} #{lastSignon.time}", "DD/MM/YY HH:mm", store.getState().project.timezone)
        dueTime = timestamp.add(lastSignon.properties.vehicleUseInterval, "h")
        if timestamp.isSame(moment(), "day") && dueTime.isAfter(moment())
            dueTime.format "HH:mm"
        else
            #no due time available
    else
        #no signons


reportBuilders =
    projectVisits: (events) ->
        return noRecordsMessage if events.length == 0

        tableRows = R.map ((event) ->
            """
            <tr>
            <td>#{event.userName}</td>
            <td>#{event.userRole}</td>
            <td>#{event.userCompany}</td>
            <td>#{event.date.split(" ")[0]}</td>
            <td>#{positionLink event.firstEntryPosition, event.arrivedAt}</td>
            <td>#{positionLink event.lastExitPosition, event.departedAt}</td>
            </tr>
            """
            ), events
        .join "\n"

        """
        <a href = '#projectVisits' class='csvLink'>Download as CSV</a><br/><br/>
        <table data-role="table" class="ui-table ui-responsive table-stripe">
        <thead>
            <tr>
            <th data-priority="2">Person</th>
            <th>Role</th>
            <th data-priority="3">Company</th>
            <th data-priority="3">Date</th>
            <th data-priority="3">Arrived at</th>
            <th data-priority="3">Departed at</th>
            </tr>
         </thead>
        <tbody>
            #{tableRows}
        </tbody>
        </table>
        <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
        """


    areas: (events) ->
        return noRecordsMessage if R.isEmpty events

        processDay = (day) ->
            date = moment(day.day).format "D/M/YY"

            borderSpec = (area) ->
                if area.isBoundary
                    "style = 'border-bottom: 2px solid #5191c3; font-weight: bold'"
                else
                    ""

            noRecordsRow = """<tr><td>#{date}</td><td></td><td></td><td>No records</td></tr>"""

            detailsHtml = (lastSyncedAt, hasSyncedOnLaterDate, area) ->
                firstEntry = if area.firstEntryMissing then """First entry missing - on site the night before.</br>""" else ""
                lastExit =
                    if area.lastExitMissing
                        if !hasSyncedOnLaterDate
                            time = moment.tz(lastSyncedAt, store.getState().project.timezone).format "H:mm"
                            """Last known location inside #{area.areaName} (at #{time}).<br/>"""
                        else
                            """Last exit missing - on site overnight.<br/>"""
                    else ""

                visitsStr = if area.areaVisits.length == 1
                    """1 visit.<br/>"""
                else
                    """#{area.areaVisits.length} visits.<br/>"""

                visitsList = (R.map (visit) ->
                    timeZone = store.getState().project.timezone
                    start = moment.tz(visit.entryAt, "UTC").tz(timeZone)
                    end = moment.tz(visit.exitAt, "UTC").tz(timeZone)
                    """<span style="font-weight: normal;">
                       #{start.format("HH:mm")} - #{end.format("HH:mm")}:</span>
                      <div style="display: inline-block; vertical-align: top; font-weight: normal;"> #{formattedDuration visit.length}</div>
                    """
                , area.areaVisits).join "<br/>\n"

                visits = if area.areaVisits.length > 0
                    """
                    <div data-role="collapsible" data-mini="true" data-inset="false" data-iconpos="right"
                        data-collapsed-icon="carat-d" data-expanded-icon="carat-u">
                        <h4>#{visitsStr}</h4>
                        #{visitsList}
                    </div>
                    """
                else ""

                "#{firstEntry}#{lastExit}#{visits}"

            if R.isEmpty day.areasDetails
                noRecordsRow
            else
                sortedAreas = R.pipe(R.sortBy(R.prop "areaName"), R.sortBy(R.prop "isBoundary")) day.areasDetails
                (R.map (area) ->
                    """
                    <tr #{borderSpec area}>
                    <td>#{date}</td>
                    <td>#{if area.isBoundary then "Total time" else area.areaName}</td>
                    <td>#{formattedDuration area.totalTime}</td>
                    <td>#{detailsHtml day.lastSyncedAt, day.hasSyncedOnLaterDate, area}</td>
                    </tr>
                    """
                , sortedAreas).join "\n"

        noAreasDetails = (day) -> R.isEmpty day.areasDetails

        userRowsHtml = (days) ->
            tableRows = R.pipe(R.dropWhile(noAreasDetails), R.dropLastWhile(noAreasDetails), R.map(processDay), R.join("\n")) days

            """
            <table data-role="table" class="ui-table table-stripe" data-mode="columntoggle">
            <thead>
                <tr>
                <th width = "15%">Date</th>
                <th width = "15%">Area</th>
                <th width = "20%">Time in area</th>
                <th>Details</th>
                </tr>
             </thead>
            <tbody>
                #{tableRows}
            </tbody>
            </table>
            <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
            """

        groupedEvents = R.groupBy ((event) -> event.userName), events

        res = (R.map (userName) ->
            userCompany = if groupedEvents[userName][0].userCompany.length > 0 then " at " + groupedEvents[userName][0].userCompany else ""
            """
            <h2 style = "margin-bottom: 10px">#{userName}</h2>
            (#{groupedEvents[userName][0].userRole}#{userCompany})
            <br/><br/>
            #{userRowsHtml groupedEvents[userName]}
            """
        ,  R.keys(groupedEvents).sort()).join("\n")
        """<a href = '#areas' class='csvLink'>Download as CSV</a><br/><br/>#{res}"""


    speedBands: (events) ->
        return noRecordsMessage if events.length == 0

        #JSON.stringify events

        entriesHtml = (entries) ->
            day = entries[0].day
            area = entries[0].geometryName
            tableRows = R.map (entry) ->
                borderSpec = if area != entry.geometryName
                    area = entry.geometryName
                    "style = 'border-top: 1px solid #5393c5'"
                else
                    ""

                if day != entry.day
                    day = entry.day
                    borderSpec = "style = 'border-top: 2px solid #5191c3'"

                distance = if entry.speedBand == 0 then "&mdash;" else "#{Math.round(entry.speedBandDistance / 100) / 10} km"
                fuel = if entry.speedBand == 0 then "&mdash;" else "#{Math.round(entry.speedBandDistance * 0.0033) / 10 } L"

                """
                <tr #{borderSpec}>
                <td>#{entry.day.split(" ")[0]}</td>
                <td>#{entry.geometryName}</td>
                <td>#{speedBandFromIndex(entry.speedBand)}</td>
                <td>#{Math.round(entry.duration / 60)} minutes (#{Math.round(entry.duration / 60 / 6) / 10} hours)</td>
                <td>#{Math.round(entry.percentage * 10) / 10}%</td>
                <td>#{Math.round(entry.minSpeed * 3.6)} - #{Math.round(entry.maxSpeed * 3.6)} km/h</td>
                <td>#{distance}</td>
                <td>#{fuel}</td>
                </tr>
                """
            , entries
            .join "\n"

            """
            <table data-role="table" class="ui-table ui-responsive table-stripe">
            <thead>
                <tr>
                <th data-priority="1">Date</th>
                <th data-priority="2">Area</th>
                <th data-priority="3">Speed band</th>
                <th data-priority="4">Time in speed band</th>
                <th data-priority="4">Percentage</th>
                <th>Speed range</th>
                <th>Distance</th>
                <th>Fuel burn (approx.)</th>
                </tr>
             </thead>
             <tbody>
                #{tableRows}
            </tbody>
            </table>
            <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
            """

        groupedEvents = R.groupBy ((event) -> event.userName), events

        res = (R.map (userName) ->
            userCompany = if groupedEvents[userName][0].userCompany.length > 0 then " at " + groupedEvents[userName][0].userCompany else ""
            """
            <h2 style = "margin-bottom: 10px">#{userName}</h2>
            (#{groupedEvents[userName][0].userRole}#{userCompany})
            <br/><br/>
            #{entriesHtml groupedEvents[userName]}
            """
        , R.keys(groupedEvents).sort()).join("\n")

        """<a href = '#speedBands' class='csvLink'>Download as CSV</a><br/><br/>#{res}"""


    speeding: (events) ->
        return noRecordsMessage


    timeline: (events) ->
        return noRecordsMessage if events.length == 0

        areaNames = (event) =>
            switch event.type
                when "jha"
                    (R.map ((item) -> item.geometryName), event.properties.insideGeometries).join(", ")
                when "app_start"
                    "Safe Site was started"
                when "app_stop"
                    "Safe Site was stopped manually"
                when "concrete_movement"
                    inflector.capitalize(event.properties.step) + ": " +
                        (R.pluck "geometryName", (event.properties.insideGeometries ? [])).join(", ")
                else
                    event.geometryName ? "&mdash;"

        position = (event) =>
            p = event.position
            if p?
                """
                <a href = 'http://maps.google.com/maps?q=#{event.type}+(location)+%40#{p.lat},#{p.lon}'
                    target = '_blank'>Show</a>
                """
            else
                ""

        typeToStr = (type) =>
            switch type
                when "jha" then """<span style="color: #0000aa">JHA</span>"""
                when "app_stop" then """<span style="color: #aa0000">App off</span>"""
                when "app_start" then """<span style="color: #00aa00">App on</span>"""
                when "concrete_movement" then """Concrete"""
                else inflector.capitalize type

        tableRows = (items) =>
            indent = 0
            (R.map (event) ->
                indent -= 2 if event.type == "exit"
                indent = 0 if indent < 0
                spaces = new Array(indent + 1).join '&nbsp;'
                indent += 2 if event.type == "entry"
                """
                <tr>
                <td>#{typeToStr event.type}</td>
                <td>#{if event.type == "app_stop" or event.type == "app_start" then "" else spaces}#{areaNames event}</td>
                <td>#{event.createdAt}</td>
                <td>#{position event}</td>
                </tr>
                """
            , items).join "\n"

#            # calculate time in seconds
#            areaTime = (events) =>
#                time = 0
#                for i in [0..events.length - 1]
#                    entry = events[i]
#                    exit = events[i + 1]
#
#                    if entry.type == "entry" && !exit?  # last record
#                        time += Math.floor((new Date).getTime() / 1000) - entry.timestamp
#                    else if entry.type != "entry" || exit?.type != "exit"  # not an entry/exit pair
#                        continue
#                    else if exit.timestamp - entry.timestamp >= 10  # skip extra-short intervals
#                        time += exit.timestamp - entry.timestamp
#
#                time

#            timesForAreas = (items) =>
#                s = "<table style = 'width: 50%' class = 'ui-table table-stripe'><thead><th>Area</th><th>Time (minutes)</th></thead><tbody>"
#                byArea = _.groupBy items, (item) -> item.geometryId
#                delete byArea[undefined]
#
#                s += ("""<tr><td>#{events[0].geometryName}</td>
#                    <td>#{Math.round(10 * (areaTime events) / 60) / 10}</td></tr>""" for areaId, events of byArea when areaId?).join("\n")
#
#                s += "</tbody></table>"
#                s

        groupedEvents = R.groupBy ((event) -> event.userName), events

        reportHtml = "<br/><a href = '#timeline' class='csvLink'>Download as CSV</a><br/><br/>"
        reportHtml += (R.map (name) ->
            if !R.isEmpty groupedEvents[name]
#                eventsByTime = _.sortBy items, (item) ->
#                    # make sure that entry events appear after exit events if both have
#                    # the same timestamp
#                    item.timestamp * 10 + (if item.type == 'entry' then 1 else 0)
                """
                <h2 id = '#{groupedEvents[name][0].userId}'>#{name}</h2>
                <table data-role="table" class="ui-table ui-responsive table-stripe">
                <thead>
                    <tr>
                    <th data-priority="2" width="10%">Event</th>
                    <th width="30%">Area</th>
                    <th data-priority="3" width="20%">Time</th>
                    <th data-priority="3">Location</th>
                    </tr>
                 </thead>
                <tbody>
                    #{tableRows groupedEvents[name]}
                </tbody>
                </table>
                <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
                """
        , R.keys(groupedEvents).sort()).join("")

        reportHtml


    concreteTests: (events) ->
        return noRecordsMessage if events.length == 0

        tableRows = R.map (record) ->
            avgAirContent = if record.airContent1? && record.airContent2?
                (record.airContent1 + record.airContent2) / 2.0
            else
                undefined

            loadDetails = "Recorded at: <strong>#{positionLink record.loadPosition, record.loadTime}</strong><br/>"
            testDetails = "Recorded at: <strong>#{positionLink record.testPosition, record.testTime}</strong><br/>"
            dumpDetails = "Recorded at: <strong>#{positionLink record.dumpPosition, record.dumpTime}</strong><br/>"

            if (record.errorStep == "")
                startRow = "<tr>"

                loadDetails += """
                   Batch plant: <strong>#{record.batchPlantName ? ""}</strong><br/>
                   Load number: <strong>#{record.loadNumber ? ""}</strong><br/>
                   Mix code: <strong>#{record.mixCode ? ""}</strong><br/>
                   Batch time: <strong>#{record.batchTime ? ""}</strong><br/>
                   Load volume: <strong>#{record.loadVolume ? ""}</strong><br/>
                """

                testDetails += """
                    Test type: <strong>#{record.testType ? ""}</strong><br/>
                    Initial slump, mm: <strong>#{if record.testTime? then (record.initialSlump ? "Fail") else ""}</strong><br/>
                    Final slump, mm: <strong>#{if (record.testTime? && !record.initialSlump?) then (record.finalSlump ? "Fail") else ""}</strong><br/>
                    <hr/>
                    Air content 1, %: <strong>#{record.airContent1 ? ""}</strong><br/>
                    Air content 2, %: <strong>#{record.airContent2 ? ""}</strong><br/>
                    Average air content, %: <strong>#{avgAirContent ? ""}</strong><br/>
                    Air correction: <strong>#{record.airCorrection ? ""}</strong><br/>
                    <hr/>
                    MUV: <strong>#{record.muv ? ""}</strong><br/>
                    Air temperature: <strong>#{record.airTemp ? ""}</strong><br/>
                    Concrete temperature: <strong>#{record.concreteTemp ? ""}</strong><br/>
                    Cylinder number: <strong>#{record.cylinderNum ? ""}</strong><br/>
                    Beam number: <strong>#{record.beamNum ? ""}</strong><br/>
                    Notes: <strong>#{record.notes ? ""}</strong><br/>
                """

                dumpDetails += "Dump site: <strong>#{record.dumpSite ? ""}</strong><br/>"
            else
                startRow = """<tr class="error">"""

                switch record.errorStep
                    when "load"
                        loadDetails += "Invalid scan: " + record.errorText
                        testDetails = ""
                        dumpDetails = ""
                    when "test"
                        loadDetails = ""
                        testDetails += "Invalid scan: " + record.errorText
                        dumpDetails = ""
                    when "dump"
                        loadDetails = ""
                        testDetails = ""
                        dumpDetails += "Invalid scan: " + record.errorText

            """
            #{startRow}
            <td>#{record.userName ? ""}</td>
            <td>#{loadDetails}</td>
            <td>#{testDetails}</td>
            <td>#{dumpDetails}</td>
            </tr>
            """
        , events
        .join "\n"

        """
        <a href = '#concreteTests' class='csvLink'>Download as CSV</a><br/><br/>
        <table data-role="table" class="ui-table ui-responsive table-stripe" style="table-layout: fixed">
        <thead>
            <tr>
            <th data-priority="1" style="width: 10%">Person</th>
            <th data-priority="2" style="width: 30%">Load details</th>
            <th data-priority="3" style="width: 30%">Test details</th>
            <th data-priority="4" style="width: 30%">Dump details</th>
            </tr>
         </thead>
        <tbody>
            #{tableRows}
        </tbody>
        </table>
        <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
        """

    breaks: (events) ->
        Tracer.log "num events", events.length
        return noRecordsMessage if events.length == 0

        Tracer.log "events", events

        timeZone = store.getState().project.timezone

        breaksHtml = (stops, totalBreakTime) ->
            return "&mdash;" if stops.length == 0

            mapLink = (text, position) ->
                if !position?
                    text
                else
                    """
                    <a href = 'http://maps.google.com/maps?q=#{text}+(location)+%40#{position.lat},#{position.lon}'
                        target = '_blank'>#{text}</a>
                    """

            breaksList = (R.map (stop) ->
                start = moment.tz(stop.start.coord, "UTC").tz(timeZone)
                end = moment.tz(stop.end.coord, "UTC").tz(timeZone)
                dur = moment.duration(end - start)
                insideGeometriesText = if stop.start.insideGeometries?
                    """<span style="font-size: small; color: #888">#{stop.start.insideGeometries}</span>"""
                else
                    ""

                """
                #{start.format("HH:mm")} - #{end.format("HH:mm")}:
                <div style="display: inline-block; vertical-align: top">
                    #{mapLink Math.round(dur.asMinutes()).toString() + " minutes", stop.start.position}
                    #{if stop.isScheduled then " (scheduled)" else ""}
                    #{insideGeometriesText}
                </div>
                """
            , stops).join "<br/>\n"

            """
            <div data-role="collapsible" data-mini="true" data-inset="false" data-iconpos="right"
                data-collapsed-icon="carat-d" data-expanded-icon="carat-u">
                <h4>Total: #{Math.round totalBreakTime.asMinutes()} minutes</h4>
                #{breaksList}
            </div>
            """

        tableRows = R.map (record) ->
            totalActiveTime = moment.duration(record.totalActiveTime)
            console.log "Total active time:", totalActiveTime
            totalBreakTime = moment.duration R.sum R.map(((s) -> s.end.coord - s.start.coord), record.stops)
            console.log "Total break time:", totalBreakTime

            workHours = Math.round(10 * totalActiveTime.asHours()) / 10
#                workTime = moment.duration(totalActiveTime.asSeconds(), "seconds").subtract(totalBreakTime)
#                workHours = Math.round(10 * (workTime).asHours()) / 10

            """
            <tr>
            <td>#{record.userName}</td>
            <td>#{record.role}</td>
            <td>#{record.truckNo}</td>
            <td>#{record.company}</td>
            <td>#{record.day.slice(0, 8)}</td>
            <td>#{record.start.slice(9, 14)}</td>
            <td>#{workHours ? 0} hours</td>
            <td>#{breaksHtml record.stops, totalBreakTime}</td>
            </tr>
            """
        , events
        .join "\n"

        """
        <table data-role="table" class="ui-table table-stripe" data-mode="columntoggle">
        <thead>
           <tr>
           <th width = "10%">Name</th>
           <th width = "10%">Role</th>
           <th width = "10%">Truck no.</th>
           <th width = "10%">Company</th>
           <th width = "10%">Date</th>
           <th width = "10%">Signed on<br/>as fit for work at</th>
           <th width = "10%">Total work time</th>
           <th width = "30%">Breaks</th>
           </tr>
        </thead>
        <tbody>
           #{tableRows}
        </tbody>
        </table>
        <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
        """

    driverFitness: (events) ->
        return noRecordsMessage if events.length == 0

        answers = {
            nameConfirm:  "Name confirmed",
            sleep5h:      "Slept 5 hours or more",
            sleep12h:     "Slept 12 hours in the last 2 days"
            drugsAlcohol: "Free of drugs/alcohol",
            fit12shift:   "Fit for 12 hour shift"
        }

        tableRows = R.map (record) =>
            # Format properties/answers to be human readable
            answersHTML = R.values R.mapObjIndexed (value, key, obj) =>
                if (answers[key])
                    "#{answers[key]}: #{if value then "Yes" else """<span class="error">No</span>"""}"
                else
                    ""
            , record.properties
            .join "<br/>"

            hoursType = if R.contains "extended_hours", record.permissions then "Advanced" else "Standard"
                
            """
            <tr>
            <td>#{record.date}</td>
            <td>#{record.time}</td>
            <td>#{record.userName}</td>
            <td>#{record.vehicleType}</td>
            <td>#{record.vehicleNumber}</td>
            <td>#{hoursType}</td>
            <td>#{answersHTML}</td>
            </tr>
            """
        , events
        .join "\n"

        """
        <a href = '#driverFitness' class='csvLink'>Download as CSV</a><br/><br/>
        <table data-role="table" class="ui-table ui-responsive table-stripe">
        <thead>
           <tr>
           <th width = "11.5%">Date</th>
           <th width = "11.5%">Time</th>
           <th width = "11.5%">User name</th>
           <th width = "11.5%">Vehicle type</th>
           <th width = "11.5%">Vehicle no.</th>
           <th width = "11.5%">Hours</th>
           <th width = "30%">Answers</th>
           </tr>
        </thead>
        <tbody>
           #{tableRows}
        </tbody>
        </table>
        <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
        """


    loadCounts: (events) ->
        Tracer.log "num events", events.length
        return noRecordsMessage if events.length == 0

        Tracer.log "events", events

        timeZone = store.getState().project.timezone

        getCycleDetailsHtml = (details) ->
            totalLoadedQueueingTime = formattedDuration R.pipe(R.map(R.prop("loadedQueueingTime")), R.sum) details
            totalEmptyQueueingTime = formattedDuration R.pipe(R.map(R.prop("emptyQueueingTime")), R.sum) details
            totalFuelBurn = R.sum(R.map R.pipe(R.prop("fuelBurn"), Math.round), details) + " l"
            detailsHtml = R.map (cycle) ->
                loadedAt = moment.tz(cycle.loadedAt, "UTC").tz(timeZone).format("HH:mm")
                loadTime = formattedDuration cycle.loadTime

                emptyQueueingTime = if !cycle.emptyQueueingTime?
                    "&mdash;"
                else
                    formattedDuration cycle.emptyQueueingTime

                haulTime = formattedDuration cycle.haulTime
                haulDistance = (cycle.haulDistance / 1000).toFixed(2) + " km"

                returnTime = if !cycle.returnTime? then "&mdash;" else formattedDuration cycle.returnTime
                returnDistance = if !cycle.returnDistance?
                    "&mdash;"
                else
                    (cycle.returnDistance / 1000).toFixed(2) + " km"

                loadedQueueingTime = formattedDuration cycle.loadedQueueingTime

                dumpedAt = moment.tz(cycle.dumpedAt, "UTC").tz(timeZone).format("HH:mm")
                dumpTime = formattedDuration cycle.dumpTime

                cycleTime = if !cycle.cycleTime? then "&mdash;" else formattedDuration cycle.cycleTime

                fuelBurn = if !cycle.fuelBurn?
                    "&mdash;"
                else
                    cycle.fuelBurn.toFixed(1) + " l"

                invalidDumpMessage = if cycle.isMissingDump
                    "Unknown dump location"
                else if cycle.isAmbiguousDump
                    "Ambiguous dump location, one of: #{cycle.dumpedIn.join ", "}"
                else
                    ""

                if cycle.isMissingDump || cycle.isAmbiguousDump
                    """
                    <tr>
                        <td style="color: #004685">#{loadedAt}</td>
                        <td style="color: #004685">#{cycle.loadedBy}</td>
                        <td style="color: #004685">#{loadTime}</td>
                        <td style="text-align: center" colspan="9">#{invalidDumpMessage}</td>
                        <td>#{cycleTime}</td>
                        <td>&mdash;</td>
                    </tr>
                    """
                else
                    """
                    <tr>
                        <td style="color: #004685">#{loadedAt}</td>
                        <td style="color: #004685">#{cycle.loadedBy}</td>
                        <td style="color: #004685">#{loadTime}</td>
                        <td>#{haulTime}</td>
                        <td>#{haulDistance}</td>
                        <td>#{loadedQueueingTime}</td>
                        <td style="color: #047500">#{dumpedAt}</td>
                        <td style="color: #047500">#{cycle.dumpedIn}</td>
                        <td style="color: #047500">#{dumpTime}</td>
                        <td>#{returnTime}</td>
                        <td>#{returnDistance}</td>
                        <td>#{emptyQueueingTime}</td>
                        <td>#{cycleTime}</td>
                        <td>#{fuelBurn}</td>
                    </tr>
                    """
            , details
            .join "\n"

            """
            <table class="cycles">
               <tr>
                    <th width = "10%">Loaded at</th>
                    <th width = "10%">Loaded by</th>
                    <th width = "10%">Load time</th>
                    <th width = "10%">Haul time</th>
                    <th width = "10%">Haul distance</th>
                    <th width = "10%">Loaded<br/>queueing time</th>
                    <th width = "10%">Dumped at</th>
                    <th width = "10%">Dumped in</th>
                    <th width = "10%">Dump time</th>
                    <th width = "10%">Return time</th>
                    <th width = "10%">Return distance</th>
                    <th width = "10%">Empty<br/>queueing time</th>
                    <th width = "10%">Cycle time</th>
                    <th width = "10%">Fuel burn<br/>(approx.)</th>
                </tr>
                #{detailsHtml}
                <tr>
                    <td class="totals"></td><td class="totals"></td><td class="totals"></td>
                    <td class="totals"></td><td class="totals"></td>
                    <td class="totals">#{totalLoadedQueueingTime}</td>
                    <td class="totals"></td><td class="totals"></td>
                    <td class="totals"></td><td class="totals"></td><td class="totals"></td>
                    <td class="totals">#{totalEmptyQueueingTime}</td>
                    <td class="totals"></td>
                    <td class="totals">#{totalFuelBurn}</td>
                </tr>
            </table>
            """

        tableRows = R.map (record) ->
            if record.cycles?.length > 0
                # Take the last load time if the last dump time is unavailable (in case of ambiguous dump).
                # Somewhat imprecise but better than not showing the time at all.
                totalWorkTime = moment.duration(R.last(record.cycles).dumpedAt - R.head(record.cycles).loadedAt)
                workHours = Math.round(10 * totalWorkTime.asHours()) / 10
                loadsPerHour = if workHours > 0
                    (record.cycles.length / workHours).toFixed(1)
                else
                    "&mdash;"
                cycleDetailsHtml = getCycleDetailsHtml record.cycles

                """
                <tr>
                    <td>#{record.userName}</td>
                    <td>#{record.role}</td>
                    <td>#{record.truckNo}</td>
                    <td>#{record.company}</td>
                    <td>#{record.day.slice(0, 8)}</td>
                    <td>#{record.cycles.length}</td>
                    <td>#{loadsPerHour}</td>
                    <td>
                        <a href="#" onclick="$(this).parent().parent().next('tr').toggle()">
                            <span class="ui-icon-carat-d ui-btn-icon-left" style="position: relative;"
                                onclick="$(this).toggleClass('ui-icon-carat-u')"/>
                        </a>
                    </td>
                </tr>
                <tr style="display: none"><td colspan="10" style="background: none">#{cycleDetailsHtml}</td></tr>
                <tr style="display: none">
                """
            else ""
        , events
        .join "\n"

        """
        <table data-role="table" class="ui-table table-main" data-mode="columntoggle">
            <thead>
               <tr>
               <th width = "13%">Name</th>
               <th width = "13%">Role</th>
               <th width = "12%">Truck no.</th>
               <th width = "13%">Company</th>
               <th width = "13%">Date</th>
               <th width = "12%">Loads total</th>
               <th width = "12%">Loads/hour</th>
               <th width = "12%">Details</th>
               </tr>
            </thead>
           <tbody>
               #{tableRows}
           </tbody>
        </table>
        <a href = "#" class = "navLink" style = "display:block; float:right"
            onclick="scrollTo(0, 0)">Back to top</a>
        """


    lightVehicles: (events) ->
        return noRecordsMessage if events.length == 0

        Tracer.log "events", events

        tableRows = R.map (record) ->
            # Format properties/answers to be human readable
            signonCollapsible = (signons) ->
                signonList = R.map (signon) ->
                    "#{signon.time}: #{signon.userName} (#{signon.userRole})"
                , signons
                .join "<br/>"

                """
                <div data-role="collapsible" data-mini="true" data-inset="false" data-iconpos="right"
                    data-collapsed-icon="carat-d" data-expanded-icon="carat-u">
                    <h4>#{signons.length} signons</h4>
                    #{signonList}
                </div>
                """


            """
            <tr>
            <td>#{record.date}</td>
            <td>#{record.number}</td>
            <td>#{record.make}</td>
            <td>#{record.model}</td>
            <td>#{record.vehicleType}</td>
            <td>#{(record.travelDistance.distance / 1000).toFixed(1)} km</td>
            <td>#{vehicleDueTime(record) ? "&mdash;"}</td>
            <td>#{signonCollapsible record.signons}</td>
            </tr>
            """
        , events
        .join "\n"

        """
        <a href = '#lightVehicles' class='csvLink'>Download as CSV</a><br/><br/>
        <table data-role="table" class="ui-table table-stripe" data-mode="columntoggle">
        <thead>
           <tr>
           <th width = "10%">Date</th>
           <th width = "10%">Number</th>
           <th width = "10%">Make</th>
           <th width = "10%">Model</th>
           <th width = "10%">Type</th>
           <th width = "10%">Travel distance</th>
           <th width = "10%">Due back</th>
           <th width = "30%">Signons</th>
           </tr>
        </thead>
        <tbody>
           #{tableRows}
        </tbody>
        </table>
        <a href = '#' class = 'navLink' style = "display:block; float:right" onclick="scrollTo(0, 0)">Back to top</a>
        """



reportLoader = (params) ->
    days = moment.range(moment(params.dateRange[0]), moment(params.dateRange[1])).toArray('days')
    Tracer.log "REPORT REQUEST START", moment().format "H:mm:ss"
    getData = (day) ->
        day = day.format "YYYY-MM-DD"
        params = R.merge params, dateRange: [day, day]
        urlPath = "reports/#{store.getState().project.id}/#{params.url}"
        Uplink.get(urlPath, params)
    Promise.map days, getData, concurrency: 1


getReportCSV =
    areas: (result) ->
        transformed = R.reduce (totalRows, day) ->
            time = moment.tz(day.lastSyncedAt, store.getState().project.timezone).format "H:mm"
            date = moment(day.day).format "D/M/YY"
            dayRows = R.map (area) ->
                userName: day.userName
                userRole: day.userRole
                userCompany: day.userCompany
                date: date
                areaName: area.areaName
                totalTime: formattedDuration area.totalTime
                firstEntryMissing: if area.firstEntryMissing then "yes" else "no"
                lastExitMissing: if area.lastExitMissing && day.hasSyncedOnLaterDate then "yes" else "no"
                lastKnownLocationInsideTheArea: if area.lastExitMissing && !day.hasSyncedOnLaterDate then time else "-"
                numberOfVisits: R.length area.areaVisits
            , day.areasDetails
            R.concat totalRows, dayRows
        , [], result
        json2csv {data: transformed, fields: ["userName", "userRole", "userCompany", "date", "areaName", "totalTime",
            "firstEntryMissing", "lastExitMissing", "lastKnownLocationInsideTheArea", "numberOfVisits"]}

    concreteTests: (result) ->
        initialSlump = {label: "initialSlump", value: (row) ->
            if row.testTime? && !row.initialSlump?
                "Fail"
            else row.initialSlump
        }
        finalSlump = {label: "finalSlump", value: (row) ->
            if row.testTime? && !row.initialSlump? && !row.finalSlump?
                "Fail"
            else row.finalSlump
        }
        json2csv {data: result, fields: ["docketId", "userName", initialSlump, finalSlump, "airContent1", "airContent2",
            "airCorrection", "muv", "airTemp", "concreteTemp", "cylinderNum" ,"beamNum", "notes",
            "batchPlantName", "loadNumber" ,"mixCode", "batchTime","loadVolume", "loadTime",
            "testTime", "dumpTime"]}

    driverFitness: (result) ->
        transformed = R.map (record) ->
            record.advancedHours = if R.contains "extended_hours", record.permissions then "Yes" else "No"
            R.merge (R.omit ["properties", "permissions"], record), record.properties
        , result
        json2csv {data: transformed, fields: R.keys(transformed[0])}

    lightVehicles: (result) ->
        travelDistance = {label: "travelDistance(km)", value: (row) ->
            (row.travelDistance.distance / 1000).toFixed(1)
        }
        dueTime = {label: "dueTime", value: (row) ->
            vehicleDueTime(row) ? "-"
        }
        signons = {label: "numberOfSignons", value: (row) ->
            R.length row.signons
        }
        json2csv {data: result, fields: ["date", "number", "make", "model", travelDistance, dueTime, signons]}

    projectVisits: (result) ->
        json2csv {data: result, fields: ["id", "userName", "userCompany", "userRole", "date", "arrivedAt", "departedAt"]}

    speedBands: (result) ->
        distance = {label: "Distance (km)", value: (row) ->
            if row.speedBand == 0
                "-"
            else "#{Math.round(row.speedBandDistance / 100) / 10}"
        }
        fuel = {label: "Fuel (L)", value: (row) ->
            if row.speedBand == 0
                "-"
            else "#{Math.round(row.speedBandDistance * 0.0033) / 10 }"
        }
        date = {label: "Date", value: (row) -> row.day.split(" ")[0]}
        speedBand = {label: "Speed band", value: (row) -> speedBandFromIndex(row.speedBand)}
        duration = {label: "Duration", value: (row) -> "#{Math.round(row.duration / 60)} minutes #{Math.round(row.duration / 60 / 6) / 10} hours"}
        percentage = {label: "Percentage (%)", value: (row) -> Math.round(row.percentage * 10) / 10}
        minSpeed = {label: "Min. speed (km/h)", value: (row) -> Math.round(row.minSpeed * 3.6)}
        maxSpeed = {label: "Max. speed (km/h)", value: (row) -> Math.round(row.maxSpeed * 3.6)}

        json2csv {data: result, fields: ["userName", date, "geometryName", speedBand, duration, percentage, minSpeed,
            maxSpeed, distance, fuel]}

    timeline: (result) ->
        json2csv {data: result, fields: ["type", "geometryId", "geometryName", "userId", "userName", "createdAt"]}


module.exports = class ReportPage extends pages.BasePage
    @pageId "reportPage"

    REPORTS:
        projectVisits:
            question: [
                "When did"
                {control: controls.PersonSelector, containerClass: "personContainer"}
                "arrive and depart"
                {control: controls.DateRangeSelector, containerClass: "dateContainer"}
                "?"
            ]

        areas:
            question: [
                "How long did "
                {control: controls.PersonSelector, containerClass: "personContainer"}
                "spend in"
                {control: controls.AreaSelector, containerClass: "areaContainer"}
                {control: controls.DateRangeSelector, containerClass: "dateContainer"}
                "?"
            ]
            isDynamic: true

        speedBands:
            question: [
                "What percentage of time did"
                {control: controls.PersonSelector, containerClass: "personContainer"}
                "spend in each speed band in "
                {control: controls.AreaSelector, containerClass: "areaContainer"}
                {control: controls.DateRangeSelector, containerClass: "dateContainer"}
                "?"
            ]


        timeline:
            question: [
                "What actions were recorded for "
                {control: controls.PersonSelector, containerClass: "personContainer"}
                {control: controls.DateRangeSelector, containerClass: "dateContainer"}
                "?"
            ]


        driverFitness:
            question: [
                "What sign on details were recorded for "
                {
                    control: controls.PersonSelector, containerClass: "personContainer", 
                    roleFilter: (role) -> role.properties.belongsToCor,
                    userFilter: (user) -> user.roleProperties.belongsToCor
                }
                {control: controls.DateRangeSelector, containerClass: "dateContainer"}
                "?"
            ]

        breaks:
            question: [
                "When did "
                {
                    control: controls.PersonSelector, containerClass: "personContainer"
                    roleFilter: (role) -> role.properties.belongsToCor,
                    userFilter: (user) -> user.roleProperties.belongsToCor
                }
                "take breaks "
                {control: controls.DateRangeSelector, containerClass: "dateContainer"}
                "?"
            ]
            isDynamic: true


        concreteTests:
            question: [
                "What tests were recorded "
                {control: controls.DateRangeSelector, containerClass: "dateContainer"}
                "?"
            ]

        loadCounts:
            question: [
                "What load counts were recorded for "
                {
                    control: controls.PersonSelector, containerClass: "personContainer"
                    roleFilter: (role) -> role.properties.belongsToCor,
                    userFilter: (user) -> user.roleProperties.belongsToCor
                }
                "loaded at "
                {control: controls.AreaSelector, containerClass: "loadAreaContainer", id: "loadArea"}
                "and dumped at "
                {control: controls.AreaSelector, containerClass: "dumpAreaContainer", id: "dumpArea"}
                {control: controls.DateRangeSelector, containerClass: "dateContainer"}
                "?"
            ]

        lightVehicles:
            question: [
                "What activity was recorded for "
                {control: controls.VehicleSelector, containerClass: "vehicleContainer"}
                {control: controls.DateRangeSelector, containerClass: "dateContainer"}
                "?"
            ]
            isDynamic: true

    HEADER_BUTTON: {label: "Choose report", icon: "arrow-l", target: "#selectReportPage"}
    TITLE: -> store.getState().project.name + ": " + store.getState().lastSelectedReport.label


    constructor: ->
        super

        @$el.on "popupafterclose", ".controlPopup", =>
            @loadReport @getControlValues()
        @controls = []


    getControlValues: =>
        R.reduce ((memo, control) -> R.merge memo, control.getValue()), {}, @controls


    onPageBeforeShow: =>
        super

        @setupControls()
        @loadReport @getControlValues()


    onPageHide: =>
        console.log "In #{@id} onPageHide"
        R.forEach ((control) -> control.destroy()), @controls
        @controls = []

    setupControls: ->
        Tracer.log "Setting up controls"
        container = @$(".controls").html("")

        R.forEach ((part) =>
            if typeof part == "string"
                container.append """<div class = "questionPart textPart">#{part}</div>"""
            else
                container.append """<div class = "questionPart #{part.containerClass}" style = "margin-right: 85px"></div>"""
                @controls.push new part.control @, R.omit 'control', part
            ), @REPORTS[store.getState().lastSelectedReport.url].question


    loadReport: (params) =>
        $.mobile.loading "show"
        @$(".report").html ""

        reportData = []

        allParams = R.merge params, {sessionId: store.getState().sessionId, url: store.getState().lastSelectedReport.url}
        reportLoader(allParams)
        .then (result) =>
            Tracer.log "REPORT REQUEST END", moment().format "H:mm:ss"
            reportData = R.flatten result
            reportBuilders[store.getState().lastSelectedReport.url]? reportData
        .then (reportHtml) =>
            reportEl = @$(".report").html(reportHtml)
            if @REPORTS[store.getState().lastSelectedReport.url].isDynamic
                reportEl.enhanceWithin()
            else
                # Do nothing - no jQM controls in the markup
            @$(".csvLink").click (e) =>
                csv = getReportCSV[store.getState().lastSelectedReport.url]? reportData
                link = document.createElement "a"
                link.id = "tempLink"
                document.body.appendChild link
                blob = new Blob [csv], { type: "text/csv" }
                csvUrl = window.URL.createObjectURL blob
                $("#tempLink").attr { "download": "#{store.getState().lastSelectedReport.url}.csv", "href": csvUrl }
                $("#tempLink")[0].click()
                document.body.removeChild link

        .catch (error) =>
            Tracer.log "Error generating report: ", error
            errorMessage = if error.status == 0
                "Please check your internet connection and try again.
                 If the error persists, please contact support@cloudscapelabs.com."
            else JSON.stringify error
            @$(".report").html "Could not retrieve report data from the server. #{errorMessage}"
        .finally =>
            $.mobile.loading "hide"
