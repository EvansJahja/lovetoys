--- Component module for creating and managing component classes.
-- Components are pure data containers that can be attached to entities.
-- This module provides utilities for creating, registering, and loading components.
--
-- @module Component
-- @usage
-- local Position = Component.create("Position", {"x", "y"}, {x = 0, y = 0})
-- local Velocity = Component.create("Velocity", {"vx", "vy"})
--
-- -- Using created components
-- local pos = Position(100, 200)
-- local vel = Velocity(5, 10)
local Component = {}

-- Getting folder that contains our src
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")

--- Table containing all registered component classes, indexed by name.
-- @table all
Component.all = {}

--- Creates a new Component class with the specified name and fields.
-- The created component class will automatically have a constructor
-- that accepts the fields as arguments in order.
-- @tparam string name The name of the component class
-- @tparam[opt] table fields Array of field names the component will have
-- @tparam[opt] table defaults Table of default values for fields, keyed by field name
-- @treturn table The newly created component class
-- @usage
-- -- Component with fields and defaults
-- local Position = Component.create("Position", {"x", "y"}, {x = 0, y = 0})
-- local pos = Position(10, 20)  -- x=10, y=20
-- local pos2 = Position()       -- x=0, y=0 (uses defaults)
--
-- -- Component without predefined fields
-- local Tag = Component.create("Tag")
function Component.create(name, fields, defaults)
    local component = require(folderOfThisFile .. 'namespace').class(name)

    if fields then
        defaults = defaults or {}
        component.initialize = function(self, ...)
            local args = {...}
            for index, field in ipairs(fields) do
                self[field] = args[index] or defaults[field]
            end
        end
    end

    Component.register(component)

    return component
end

--- Registers a component class to make it available via Component.load.
-- Components created with Component.create are automatically registered.
-- Use this to register custom component classes.
-- @tparam table componentClass The component class to register (must have a `name` property)
-- @usage
-- local MyComponent = lovetoys.class("MyComponent")
-- function MyComponent:initialize(value)
--     self.value = value
-- end
-- Component.register(MyComponent)
function Component.register(componentClass)
    Component.all[componentClass.name] = componentClass
end

--- Loads multiple registered components by name.
-- Returns the component classes as multiple return values,
-- useful for requiring several components at once.
-- @tparam table names Array of component names to load
-- @return Component classes in the order specified
-- @usage
-- local Position, Velocity, Health = Component.load({"Position", "Velocity", "Health"})
function Component.load(names)
    local components = {}

    for _, name in pairs(names) do
        components[#components+1] = Component.all[name]
    end
    return unpack(components)
end

return Component
