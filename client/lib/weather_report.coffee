create = (map) =>
    L.Control.LeafletWeatherControl = L.Control.extend
        options:
            position: "bottomright"
        onAdd: (map) ->
            L.DomUtil.create "div", "weatherReport"

    control = new L.Control.LeafletWeatherControl
    control.addTo map


redraw = (weather) =>
    Tracer.log "Drawing weather"
    htmlContent = if !R.isEmpty weather
        windDir =
            if weather.windSpeed > 0
                dir = weather.windDir.toLowerCase()
                "wiIcon wi wi-wind wi-from-#{dir}"
            else
                "fa fa-circle-o"

        windSpeed =
            if weather.windSpeed >= 0 then Math.round weather.windSpeed else "?"

        airTemp = if weather.airTemp > -100 then Math.round weather.airTemp else "?"

        noPressure = if weather.pressure < 0 then "style='display: none;'" else ""

        pressureTend =
            if weather.pressTend > 0
                "up"
            else if weather.pressTend < 0
                "down"
            else ""

        noPressureChange = if weather.pressTend == 0 then "|" else ""

        pressure = if weather.pressure >= 0 then Math.round weather.pressure else "?"

        rain = if weather.rainTrace >= 0 then Math.round weather.rainTrace else "?"

        """
            <a href = #{weather.properties.weatherRadarUrl} target="_blank">
                <table>
                    <tr>
                        <td style="text-align: center;"><i class="wi wi-thermometer"></i></td>
                        <td> #{airTemp}&deg C</td>
                    </tr>
                    <tr>
                        <td style="text-align: center;"><i class="#{windDir}"></i></td>
                        <td>#{windSpeed} km/h</td>
                    </tr>
                    <tr #{noPressure}>
                        <td style="text-align: center;"><i class="wiIcon wi wi-direction-#{pressureTend}">#{noPressureChange}</i></td>
                        <td>#{pressure} hPa</td>
                    </tr>
                    <tr>
                        <td style="text-align: center;"><i class="wiIcon wi wi-raindrop"></i></td>
                        <td>#{rain} mm</td>
                    </tr>
                </table>
            </a>
        """
    else ""

    $(".weatherReport").html(htmlContent).enhanceWithin()

module.exports =
    create: create
    redraw: redraw

