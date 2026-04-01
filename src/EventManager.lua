--- EventManager class for publish-subscribe event handling.
-- Allows objects to subscribe to events and receive notifications when
-- those events are fired. Used internally by the Engine for component
-- change events, but can also be used for custom game events.
--
-- @classmod EventManager
-- @usage
-- local eventManager = EventManager()
--
-- -- Create a listener object
-- local listener = lovetoys.class("MyListener")()
-- function listener:onPlayerDied(event)
--     print("Player died: " .. event.playerName)
-- end
--
-- -- Subscribe to event
-- eventManager:addListener("PlayerDied", listener, listener.onPlayerDied)
--
-- -- Fire event
-- local event = PlayerDiedEvent("Hero")
-- eventManager:fireEvent(event)

-- Getting folder that contains our src
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")

local lovetoys = require(folderOfThisFile .. 'namespace')
local EventManager = lovetoys.class("EventManager")

--- Creates a new EventManager instance.
function EventManager:initialize()
    --- Table of event listeners, keyed by event name.
    -- Each entry is an array of {listener, function} pairs.
    -- @field eventListeners
    self.eventListeners = {}
end

--- Adds a listener for a specific event type.
-- The listener object must have a `class.name` field for identification.
-- Each class can only have one listener per event type.
-- @tparam string eventName The name of the event to listen for (typically the event class name)
-- @tparam table listener The listener object (must have listener.class.name)
-- @tparam function listenerFunction The function to call when the event fires
-- @usage
-- eventManager:addListener("ComponentAdded", mySystem, mySystem.onComponentAdded)
function EventManager:addListener(eventName, listener, listenerFunction)
    -- If there's no list for this event, we create a new one
    if not self.eventListeners[eventName] then
        self.eventListeners[eventName] = {}
    end




    if not listener.class or (listener.class and not listener.class.name) then
        lovetoys.debug('Eventmanager: The listener has to implement a listener.class.name field.')
    end

    for _, registeredListener in pairs(self.eventListeners[eventName]) do
        if registeredListener[1].class == listener.class then
            lovetoys.debug(
                string.format("Eventmanager: EventListener for {} already exists.", eventName))
            return
        end
    end
    if type(listenerFunction) == 'function' then
        table.insert(self.eventListeners[eventName], {listener, listenerFunction})
    else
        lovetoys.debug('Eventmanager: Third parameter has to be a function! Please check listener for ' .. eventName)
        if listener.class and listener.class.name then
            lovetoys.debug('Eventmanager: Listener class name: ' .. listener.class.name)
        end
    end
end

--- Removes a listener from an event.
-- @tparam string eventName The name of the event
-- @tparam string listener The class name of the listener to remove
-- @usage
-- eventManager:removeListener("ComponentAdded", "MovementSystem")
function EventManager:removeListener(eventName, listener)
    if self.eventListeners[eventName] then
        for key, registeredListener in pairs(self.eventListeners[eventName]) do
            if registeredListener[1].class.name == listener then
                table.remove(self.eventListeners[eventName], key)
                return
            end
        end
        lovetoys.debug(string.format("Eventmanager: Listener %s to be deleted on Event %s  is not existing.", listener.class.name, eventName))
    end
    lovetoys.debug(string.format("Eventmanager: Event %s listener should be removed from is not existing ", eventName))
end

--- Fires an event to all registered listeners.
-- All listeners subscribed to this event type will have their callback invoked.
-- @tparam table event The event instance to fire (must have event.class.name)
-- @usage
-- local event = ComponentAdded(entity, "Position")
-- eventManager:fireEvent(event)
function EventManager:fireEvent(event)
    local name = event.class.name
    if self.eventListeners[name] then
        for _,listener in pairs(self.eventListeners[name]) do
            listener[2](listener[1], event)
        end
    end
end

return EventManager
