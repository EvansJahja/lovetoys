--- Event fired when a component is removed from an entity.
-- This event is automatically fired by Entity:remove when the entity
-- has an associated EventManager (i.e., when added to an Engine).
--
-- @classmod ComponentRemoved
-- @see Entity:remove

-- Getting folder that contains our src
local folderOfThisFile = (...):match("(.-)[^%/%.]+$")

path = {}
for i in string.gmatch(folderOfThisFile, '.[^.]*') do
    table.insert(path, i)
end
table.remove(path, #path)
table.remove(path, #path)
folderOfThisFile = table.concat(path)

local ComponentRemoved = require(folderOfThisFile .. '.namespace').class("ComponentRemoved")

--- Creates a new ComponentRemoved event.
-- @tparam Entity entity The entity the component was removed from
-- @tparam string component The name of the removed component class
function ComponentRemoved:initialize(entity, component)
    --- The entity the component was removed from.
    -- @field entity
    self.entity = entity
    --- The name of the component class that was removed.
    -- @field component
    self.component = component
end

return ComponentRemoved
