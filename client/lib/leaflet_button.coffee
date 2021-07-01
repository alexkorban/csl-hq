L.Control.Button = L.Control.extend
    options:
        position: 'topright'

    initialize: (options) ->
        L.Util.setOptions(@, options)

    onAdd: (map) ->
        container = L.DomUtil.create("div", "leafletButton")
        icon = L.DomUtil.create("span", "fa " + @options.icon)
        container.appendChild(icon)
        container.addEventListener "click", @options.onClick
        container

    onRemove: (map) ->
        @._container.removeEventListener "click"
