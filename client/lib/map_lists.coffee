class GeometryList
    constructor: (options) ->
        {@layers, @$el} = options

        @$(".geometryList").on "mouseenter", ".geoItem", (e) =>
            @layerStyleHighlight @findLayer $(e.target).closest ".geoItem"

        @$(".geometryList").on "mouseleave", ".geoItem", (e) =>
            @layerStyleRestore @findLayer $(e.target).closest ".geoItem"

        R.forEach ((layer) =>
            layer.on "mouseover", (e) => @layerStyleHighlight layer
            layer.on "mouseout", (e) => @layerStyleRestore layer
        ), @layers


    $: (selector) =>
        @$el.find selector


    layerStyleHighlight: (layer) ->
        if layer instanceof L.Marker
            layer.setOpacity 0.5
        else
            layer.setStyle color: "#f90"


    layerStyleRestore: (layer) ->
        if layer instanceof L.Marker
            layer.setOpacity 1.0
        else
            layer.setStyle color: layer.style.color


    findLayer: (target) =>
        R.find R.propEq("id", parseInt target.attr("data-id")), @layers


    destroy: =>
        @$(".geometryList").html("").hide().off "mouseenter mouseleave click"
        R.forEach ((layer) =>
            @layerStyleRestore layer
            layer.off "mouseover mouseout"
        ), @layers



class GeometryEditList extends GeometryList
    constructor: (options) ->
        super

        listItems = R.map ((layer) => """
            <li data-icon="false"><a class="geoItem" data-id="#{layer.id}">#{layer.name}</a></li>
        """)
        , @layers

        @$(".geometryList").html """<ul data-role="listview">#{listItems.join "\n"}</ul>"""
        .enhanceWithin()
        .show()

        @$(".geoItem").on "click", (e) =>
            layer = @findLayer $(e.target).closest ".geoItem"

            onSaveButton = (e) =>
                Tracer.log "Popup save button"
                @$(".geometryList").find("[data-id=" + layer.id + "]")
                    .html layer.name
                    .buttonMarkup
                        icon: "edit"
                        iconpos: "right"
                $(this).off "input"

            new controls.GeometryForm
                layer: layer
                saveHandler: onSaveButton




class GeometryDeleteList extends GeometryList
    constructor: (options) ->
        super

        listItems = R.map ((layer) => """
            <li data-icon="delete"><a class="geoItem" data-id="#{layer.id}">#{layer.name}</a></li>
        """)
        , @layers

        @$(".geometryList").html """<ul data-role="listview">#{listItems.join "\n"}</ul>"""
        .enhanceWithin()
        .show()

        @$(".geometryList").on "click", ".geoItem", (e) =>
            layer = @findLayer $(e.target).closest ".geoItem"

            #HACK: invokes internal LeafletDraw handler to remove layer
            for key, toolbar of layer._map.draw._toolbars
                toolbar._modes.remove?.handler._removeLayer layer

            @$(e.target).addClass "ui-state-disabled"
                        .removeClass "ui-btn-icon-right"

        R.forEach ((layer) => layer.on "click", (e) =>
            @$(".geometryList").find("[data-id=#{e.target.id}]").addClass "ui-state-disabled"
                                                                .removeClass "ui-btn-icon-right"
        ), @layers


    destroy: =>
        super
        #TODO: unsubscribe delete click only, keep popup click
        R.forEach ((layer) => layer.off "click"), @layers



module.exports =
    GeometryEditList: GeometryEditList
    GeometryDeleteList: GeometryDeleteList
