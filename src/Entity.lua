--- Entity class representing a game object in the ECS.
-- An Entity is a container for components and can have parent-child relationships
-- with other entities. Entities must be added to an Engine to participate in systems.
--
-- @classmod Entity
-- @usage
-- local entity = Entity(nil, "player")
-- entity:add(Position(100, 200))
-- entity:add(Velocity(0, 0))
-- engine:addEntity(entity)

-- Getting folder that contains our src
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")

local lovetoys = require(folderOfThisFile .. 'namespace')
local Entity = lovetoys.class("Entity")

--- Creates a new Entity.
-- @tparam[opt=nil] Entity parent Parent entity for hierarchy
-- @tparam[opt=nil] string name Optional name for the entity
-- @usage
-- local entity = Entity()
-- local childEntity = Entity(parentEntity, "child")
function Entity:initialize(parent, name)
    --- Table of components attached to this entity, keyed by component name.
    -- @field components
    self.components = {}
    --- The EventManager instance (set when added to an Engine).
    -- @field eventManager
    self.eventManager = nil
    --- Whether the entity is alive (set to false when removed from Engine).
    -- @field alive
    self.alive = false
    if parent then
        self:setParent(parent)
    else
        parent = nil
    end
    --- Optional name for the entity.
    -- @field name
    self.name = name
    --- Table of child entities, keyed by their id.
    -- @field children
    self.children = {}
end

--- Adds a component to the entity.
-- An entity can only have one component of each type. If a component of the
-- same type already exists, a debug message is printed and the component is not added.
-- Fires a ComponentAdded event if the entity has an eventManager.
-- @tparam table component The component instance to add
-- @see Entity:set
-- @usage
-- entity:add(Position(100, 200))
function Entity:add(component)
    local name = component.class.name
    if self.components[name] then
        lovetoys.debug("Entity: Trying to add Component '" .. name .. "', but it's already existing. Please use Entity:set to overwrite a component in an entity.")
    else
        self.components[name] = component
        if self.eventManager then
            self.eventManager:fireEvent(lovetoys.ComponentAdded(self, name))
        end
    end
end

--- Sets a component on the entity, overwriting any existing component of the same type.
-- Unlike `add`, this will not print a warning if the component already exists.
-- @tparam table component The component instance to set
-- @see Entity:add
-- @usage
-- entity:set(Position(150, 250))  -- Overwrites existing Position
function Entity:set(component)
    local name = component.class.name
    if self.components[name] == nil then
        self:add(component)
    else
        self.components[name] = component
    end
end

--- Adds multiple components to the entity at once.
-- @tparam table componentList Array of component instances to add
-- @usage
-- entity:addMultiple({Position(0, 0), Velocity(1, 1), Health(100)})
function Entity:addMultiple(componentList)
    for _, component in  pairs(componentList) do
        self:add(component)
    end
end

--- Removes a component from the entity by name.
-- Fires a ComponentRemoved event if the entity has an eventManager.
-- @tparam string name The name of the component class to remove
-- @usage
-- entity:remove("Position")
function Entity:remove(name)
    if self.components[name] then
        self.components[name] = nil
    else
        lovetoys.debug("Entity: Trying to remove non-existent component " .. name .. " from Entity. Please fix this")
    end
    if self.eventManager then
        self.eventManager:fireEvent(lovetoys.ComponentRemoved(self, name))
    end
end

--- Sets a new parent for this entity.
-- Removes the entity from its current parent's children and adds it to the new parent.
-- @tparam Entity parent The new parent entity
-- @usage
-- entity:setParent(newParentEntity)
function Entity:setParent(parent)
    if self.parent then self.parent.children[self.id] = nil end
    self.parent = parent
    self:registerAsChild()
end

--- Gets the parent entity.
-- @treturn Entity The parent entity, or nil if no parent
function Entity:getParent()
    return self.parent
end

--- Registers this entity as a child of its parent.
-- Called automatically when the entity is added to an engine or when setParent is called.
-- @local
function Entity:registerAsChild()
    if self.id then self.parent.children[self.id] = self end
end

--- Gets a component by name.
-- @tparam string name The name of the component class
-- @treturn table|nil The component instance, or nil if not found
-- @usage
-- local pos = entity:get("Position")
-- if pos then
--     print(pos.x, pos.y)
-- end
function Entity:get(name)
    return self.components[name]
end

--- Retrieves a nested value from a component using dot-notation path.
-- Useful for accessing deeply nested component properties.
-- @tparam string path Path in format "ComponentName.property.subproperty"
-- @return The value at the path, or nil if any part of the path doesn't exist
-- @usage
-- -- Assuming entity has a Transform component with nested position
-- local x = entity:getPath("Transform.position.x")
function Entity:getPath(path)
    local result = self.components
    for str in string.gmatch(path, "([^%.]+)") do
        if result[str] then
            result = result[str]
        else
            return nil
        end
    end
    return result
end

--- Gets multiple components at once.
-- @tparam string ... Component names as varargs
-- @return Multiple component instances in the order requested
-- @usage
-- local pos, vel = entity:getMultiple("Position", "Velocity")
function Entity:getMultiple(...)
    local res = {}
    for _, component in pairs{...} do
        table.insert(res, self.components[component])
    end
    return unpack(res)
end

--- Checks if the entity has a component.
-- @tparam string name The name of the component class
-- @treturn boolean True if the entity has the component
-- @usage
-- if entity:has("Position") then
--     -- do something
-- end
function Entity:has(name)
    return not not self.components[name]
end

--- Gets all components attached to this entity.
-- @treturn table The components table, keyed by component name
-- @usage
-- for name, component in pairs(entity:getComponents()) do
--     print(name, component)
-- end
function Entity:getComponents()
    return self.components
end

return Entity
