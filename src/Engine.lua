--- Engine class that manages all entities and systems in the ECS.
-- The Engine is the central coordinator that connects entities with systems.
-- It maintains entity lists, handles component events, and orchestrates
-- the update/draw lifecycle.
--
-- @classmod Engine
-- @usage
-- local engine = Engine()
-- engine:addSystem(MovementSystem())
-- engine:addSystem(RenderSystem(), "draw")
-- engine:addEntity(player)
--
-- function love.update(dt)
--     engine:update(dt)
-- end
--
-- function love.draw()
--     engine:draw()
-- end

-- Getting folder that contains our src
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")

local lovetoys = require(folderOfThisFile .. 'namespace')
local Engine = lovetoys.class("Engine")

--- Creates a new Engine instance.
-- Initializes all internal data structures and sets up event listeners
-- for component changes.
function Engine:initialize()
    --- Table of all entities, indexed by entity id.
    -- @field entities
    self.entities = {}
    --- The root entity of the entity hierarchy tree.
    -- @field rootEntity
    self.rootEntity = lovetoys.Entity()
    --- Maps component names to systems requiring that component as first requirement.
    -- @field[opt] singleRequirements
    self.singleRequirements = {}
    --- Maps component names to all systems requiring that component.
    -- @field[opt] allRequirements
    self.allRequirements = {}
    --- Maps component names to lists of entities having that component.
    -- @field entityLists
    self.entityLists = {}
    --- The EventManager instance for this engine.
    -- @field eventManager
    self.eventManager = lovetoys.EventManager()

    --- Table containing system lists by type ("update" and "draw").
    -- @field systems
    self.systems = {}
    --- Registry of all added systems by name.
    -- @field systemRegistry
    self.systemRegistry = {}
    self.systems["update"] = {}
    self.systems["draw"] = {}

    self.eventManager:addListener("ComponentRemoved", self, self.componentRemoved)
    self.eventManager:addListener("ComponentAdded", self, self.componentAdded)
end

--- Adds an entity to the engine.
-- Assigns an ID to the entity, sets up its event manager, and checks
-- which systems the entity should be added to based on its components.
-- @tparam Entity entity The entity to add
-- @usage
-- local entity = Entity()
-- entity:add(Position(0, 0))
-- engine:addEntity(entity)
function Engine:addEntity(entity)
    -- Setting engine eventManager as eventManager for entity
    entity.eventManager = self.eventManager
    -- Getting the next free ID or insert into table
    local newId = #self.entities + 1
    entity.id = newId
    self.entities[entity.id] = entity

    -- If a rootEntity entity is defined and the entity doesn't have a parent yet, the rootEntity entity becomes the entity's parent
    if entity.parent == nil then
        entity:setParent(self.rootEntity)
    end
    entity:registerAsChild()

    for _, component in pairs(entity.components) do
        local name = component.class.name
        -- Adding Entity to specific Entitylist
        if not self.entityLists[name] then self.entityLists[name] = {} end
        self.entityLists[name][entity.id] = entity

        -- Adding Entity to System if all requirements are granted
        if self.singleRequirements[name] then
            for _, system in pairs(self.singleRequirements[name]) do
                self:checkRequirements(entity, system)
            end
        end
    end
end

--- Removes an entity from the engine.
-- Removes the entity from all systems and entity lists. Can optionally
-- remove all children recursively or reassign them to a new parent.
-- @tparam Entity entity The entity to remove
-- @tparam[opt=false] boolean removeChildren If true, removes all children recursively
-- @tparam[opt] Entity newParent If provided and removeChildren is false, children are reassigned to this parent
-- @usage
-- -- Remove entity only, children go to rootEntity
-- engine:removeEntity(entity)
--
-- -- Remove entity and all children
-- engine:removeEntity(entity, true)
--
-- -- Remove entity, reassign children to another parent
-- engine:removeEntity(entity, false, otherEntity)
function Engine:removeEntity(entity, removeChildren, newParent)
    if self.entities[entity.id] then
        -- Removing the Entity from all Systems and engine
        for _, component in pairs(entity.components) do
            local name = component.class.name
            if self.singleRequirements[name] then
                for _, system in pairs(self.singleRequirements[name]) do
                    system:removeEntity(entity)
                end
            end
        end
        -- Deleting the Entity from the specific entity lists
        for _, component in pairs(entity.components) do
            self.entityLists[component.class.name][entity.id] = nil
        end

        -- If removeChild is defined, all children become deleted recursively
        if removeChildren then
            for _, child in pairs(entity.children) do
                self:removeEntity(child, true)
            end
        else
            -- If a new Parent is defined, this Entity will be set as the new Parent
            for _, child in pairs(entity.children) do
                if newParent then
                    child:setParent(newParent)
                else
                    child:setParent(self.rootEntity)
                end
                -- Registering as child
                entity:registerAsChild()
            end
        end
        -- Removing Reference to entity from parent
        for _, _ in pairs(entity.parent.children) do
            entity.parent.children[entity.id] = nil
        end
        -- Setting status of entity to dead. This is for other systems, which still got a hard reference on this
        self.entities[entity.id].alive = false
        -- Removing entity from engine
        self.entities[entity.id] = nil
    else
        lovetoys.debug("Engine: Trying to remove non existent entity from engine.")
        if entity.id then
            lovetoys.debug("Engine: Entity id: " .. entity.id)
        else
            lovetoys.debug("Engine: Entity has not been added to any engine yet. (No entity.id)")
        end
        lovetoys.debug("Engine: Entity's components:")
        for index, component in pairs(entity.components) do
            lovetoys.debug(index, component)
        end
    end
