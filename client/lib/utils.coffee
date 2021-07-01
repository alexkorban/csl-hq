window.loadScript = (src) ->
    script = document.createElement "script"
    script.src = src
    ($ "body")[0].appendChild script


# mixin: instance methods
window.extend = (obj, mixin) ->
    for name, method of mixin
        obj[name] = method


# mixin: class methods
window.include = (klass, mixin) ->
    extend klass.prototype, mixin


# Add functions to Storage/localStorage
Storage::set = (key, value) ->
    @setItem key, JSON.stringify value


Storage::get = (key) ->
    try
        (JSON.parse @getItem key) || undefined
    catch e
        alert "Error in " + key + ": " + @getItem key


Storage::dump = ->
    h = {}
    for i in [0...@length]
        h[@key i] = @get @key i
    h


# Clamp x to [a, b]
window.clamp = (a, b, x) => Math.max(a, Math.min(x, b))


# Area / Distance methods for geometry layers
window.measure = (geoJSON) ->
    switch geoJSON.geometry.type
        when "Polygon"
            area = turf.area geoJSON
            units = "m<sup>2</sup>"
            if area > 10000
                units = "ha"
                area /= 10000
            {description: "Area of geometry", amount: area.toFixed(2) + " " + units}
        when "LineString"
            distance = turf.lineDistance geoJSON
            units = "km"
            if distance < 1
                units = "m"
                distance *= 1000
            {description: "Length of line", amount: distance.toFixed(2) + " " + units}
        else undefined


window.isEmail = (email) ->
    re = /// ^(
        ([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))\@
        ((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,})
    )$ ///
    re.test email

    
window.formattedDuration = (milliseconds) ->
    dur = moment.duration(milliseconds)
    hours = dur.hours()
    if hours == 0
        "#{dur.minutes()} min"
    else
        "#{hours} h #{Math.abs dur.minutes()} min"
