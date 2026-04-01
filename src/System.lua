--- Base System class for implementing game logic.
-- Systems contain the logic that operates on entities with specific components.
-- Subclass this to create your own systems with update or draw methods.
--
-- Systems can require components in two ways:
--
-- 1. Simple requirements: Return an array of component names from requires()
-- 2. Grouped requirements: Return a table of named groups, each containing component arrays
--
-- @classmod System
-- @usage
-- -- Simple system
-- local MovementSystem = lovetoys.class("MovementSystem", System)
-- function MovementSystem:requires()
--     return {"Position", "Velocity"}
-- end
-- function MovementSystem:update(dt)
--     for _, entity in pairs(self.targets) do
--         local pos = entity:get("Position")
--         local vel = entity:get("Velocity")
--         pos.x = pos.x + vel.x * dt
--         pos.y = pos.y + vel.y * dt
--     end
-- end
--
-- -- System with grouped requirements
-- local CollisionSystem = lovetoys.class("CollisionSystem", System)
-- function CollisionSystem:requires()
--     return {
--         static = {"Position", "StaticBody"},
--         dynamic = {"Position", "DynamicBody"}
--     }
-- end
-- function CollisionSystem:update(dt)
--     for _, static in pairs(self.targets.static) do
--         for _, dynamic in pairs(self.targets.dynamic) do
--             -- check collision
--         end
--     end
-- end

-- Getting folder that contains our src
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")

local lovetoys = require(folderOfThisFile .. 'namespace')
local System = lovetoys.class("System")

--- Initializes a new System instance.
-- Sets up the targets table and validates the requires() return format.
function System:initialize()
    --- Table of entities that match this system's requirements.
    -- If the system has groups, this is a table of tables keyed by group name.
    -- Otherwise, it's a table keyed by entity id.
    -- @field targets
    self.targets = {}
    --- Whether this system is active. Inactive systems are skipped during update/draw.
    -- @field active
    self.active = true
    --- Whether this system uses grouped requirements.
    -- Set automatically based on the return value of requires().
    -- @field hasGroups
    self.hasGroups = nil
    for group, req in pairs(self:requires()) do
        local requirementIsGroup = type(req) == "table"
        if self.hasGroups ~= nil then
            assert(self.hasGroups == requirementIsGroup, "System " .. self.class.name .. " has mixed requirements in requires()")
        else
            self.hasGroups = requirementIsGroup
        end

        if requirementIsGroup then
            self.targets[group] = {}
        end
    end
end

--- Override this to define which components entities must have.
-- Return an array of component names for simple requirements,
-- or a table of named groups for grouped requirements.
-- @treturn table Array of component names, or table of groups
-- @usage
-- -- Simple requirements
-- function MySystem:requires()
--     return {"Position", "Velocity"}
-- end
--
-- -- Grouped requirements
-- function MySystem:requires()
--     return {
--         players = {"Position", "PlayerInput"},
--         enemies = {"Position", "AIController"}
--     }
-- end
function System:requires() return {} end

--- Callback called when an entity is added to this system.
-- Override this to perform initialization when entities join.
-- @tparam Entity entity The entity that was added
-- @tparam[opt] string group The group the entity was added to (if using grouped requirements)
function System:onAddEntity(entity, group) end

--- Callback called when an entity is removed from this system.
-- Override this to perform cleanup when entities leave.
-- @tparam Entity entity The entity that was removed
-- @tparam[opt] string group The group the entity was removed from (if using grouped requirements)
function System:onRemoveEntity(entity, group) end

--- Adds an entity to this system's targets.
-- Called automatically by the Engine when an entity matches requirements.
-- @tparam Entity entity The entity to add
-- @tparam[opt] string category The group name if using grouped requirements
-- @local
function System:addEntity(entity, category)
    -- If there are multiple requirement lists, the added entities will
    -- be added to their respective list.
    if category then
        self.targets[category][entity.id] = entity
    else
        -- Otherwise they'll be added to the normal self.targets list
        self.targets[entity.id] = entity
    end

    self:onAddEntity(entity, category)
end

--- Removes an entity from this system's targets.
-- Called automatically by the Engine when entities are removed or
-- no longer match requirements.
-- @tparam Entity entity The entity to remove
-- @tparam[opt] string group The specific group to remove from
-- @local
function System:removeEntity(entity, group)
    if group and self.targets[group][entity.id] then
        self.targets[group][entity.id] = nil
        self:onRemoveEntity(entity, group)
        return
    end

    local firstGroup, _ = next(self.targets)
    if firstGroup then
        if self.hasGroups then
            -- Removing entities from their respective category target list.
            for group, _ in pairs(self.targets) do
                if self.targets[group][entity.id] then
                    self.targets[group][entity.id] = nil
                    self:onRemoveEntity(entity, group)
                end
            end
        else
            if self.targets[entity.id] then
                self.targets[entity.id] = nil
                self:onRemoveEntity(entity)
            end
        end
    end
end

--- Handles component removal from an entity.
-- Called by the Engine when a component is removed. Checks if the entity
-- still meets requirements and removes it from appropriate groups if not.
-- @tparam Entity entity The entity that lost a component
-- @tparam string component The name of the removed component
-- @local
function System:componentRemoved(entity, component)
    if self.hasGroups then
        -- Removing entities from their respective category target list.
        for group, requirements in pairs(self:requires()) do
            for _, req in pairs(requirements) do
                if req == component then
                    self:removeEntity(entity, group)
                    -- stop checking requirements for this group
                    break
                end
            end
        end
    else
        self:removeEntity(entity)
    end
end

--- Helper to get all required components from an entity.
-- Only works for systems with simple (non-grouped) requirements.
-- @tparam Entity entity The entity to get components from
-- @return The required components as multiple return values
-- @usage
-- function MovementSystem:update(dt)
--     for _, entity in pairs(self.targets) do
--         local pos, vel = self:pickRequiredComponents(entity)
--         pos.x = pos.x + vel.x * dt
--     end
-- end
function System:pickRequiredComponents(entity)
    local components = {}
    local requirements = self:requires()

    if type(lovetoys.util.firstElement(requirements)) == "string" then
        for _, componentName in pairs(requirements) do
            table.insert(components, entity:get(componentName))
        end
    elseif type(lovetoys.util.firstElement(requirements)) == "table" then
        lovetoys.debug("System: :pickRequiredComponents() is not supported for systems with multiple component constellations")
        return nil
    end
    return unpack(components)
end

return System