end

--- Adds a system to the engine.
-- Systems with an `update` method are added to the update list.
-- Systems with a `draw` method are added to the draw list.
-- If a system has both, you must specify which type to add it as.
-- @tparam System system The system instance to add
-- @tparam[opt] string type Either "update" or "draw". Required if system has both methods.
-- @treturn System The added system
-- @usage
-- engine:addSystem(MovementSystem())
-- engine:addSystem(RenderSystem(), "draw")
function Engine:addSystem(system, type)
    local name = system.class.name

    -- Check if the specified type is correct
    if type ~= nil and type ~= "draw" and type ~= "update" then
        lovetoys.debug("Engine: Trying to add System " .. name .. "with invalid type " .. type .. ". Aborting")
        return
    end

    -- Check if a type should be specified
    if system.draw and system.update and not type then
        lovetoys.debug("Engine: Trying to add System " .. name .. ", which has an update and a draw function, without specifying type. Aborting")
        return
    end

    -- Check if the user is accidentally adding two instances instead of one
    if self.systemRegistry[name] and self.systemRegistry[name] ~= system then
        lovetoys.debug("Engine: Trying to add two different instances of the same system. Aborting.")
        return
    end

    -- Adding System to engine system reference table
    if not (self.systemRegistry[name]) then
        self:registerSystem(system)
    -- This triggers if the system doesn't have update and draw and it's already existing.
    elseif not (system.update and system.draw) then
        if self.systemRegistry[name] then
            lovetoys.debug("Engine: System " .. name .. " already exists. Aborting")
            return
        end
    end

    -- Adding System to draw table
    if system.draw and (not type or type == "draw") then
        for _, registeredSystem in pairs(self.systems["draw"]) do
            if registeredSystem.class.name == name then
                lovetoys.debug("Engine: System " .. name .. " already exists. Aborting")
                return
            end
        end
        table.insert(self.systems["draw"], system)
    -- Adding System to update table
    elseif system.update and (not type or type == "update") then
        for _, registeredSystem in pairs(self.systems["update"]) do
            if registeredSystem.class.name == name then
                lovetoys.debug("Engine: System " .. name .. " already exists. Aborting")
                return
            end
        end
        table.insert(self.systems["update"], system)
    end

    -- Checks if some of the already existing entities match the required components.
    for _, entity in pairs(self.entities) do
        self:checkRequirements(entity, system)
    end
    return system
end

--- Registers a system's component requirements internally.
-- Called automatically by addSystem. Sets up the singleRequirements and
-- allRequirements mappings for efficient entity-system matching.
-- @tparam System system The system to register
-- @local
function Engine:registerSystem(system)
    local name = system.class.name
    self.systemRegistry[name] = system
    -- case: system:requires() returns a table of strings
    if not system.hasGroups then
        for index, req in pairs(system:requires()) do
            -- Registering at singleRequirements
            if index == 1 then
                self.singleRequirements[req] = self.singleRequirements[req] or {}
                table.insert(self.singleRequirements[req], system)
            end
            -- Registering at allRequirements
            self.allRequirements[req] = self.allRequirements[req] or {}
            table.insert(self.allRequirements[req], system)
        end
    end

    -- case: system:requires() returns a table of tables which contain strings
    if system.hasGroups then
        for group, componentList in pairs(system:requires()) do
            -- Registering at singleRequirements
            local component = componentList[1]
            self.singleRequirements[component] = self.singleRequirements[component] or {}
            table.insert(self.singleRequirements[component], system)

            -- Registering at allRequirements
            for _, req in pairs(componentList) do
                self.allRequirements[req] = self.allRequirements[req] or {}
                -- Check if this List already contains the System
                local contained = false
                for _, registeredSystem in pairs(self.allRequirements[req]) do
                    if registeredSystem == system then
                        contained = true
                        break
                    end
                end
                if not contained then
                    table.insert(self.allRequirements[req], system)
                end
            end
        end
    end
end

--- Stops (deactivates) a system by name.
-- Stopped systems will not have their update or draw methods called.
-- @tparam string name The name of the system to stop
-- @see Engine:startSystem
-- @see Engine:toggleSystem
-- @usage
-- engine:stopSystem("MovementSystem")
function Engine:stopSystem(name)
    if self.systemRegistry[name] then
        self.systemRegistry[name].active = false
    else
        lovetoys.debug("Engine: Trying to stop not existing System: " .. name)
    end
