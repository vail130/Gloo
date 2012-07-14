###

Gloo.coffee

Advanced MVC Framework in CoffeeScript

Copyright 2012, Vail Gold
Released under ...

Usage in JavaScript

    var App = new Gloo(TopLevelControllerClass)
    App.app.run({
        model: ModelClassName,
        view: ViewClassName,
        controllers: {
            ChildControllerClassName1: ChildControllerClassName1,
            ChildControllerClassName2: ChildControllerClassName2,
            ChildControllerClassName3: ChildControllerClassName3
        }
    })

###

if not Array.prototype.indexOf
    Array.prototype.indexOf = (obj, fromIndex) ->
        if not fromIndex?
            fromIndex = 0
        else if fromIndex < 0
            fromIndex = Math.max 0, @length + fromIndex 
        for i in [fromIndex..(@length-1)]
            return i if @[i] is obj
        -1
        
class GlooController
    constructor: (parent) ->
        ###
        # To extend this class, do the following:
        @classes =
            model: null
            view: null
            controllers: null
        super
        ###
        throw MissingArgumentError if not parent? or typeof parent isnt 'object'
        @parent = parent
        @model = new @classes.model() if @classes.model?
        @view = new @classes.view() if @classes.view?
        if @classes.controllers?.length > 0
            for value, key in @classes.controllers
                @controllers[key] = new @classes.controllers[key]()
        @
        
    resetView: ->
        @view.destroy()
        @view = new @classes.view()

    resetModel: ->
        @model.destroy()
        @model = new @classes.model()

    bindDOMEvent: (el, event, callback) ->
        if elem.addEventListener
            elem.addEventListener event, callback, false
        else if elem.attachEvent
            elem.attachEvent 'on' + event, ->
                callback.call event.srcElement, event
        
    bindEvent: (element, event, namespace, callback) ->
        throw MissingArgumentError is arguments.length < 4
        if namespace is null or typeof namespace isnt 'string' or namespace.length is 0
            namespace = ' '
        if @eventIsSupported event
            @bindEventToDOM @el, event, callback
        @events[namespace][event].push
            element: element
            callback: callback
        @
    
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
        
    get: (property) -> @[property]
   
    has: (property) -> @get(property)?
    
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
    
    set: (property, value) ->
        @[property] = value
        @trigger 'update'
    
    setAttributes: (hashmap) ->
        throw 'MissingArgumentError' if not hashmap? or typeof hashmap isnt 'object'
        for value, key in hashmap
            @[key] = value
        @
    
    trigger: (eventString) ->
        throw 'MissingPropertyValueError' if not @el? or typeof @el.innerHTML isnt 'string'
        events = eventString.split(/\s+/g)
        for e in events
            if e.indexOf('.') > -1
                temp = e.split('.')
                event = temp[0]
                namespace = temp[1]
            else
                event = e
                namespace = null
            if namespace is null or typeof namespace isnt 'string' or namespace.length is 0
                namespace = ' '
            if @events[namespace]?[event]?['callback']? and @events[namespace][event].length > 0
                for obj in @events[namespace][event]
                    obj.callback()
            @
    
    unbindDOMEvent: (elem, event, callback) ->
        if elem.removeEventListener
            elem.removeEventListener event, callback, false
        else if elem.detachEvent
            elem.detachEvent 'on' + event, callback
    
    unbindEvent: (element, event, namespace) ->
        throw MissingArgumentError is arguments.length < 4
        if namespace is null or typeof namespace isnt 'string' or namespace.length is 0
            namespace = ' '
        if @eventIsSupported event
            for obj in @events[namespace][event]
                @bindDOMEvent @el, event, obj.callback
        @events[namespace][event] = []
        @
    
    unset: (property) ->
        delete @[property]
        @trigger 'update'


class GlooModel
    constructor: (controller) ->
        throw MissingArgumentError if not parent? or typeof parent isnt 'object'
        @controller = controller
        @saved = false
        @destroyed = false
    
    destroy: =>
        $.ajax =>
            url: @saveURL
            type: 'DELETE'
            success: =>
                @destroyed = true
                @trigger 'destroyComplete'
        @trigger 'destroyInit'
        
    save: (method) =>
        $.ajax =>
            url: @saveURL
            type: 'PUT'
            dataType: 'json'
            data: @keys
            success: =>
                @saved = true
                @trigger 'saveComplete'
        @trigger 'saveInit'
        
    toJSON: -> JSON.stringify(@keys)


class GlooView
    constructor: (controller) ->
        throw MissingArgumentError if not parent? or typeof parent isnt 'object'
        @controller = controller
        @el = null
        @initEvents()
    
    initEvents: ->
        
    
    validate: ->
        @el? and typeof @el is 'object' and typeof @el.innerHTML is 'string'
    
    template: ''
    
class Gloo
    constructor: (ControllerClass) ->
        throw MissingArgumentError if not ControllerClass?
        @app = new ControllerClass(@)
    Model: GlooModel
    View: GlooView
    Controller: GlooController