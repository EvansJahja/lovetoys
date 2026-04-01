--- Utility functions for Lovetoys.
-- Internal helper functions used by the library.
--
-- @module util

local util = {}

--- Gets the first element from a table.
-- Uses Lua's `next()` function, so the "first" element is arbitrary
-- for non-sequential tables.
-- @tparam table list The table to get the first element from
-- @return The first value in the table, or nil if empty
function util.firstElement(list)
    local _, value = next(list)
    return value
end

return util
