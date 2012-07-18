###

Gloo.coffee

Advanced MVC Framework in CoffeeScript

Dependencies:
    jQuery for HTTP requests, DOM selection, view event delegation

Copyright 2012, Vail Gold
Released under ...

Usage in JavaScript:

    var App = new Gloo(TopLevelControllerClass);

Notes:
    
    Assignment of root DOM element happens within each controller's class
    
TODO:
    
    - Abstract away storage mechanism from CRUD methods
        - Add support for localStorage

###

((window) ->

    if not Array.prototype.indexOf?
        Array.prototype.indexOf = (obj, fromIndex) ->
            if not fromIndex?
                fromIndex = 0
            else if fromIndex < 0
                fromIndex = Math.max 0, @length + fromIndex 
            for i in [fromIndex..(@length-1)]
                return i if @[i] is obj
            -1
        
    if not Array.isArray?
        Array.isArray = (o) ->
            if o? and typeof o is 'object'
                if typeof o.push is 'undefined' then false else true
            else
                false
    
    if not window.localStorage
        Object.defineProperty window, 'localStorage', new (->
            aKeys = []
            oStorage = {}
            Object.defineProperty oStorage, 'getItem',
                value: (sKey) -> if sKey then this[sKey] else null
                writable: false
                configurable: false
                enumerable: false
            Object.defineProperty oStorage, 'key',
                value: (nKeyId) -> aKeys[nKeyId]
                writable: false
                configurable: false
                enumerable: false
            Object.defineProperty oStorage, 'setItem',
                value: (sKey, sValue) ->
                    return if not sKey
                    document.cookie = escape(sKey) + '=' + escape(sValue) + '; path=/'
                writable: false
                configurable: false
                enumerable: false
            Object.defineProperty oStorage, "length",
                get: -> aKeys.length
                configurable: false
                enumerable: false
            Object.defineProperty oStorage, "removeItem",
                value: (sKey) ->
                    return if not sKey
                    sExpDate = new Date()
                    sExpDate.setDate sExpDate.getDate() - 1
                    document.cookie = escape(sKey) + '=; expires=' + sExpDate.toGMTString() + '; path=/'
                writable: false
                configurable: false
                enumerable: false
            @get = ->
                for sVal, sKey in oStorage
                    iThisIndx = aKeys.indexOf(sKey);
                    if iThisIndx is -1
                        oStorage.setItem sKey, oStorage[sKey]
                    else
                        aKeys.splice iThisIndx, 1
                    delete oStorage[sKey]
                
                while aKeys.length > 0
                    oStorage.removeItem aKeys[0]
                    aKeys.splice 0, 1
                
                iCouplId = 0
                aCouples = document.cookie.split /\s*;\s*/
                while iCouplId < aCouples.length
                    iCouple = aCouples[iCouplId].split /\s*=\s*/
                    if iCouple.length > 1
                        oStorage[iKey = unescape iCouple[0]] = unescape iCouple[1]
                        aKeys.push iKey
                    iCouplId++
                oStorage
            @configurable = false
            @enumerable = true
        )()
    
    class GlooController
        constructor: (parent, settings) ->
            throw 'MissingArgumentError' if not parent? or typeof parent isnt 'object'
            @parent = parent
            if settings? and typeof settings is 'object' and not Array.isArray settings
                @el = settings.el if settings.el? and typeof settings.el is 'object'
                @resource = settings.resource if settings.resource? and typeof settings.el is 'string'
                if settings.classes?
                    @classes =
                        model: if setting.classes?.model? then settings.classes.model else null
                        view: if setting.classes?.view? then settings.classes.view else null
                        controllers: if setting.classes?.controllers? then settings.classes.controllers else null
            if @classes.model? then @sync() else @init()
        
        ###############
        # Start Overload
        ###############
        
        # DOM element containing this controller's views
        el: null
        
        # If resource is a string, this object will use it for CRUD operations
        # It should be a URL pointing to the endpoint for creating and getting
        # this type of resource
        resource: null
        
        # Will use localStorage with a cookie-based fallback
        localStorage: false
        
        ###
        If resource is a string and localStorage is true, this controller will
        treat the resource as the primary datastore and localStorage as 
        secondary.
        ###
        
        # Names of classes for the models, views, and child controllers that
        # this controller will be managing
        classes: 
            model: null
            view: null
            controllers: []
        
        ###############
        # End Overload
        ###############
        
        # Leave these empty to start
        $el: $ @el
        parent: null
        models: []
        views: []
        controllers: []
        
        sync: =>
            @on 'syncSuccess', (json) =>
                @off('syncSuccess')
                .on('initModels', =>
                    @off('initModels').initViews().initControllers()
                )
                .initModels(json).initViews().initControllers()
            
            @trigger 'syncInit'
            
            # TODO: Use @resource and @localStorage
            @syncRemote()
            
            @
        
        syncRemote: =>
            $.ajax =>
                url: @resource
                type: 'GET'
                dataType: 'json'
                success: => @trigger 'syncSuccess', arguments
                error: => @trigger 'syncError', arguments
                complete: => @trigger 'syncComplete', arguments
        
        init: -> @initViews().initControllers()
            
        initModels: (json) ->
            if Array.isArray(json)
                for value in json
                    model = new @classes.model(@)
                    @models.push model.load value
            else
                model = new @classes.model(@)
                @models.push model.load value
        
        initViews: ->
            if @classes.view?
                if @models?
                    @views.push new @classes.view @, value.id for value in @models
                else
                    @views.push new @classes.view @
            @
                
        initControllers: ->
            if @classes.controllers?
                @controllers.push new value @ for value in @classes.controllers
            @
        
        destroyViews: ->
            view.delete() for view in @views
            @views = []
            @
        
        destroyModels: ->
            model.delete() for model in @models
            @models = []
            @
        
        destroyControllers: ->
            controller.delete() for controller in @controllers
            @controllers = []
            @
        
        sort: (sortString) ->
            # TODO
            sorts = sortString.split /\s*[,;:\/\\]\s*/g
            for s in sorts
                if s.substr -1 is '-'
                    property = s.substr 0, s.length-1
                else
                    property = s
        
        filter: () ->
            # TODO
    
        bindDOMEvent: (elem, eventString, callback) ->
            throw 'MissingArgumentError' is arguments.length < 3
            if elem.addEventListener
                elem.addEventListener eventString, callback, false
            else if elem.attachEvent
                elem.attachEvent 'on' + eventString, callback ->
                    callback.call event.srcElement, eventString
            @
            
            
        bindEvent: (element, event, namespace, callback) ->
            throw MissingArgumentError is arguments.length < 4
            namespace = ' ' if namespace is null or typeof namespace isnt 'string' or namespace.length is 0
            @bindEventToDOM @el, event, callback if @eventIsSupported event
            @events[namespace][event].push element: element, callback: callback
            @
        
        off: (eventString) ->
            throw 'InvalidArgumentError' if not eventString? or typeof eventString isnt 'string'
            events = eventString.split(/\s+/g)
            for e in events
                if e.indexOf('.') > -1
                    temp = e.split('.')
                    event = temp[0]
                    namespace = temp[1]
                else
                    event = e
                    namespace = null
                @unbindEvent @el, event, namespace
            @
       
        on: (eventString, callback) ->
            throw 'MissingPropertyValueError' if not @el? or typeof @el.innerHTML isnt 'string'
            throw 'InvalidArgumentError' if not eventString? or typeof eventString isnt 'string'
            throw 'InvalidArgumentError'if not callback? or typeof callback isnt 'function'
            events = eventString.split(/\s+/g)
            for e in events
                if e.indexOf('.') > -1
                    temp = e.split('.')
                    event = temp[0]
                    namespace = temp[1]
                else
                    event = e
                    namespace = null
                @bindEvent @el, event, namespace, callback
            @
        
        trigger: (eventString, args) ->
            throw 'MissingPropertyValueError' if not @el? or typeof @el.innerHTML isnt 'string'
            throw 'MissingArgumentError' if not eventString? or typeof eventString isnt 'string'
            events = eventString.split(/\s+/g)
            for e in events
                if e.indexOf '.' > -1
                    temp = e.split '.'
                    event = temp[0]
                    namespace = temp[1]
                else
                    event = e
                    namespace = null
                if namespace is null or typeof namespace isnt 'string' or namespace.length is 0
                    namespace = ' '
                if @events[namespace]?[event]?.length > 0
                    for obj in @events[namespace][event]
                        if obj.callback? and typeof obj.callback is 'function'
                            obj.callback.apply @, if args? then args else null
            @
        
        unbindDOMEvent: (elem, eventString, callback) ->
            throw 'MissingArgumentError' is arguments.length < 3
            if elem.removeEventListener
                elem.removeEventListener eventString, callback, false
            else if elem.detachEvent
                elem.detachEvent 'on' + eventString, callback ->
                    callback.call event.srcElement, eventString
            @
        
        unbindEvent: (element, event, namespace) ->
            throw 'MissingArgumentError' is arguments.length < 3
            if namespace is null or typeof namespace isnt 'string' or namespace.length is 0
                namespace = ' '
            if @eventIsSupported event
                for obj in @events[namespace][event]
                    @bindDOMEvent @el, event, obj.callback
            @events[namespace][event] = []
            @
        
    
    class GlooModel extends GlooCore
        constructor: (controller) ->
            throw 'MissingArgumentError' if not parent? or typeof parent isnt 'object'
            @controller = controller
            @
        
        ###############
        # Start Overload
        ###############
        
        id: null
        resource: null
            
        ###############
        # End Overload
        ###############
        
        controller: null
        trigger: @controller.trigger
        'deleted': false
        read: false
        updated: false
        
        #
        # TODO: Abstract away storage mechanism from read, update, delete methods,
        # and provide a property to specify mechanism. Support localStorage and
        # WebSockets?
        #
        
        'delete': =>
            @deleted = false
            $.ajax =>
                url: @resource
                type: 'DELETE'
                success: =>
                    @deleted = true
                    delete @_properties
                    @trigger 'deleteSuccess', arguments
                error: =>
                    @deleted = false
                    @trigger 'deleteError', arguments
                complete: =>
                    @trigger 'deleteComplete', arguments
            @trigger 'deleteInit'
            
        read: =>
            @read = false
            $.ajax =>
                url: @resource
                type: 'GET'
                dataType: 'json'
                success: =>
                    @read = true
                    @load(json).trigger 'readSuccess', arguments
                error: =>
                    @read = false
                    @trigger 'readError', arguments
                complete: =>
                    @trigger 'readComplete', arguments
            @trigger 'readInit'
            
        update: =>
            @updated = false
            $.ajax =>
                url: @resource
                type: 'PUT'
                data: @_properties
                success: =>
                    @updated = true
                    @trigger 'updateSuccess', arguments
                error: =>
                    @updated = false
                    @trigger 'updateError', arguments
                complete: =>
                    @trigger 'updateComplete', arguments
            @trigger 'updateInit'
    
        eventIsSupported: (eventName) ->
            TAGNAMES =
                'select':'input', 'change':'input', 'submit':'form', 'reset':'form'
                'error':'img', 'load':'img', 'abort':'img'
            el = document.createElement(TAGNAMES[eventName] || 'div')
            eventName = 'on' + eventName
            isSupported = (eventName in el)
            if not isSupported
                el.setAttribute eventName, 'return;'
                isSupported = typeof el[eventName] is 'function'
            el = null
            isSupported
            
        get: (property) ->
            throw 'MissingArgumentError' if not property?
            throw 'InvalidArgumentError' if typeof property isnt 'string'
            throw 'InvalidPropertyStringError' if property.search @propertyRegex is -1
            @_properties[property]
       
        has: (property) -> @get(property)?
        
        load: (json) ->
            throw 'MissingArgumentError' if not json?
            throw 'InvalidArgumentError' if typeof json isnt 'object' or Array.isArray(json) or json.length is 0
            for value, key in json
                throw 'InvalidPropertyStringError' if key.search @propertyRegex is -1
                @_properties[key] = value
            @trigger 'load'
        
        propertyRegex: /^[\$a-z_]{1}[\$a-z0-9_]*$/i
        
        set: (property, value) ->
            throw 'MissingArgumentError' if arguments.length < 2
            throw 'InvalidArgumentError' if typeof property isnt 'string'
            throw 'InvalidPropertyStringError' if property.search @propertyRegex is -1
            if @_properties[property] = value then @trigger 'update' else @
        
        setAttributes: (json) ->
            throw 'MissingArgumentError' if not json?
            throw 'InvalidArgumentError' if typeof json isnt 'object' or Array.isArray(json) or json.length is 0
            updated = false
            for value, key in json
                throw 'InvalidPropertyStringError' if key.search @propertyRegex is -1
                @_properties[key] = value
                updated = true
            if updated then @trigger 'update' else @
        
        unset: (property) ->
            throw 'MissingArgumentError' if not property?
            throw 'InvalidArgumentError' if typeof property isnt 'string'
            throw 'InvalidPropertyStringError' if property.search @propertyRegex is -1
            if delete @_properties[property] then @trigger 'update' else @
    
    
    class GlooView extends GlooCore
        constructor: (controller, modelID) ->
            throw 'MissingArgumentError' if not controller? or typeof controller isnt 'object'
            @controller = controller
            @modelID = modelID if modelID?
            @render().initEvents()
        
        ###############
        # Start Overload
        ###############
        
        # String of class names, separated by spaces
        className: ''
        
        ###
        An array of objects with 4 properties: selector, event, namespace,
        and callback. selector and namespace is optional. selector will be
        scoped within the view's parent element.
        Ex:
        {
            # Required
            event: 'click' # String
            callback: -> true # Function
            
            # Optional
            selector: '.items' # String
            namespace: 'selection' # String
        }
        ###
        events: []
        
        ###############
        # End Overload
        ###############
        
        @modelID: null
        
        initEvents: ->
            for obj in @events
                namespaceString = ''
                if obj.namespace? and typeof obj.namespace is 'string'
                    namespaceString = '.' + obj.namespace
                eventString = obj.event + namespaceString
                if obj.selector? and typeof obj.selector is 'string'
                    @controller.$el.on eventString, selector, callback
                else
                    @controller.on eventString, callback
            @
        
        removeEvents: ->
            for obj in @events
                eventString = obj.event + (if obj.namespace? then '.' + namespace else '')
                if obj.selector?
                    @controller.$el.off eventString, selector, callback
                else
                    @controller.off eventString, callback
            @
        
        render: ->
            @$el.addClass(@className).empty().append @template() if @validate()
            @
        
        resetEvents: -> @removeEvents().initEvents()
        
        template: ->
            # TODO: Return a rendered template
            
        
        validate: ->
            @el? and typeof @el is 'object' and typeof @el.innerHTML is 'string'
    
    
    class Gloo
        constructor: (ControllerClass) ->
            throw 'MissingArgumentError' if not ControllerClass?
            @app = new ControllerClass(@)
        Model: GlooModel
        View: GlooView
        Controller: GlooController
    
    window.Gloo = Gloo

)(window)






