end

--- Starts (activates) a system by name.
-- @tparam string name The name of the system to start
-- @see Engine:stopSystem
-- @see Engine:toggleSystem
-- @usage
-- engine:startSystem("MovementSystem")
function Engine:startSystem(name)
    if self.systemRegistry[name] then
        self.systemRegistry[name].active = true
    else
        lovetoys.debug("Engine: Trying to start not existing System: " .. name)
    end
end

--- Toggles a system's active state.
-- @tparam string name The name of the system to toggle
-- @see Engine:stopSystem
-- @see Engine:startSystem
-- @usage
-- engine:toggleSystem("MovementSystem")
function Engine:toggleSystem(name)
    if self.systemRegistry[name] then
        self.systemRegistry[name].active = not self.systemRegistry[name].active
    else
        lovetoys.debug("Engine: Trying to toggle not existing System: " .. name)
    end
end

--- Calls update on all active update systems.
-- Should be called from love.update or your game loop.
-- @tparam ... ... Arguments to pass to each system's update method (typically dt)
-- @usage
-- function love.update(dt)
--     engine:update(dt)
-- end
function Engine:update(...)
    for _, system in ipairs(self.systems["update"]) do
        if system.active then
            system:update(...)
        end
    end
end

--- Calls draw on all active draw systems.
-- Should be called from love.draw or your render loop.
-- @usage
-- function love.draw()
--     engine:draw()
-- end
function Engine:draw()
    for _, system in ipairs(self.systems["draw"]) do
        if system.active then
            system:draw()
        end
    end
end

--- Handles ComponentRemoved events.
-- Called automatically when a component is removed from an entity.
-- Updates entity lists and notifies affected systems.
-- @tparam ComponentRemoved event The component removed event
-- @local
function Engine:componentRemoved(event)
    -- In case a single component gets removed from an entity, we inform
    -- all systems that this entity lost this specific component.
    local entity = event.entity
    local component = event.component

    -- Removing Entity from Entity lists
    self.entityLists[component][entity.id] = nil

    -- Removing Entity from systems
    if self.allRequirements[component] then
        for _, system in pairs(self.allRequirements[component]) do
            system:componentRemoved(entity, component)
        end
    end
end

--- Handles ComponentAdded events.
-- Called automatically when a component is added to an entity.
-- Updates entity lists and checks if entity now matches any systems.
-- @tparam ComponentAdded event The component added event
-- @local
function Engine:componentAdded(event)
    local entity = event.entity
    local component = event.component

    -- Adding the Entity to Entitylist
    if not self.entityLists[component] then self.entityLists[component] = {} end
    self.entityLists[component][entity.id] = entity

    -- Adding the Entity to the requiring systems
    if self.allRequirements[component] then
        for _, system in pairs(self.allRequirements[component]) do
            self:checkRequirements(entity, system)
        end
    end
end

--- Gets the root entity of the entity hierarchy.
-- The root entity is the default parent for entities without an explicit parent.
-- @treturn Entity The root entity
function Engine:getRootEntity()
    if self.rootEntity ~= nil then
        return self.rootEntity
    end
end

--- Gets all entities that have a specific component.
-- Creates the entity list if it doesn't exist yet.
-- @tparam string component The name of the component
-- @treturn table Table of entities indexed by entity id
-- @usage
-- local positionEntities = engine:getEntitiesWithComponent("Position")
-- for id, entity in pairs(positionEntities) do
--     print(entity:get("Position").x)
-- end
function Engine:getEntitiesWithComponent(component)
    if not self.entityLists[component] then self.entityLists[component] = {} end
    return self.entityLists[component]
end

--- Counts the number of entities with a specific component.
-- @tparam string component The name of the component
-- @treturn number The count of entities with the component
-- @usage
-- local count = engine:getEntityCount("Position")
-- print("Entities with position: " .. count)
function Engine:getEntityCount(component)
    local count = 0
    if self.entityLists[component] then
        for _, system in pairs(self.entityLists[component]) do
            count = count + 1
        end
    end
    return count
end

--- Checks if an entity meets a system's component requirements.
-- If requirements are met, adds the entity to the system.
-- Handles both simple requirements and grouped requirements.
-- @tparam Entity entity The entity to check
-- @tparam System system The system to check against
-- @local
function Engine:checkRequirements(entity, system) -- luacheck: ignore self
    local meetsRequirements = true
    local foundGroup = nil
    for group, req in pairs(system:requires()) do
        if not system.hasGroups then
            if not entity.components[req] then
                meetsRequirements = false
                break
            end
        else
            meetsRequirements = true
            for _, req2 in pairs(req) do
                if not entity.components[req2] then
                    meetsRequirements = false
                    break
                end
            end
            if meetsRequirements == true then
                foundGroup = true
                system:addEntity(entity, group)
            end
        end
    end
    if meetsRequirements == true and foundGroup == nil then
        system:addEntity(entity)
    end
end

return Engine
