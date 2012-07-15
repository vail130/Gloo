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

if not Array.prototype.indexOf
    Array.prototype.indexOf = (obj, fromIndex) ->
        if not fromIndex?
            fromIndex = 0
        else if fromIndex < 0
            fromIndex = Math.max 0, @length + fromIndex 
        for i in [fromIndex..(@length-1)]
            return i if @[i] is obj
        -1

class GlooCore
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
    
    propertyRegex: /^[\$a-z_]{1}[\$a-z0-9_]*$/i
    
    set: (property, value) ->
        throw 'MissingArgumentError' if arguments.length < 2
        throw 'InvalidArgumentError' if typeof property isnt 'string'
        throw 'InvalidPropertyStringError' if property.search @propertyRegex is -1
        if @_properties[property] = value then @trigger 'update' else @
    
    setPropertiesFromJSON: (json) ->
        throw 'MissingArgumentError' if not json?
        throw 'InvalidArgumentError' if typeof json isnt 'object' or json.length is 0
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


class GlooController extends GlooCore
    ###
    To extend this class, update @setClasses
    ###
    constructor: (parent) ->
        throw MissingArgumentError if not parent? or typeof parent isnt 'object'
        @parent = parent
        @model = if @classes.model? then new @classes.model() else null 
        @collection = if @classes.collection? then new @classes.collection() else null 
        @view = if @classes.view? then new @classes.view() else null
        if @classes.controllers?.length > 0
            for value, key in @classes.controllers
                throw 'InvalidPropertyStringError' if key.search @propertyRegex is -1
                @controllers[key] = new @classes.controllers[key]()
        @trigger 'create'
    
    setClasses: ->
        @classes =
            model: null
            collection: null
            view: null
            controllers: null
        @
        
    resetView: ->
        @view.delete()
        @view = new @classes.view()
        @

    resetModel: ->
        @model.delete()
        @model = new @classes.model()
        @

    resetCollection: ->
        @collection.delete()
        @collection = new @classes.collection()
        @

    bindDOMEvent: (elem, eventString, callback) ->
        throw 'MissingArgumentError' is arguments.length < 3
        if elem.addEventListener
            elem.addEventListener eventString, callback, false
        else if elem.attachEvent
            elem.attachEvent 'on' + eventString, callback ->
                callback.call event.srcElement, eventString
        
        
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
        @read()
    
    created: false
    'deleted': false
    read: false
    updated: false
    
    id: null
    
    resources:
        ###
        URL paths to resources by intent
        create: 'URL/api/resources'
        delete: 'URL/api/resources/' + @id
        ###
        create: null
        'delete': null
        read: null
        update: null
        
    controller: null
    
    trigger: @controller.trigger
    
    create: =>
        @created = false
        $.ajax =>
            url: @resources.create
            type: 'POST'
            dataType: 'json'
            data: @_properties
            success: (json) =>
                #
                # TODO: Include optional, custom validation
                #
                if json?.id?
                    @created = true
                    @id = json.id
                @trigger 'createSuccess', arguments
            error: =>
                @created = false
                @trigger 'createError', arguments
            complete: =>
                @trigger 'createComplete', arguments
        @trigger 'createInit'
        
    'delete': =>
        @deleted = false
        $.ajax =>
            url: @resources.delete
            type: 'DELETE'
            success: =>
                #
                # TODO: Include optional, custom validation
                #
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
            url: @resources.read
            type: 'GET'
            dataType: 'json'
            success: (json) =>
                #
                # TODO: Include optional, custom validation
                #
                @read = true
                @setPropertiesFromJSON(json)
                .trigger 'readSuccess', arguments
            error: =>
                @read = false
                @trigger 'readError', arguments
            complete: =>
                @trigger 'readComplete', arguments
        @trigger 'readInit'
        
    update: =>
        @updated = false
        $.ajax =>
            url: @resources.update
            type: 'PUT'
            data: @_properties
            success: =>
                #
                # TODO: Include optional, custom validation
                #
                @updated = true
                @trigger 'updateSuccess', arguments
            error: =>
                @updated = false
                @trigger 'updateError', arguments
            complete: =>
                @trigger 'updateComplete', arguments
        @trigger 'updateInit'


class GlooView extends GlooCore
    constructor: (controller) ->
        throw 'MissingArgumentError' if not controller? or typeof controller isnt 'object'
        @controller = controller
        @render().initEvents()
    
    el: null
    
    $el: $? @el if @el
    
    events:
        ###
        An object with key-value pairs. Keys should be event strings,
        composed of the name of the event and an optional period and
        namespace. Values should be the instance method to run as a callback
        of the event.
        
        Ex: 'event.namespace': @callback
        
        ###
        null
        
    
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


class GlooCollection extends GlooCore
    constructor: (controller) ->
        throw 'MissingArgumentError' if not parent? or typeof parent isnt 'object'
        @controller = controller
        @read()
    
    # TODO: Figure out how the hell to let a controller manage multiple
    # models of the same class
    
class Gloo
    constructor: (ControllerClass) ->
        throw MissingArgumentError if not ControllerClass?
        @app = new ControllerClass(@)
    Model: GlooModel
    View: GlooView
    Controller: GlooController
    Collection: GlooCollection
























