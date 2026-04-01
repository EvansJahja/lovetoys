--- Event fired when a component is added to an entity.
-- This event is automatically fired by Entity:add when the entity
-- has an associated EventManager (i.e., when added to an Engine).
--
-- @classmod ComponentAdded
-- @see Entity:add

-- Getting folder that contains our src
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")

path = {}
for i in string.gmatch(folderOfThisFile, '.[^.]*') do
    table.insert(path, i)
end
table.remove(path, #path)
table.remove(path, #path)
folderOfThisFile = table.concat(path)

local ComponentAdded = require(folderOfThisFile .. '.namespace').class("ComponentAdded")

--- Creates a new ComponentAdded event.
-- @tparam Entity entity The entity the component was added to
-- @tparam string component The name of the added component class
function ComponentAdded:initialize(entity, component)
    --- The entity the component was added to.
    -- @field entity
    self.entity = entity
    --- The name of the component class that was added.
    -- @field component
    self.component = component
end

return ComponentAdded
