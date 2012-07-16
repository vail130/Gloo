###

Gloo.coffee

Advanced MVC Framework in CoffeeScript

Dependencies:
    jQuery for HTTP requests and DOM selection

Copyright 2012, Vail Gold
Released under ...

Usage in JavaScript:

    var App = new Gloo(TopLevelControllerClass);

###

if not Array.prototype.indexOf?
    Array.prototype.indexOf = (obj, fromIndex) ->
        if not fromIndex?
            fromIndex = 0
        else if fromIndex < 0
            fromIndex = Math.max 0, @length + fromIndex 
        for i in [fromIndex..(@length-1)]
            return i if @[i] is obj
        -1
    
if not Array.prototype.isArray?
    Array.prototype.isArray = (o) ->
        if o? and typeof o is 'object'
            if typeof o.push is 'undefined' then false else true
        else
            false

class GlooController
    constructor: (parent) ->
        throw 'MissingArgumentError' if not parent? or typeof parent isnt 'object'
        @parent = parent
        if @classes.model? then @sync() else @init()
    
    ###############
    # Start Overload
    ###############
    
    # DOM element containing this controller's views
    el: null
    
    # URL for creating and getting this resource
    resource: null
    
    # Names of classes for the models, views, and child controllers that this
    # controller will be managing
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
        $.ajax =>
            url: @resource
            type: 'GET'
            dataType: 'json'
            success: => @trigger 'syncSuccess', arguments
            error: => @trigger 'syncError', arguments
            complete: => @trigger 'syncComplete', arguments
        @
    
    init: -> @initViews().initControllers()
        
    initModels: (json) ->
        if json.isArray? and typeof json.isArray is 'function'
            for value in json
                model = new @classes.model(@)
                @models.push model.load value
        else
            model = new @classes.model(@)
            @models.push model.load value
            
    
    initViews: ->
        @views.push new @classes.view(@, value.id) for value in @models
        @
            
    initControllers: ->
        @controllers.push new value(@) for value in @classes.controllers
        @
    
    destroyViews: ->
        view.delete() for view in @views
        @views = []
        @
    
    destroyModels: ->
        model.delete() for model in @models
        @models = []
        @
    
    destroyController: ->
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
        throw 'InvalidArgumentError' if typeof json isnt 'object' or json.isArray? or json.length is 0
        for value, key in json
            throw 'InvalidPropertyStringError' if key.search @propertyRegex is -1
            @_properties[key] = value
        @trigger 'load'
    
    propertyRegex: /^[\$a-z_]{1}[\$a-z0-9_]*$/i
    
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
        
    set: (property, value) ->
        throw 'MissingArgumentError' if arguments.length < 2
        throw 'InvalidArgumentError' if typeof property isnt 'string'
        throw 'InvalidPropertyStringError' if property.search @propertyRegex is -1
        if @_properties[property] = value then @trigger 'update' else @
    
    setAttributes: (json) ->
        throw 'MissingArgumentError' if not json?
        throw 'InvalidArgumentError' if typeof json isnt 'object' or json.isArray? or json.length is 0
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


class GlooView extends GlooCore
    constructor: (controller, modelID) ->
        throw 'MissingArgumentError' if not controller? or typeof controller isnt 'object'
        @controller = controller
        @modelID = modelID
        @render().initEvents()
    
    ###############
    # Start Overload
    ###############
    
    className: ''
    events:
        ###
        An object with key-value pairs. Keys should be event strings,
        composed of the name of the event and an optional period and
        namespace. Values should be the instance method to run as a callback
        of the event.
        
        Ex: 'event.namespace': @callback
        
        ###
        null
        
    ###############
    # End Overload
    ###############
    
    @modelID: null
    
    initEvents: ->
        @controller.on eventString, callback for callback, eventString in @events
        @
    
    removeEvents: ->
        @controller.off eventString for callback, eventString in @events
        @
    
    render: ->
        @$el.empty().append @template() if @validate()
        @
    
    resetEvents: -> @removeEvents().initEvents()
    
    template: ->
        # TODO: Return a rendered template
        
    
    validate: ->
        @el? and typeof @el is 'object' and typeof @el.innerHTML is 'string'


class Gloo
    constructor: (ControllerClass) ->
        throw MissingArgumentError if not ControllerClass?
        @app = new ControllerClass(@)
    Model: GlooModel
    View: GlooView
    Controller: GlooController
    Collection: GlooCollection
























