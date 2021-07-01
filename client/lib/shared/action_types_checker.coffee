###
    This block will check the uniqueness of the actions types.
    It relies on the current structure: leaf values are always functions, the rest is always an object,
    when evaluated leaf function will always give an object with "type" key.
###
module.exports = (actions) ->
    extractTypes = (startObject) ->
        R.map (node) =>
            if (typeof node) == "function"
                node({}).type
            else
                extractTypes node
        , R.values startObject

    R.filter (typeCount) ->
        typeCount > 1
    , R.countBy(R.identity, R.flatten extractTypes actions)
