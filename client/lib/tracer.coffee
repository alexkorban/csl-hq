module.exports = class Tracer
    @nativeCodeEx: /\[native code\]/
    @indentCount: 0
    @tracedFuncs: []

    @jqTrace: ->
        originalOn = $.fn.on
        instrumentedOn = (types, selector, data, fn, one) ->
            if typeof types == "object"
                return originalOn.apply @, arguments
            if !fn.displayName?
                fn = Tracer.traceFunc fn, "callback: #{types}/#{selector}"
            originalOn.apply @, types, selector, data, fn, one
        $.fn.on = instrumentedOn


    @indent: ->
        if @indentCount > 0
            Array(@indentCount + 1).join "    "
        else
            ""

    @log: (str, args...) ->
        if typeof str == "string"
            console.log Tracer.indent() + str, args...
        else
            console.log Tracer.indent(), args...


    @traceFunc: (func, methodName) ->
        instrumentedFunc = ->
            #console.group methodName + '(', (Array.prototype.slice.call arguments), ')'
            #console.log "#{Tracer.indent()}Indent count: #{Tracer.indentCount}"
            console.log "#{Tracer.indent()}-> #{methodName}(", (Array.prototype.slice.call arguments)..., ")"
            Tracer.indentCount += 1
            startTime = moment()
            result = func.apply @, arguments
            console.info "#{Tracer.indent()}<- ", result, "(#{moment() - startTime} ms)"
            #console.groupEnd()
            Tracer.indentCount -= 1
            result

        instrumentedFunc.originalFunc = func
        instrumentedFunc.displayName = methodName
        for prop in func
            instrumentedFunc[prop] = func[prop]
        instrumentedFunc


    @traceObject: (root, recurse) ->
        if root == window || typeof root != 'object' || typeof root == 'function'
            return

        for key of root
            if (root.hasOwnProperty key) && root[key] != root
                thisObj = root[key]
            if typeof thisObj == 'function' && @ != root && !thisObj.originalFunc && !@nativeCodeEx.test thisObj
                root[key] = @traceFunc root[key], key
                @tracedFuncs.push {obj: root, methodName: key}

            if recurse
                @traceAll thisObj, true


    @traceAll: (obj, recurse) ->
        return
        @traceObject obj, recurse # instance methods
        @traceObject obj.prototype, recurse  # class methods


    @untraceAll: ->
        for thisTracing in @tracedFuncs
            thisTracing.obj[thisTracing.methodName] = thisTracing.obj[thisTracing.methodName].originalFunc

        console.log "tracing disabled"
        @tracedFuncs = []

