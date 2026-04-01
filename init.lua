--- Lovetoys - Entity Component System for Love2D.
-- A full-featured Entity Component System (ECS) framework for game development
-- with Love2D. Provides Entity, Component, System, Engine, and EventManager classes.
--
-- @module lovetoys
-- @author Arne Beer and Rafael Epplée
-- @license MIT
-- @usage
-- local lovetoys = require("lovetoys")
-- lovetoys.initialize({ globals = true, debug = false })
--
-- -- Create components
-- local Position = Component.create("Position", {"x", "y"}, {x = 0, y = 0})
--
-- -- Create entity and add components
-- local entity = Entity()
-- entity:add(Position(100, 200))
--
-- -- Create engine and add entity
-- local engine = Engine()
-- engine:addEntity(entity)

-- Getting folder that contains our src
local folderOfThisFile = (...) .. "."

local lovetoys = require(folderOfThisFile .. 'src.namespace')

--- Prints a debug message if debug mode is enabled.
-- @tparam string message The message to print
function lovetoys.debug(message)
    if lovetoys.config.debug then
        print(message)
    end
end

local function populateNamespace(ns)
    -- Requiring class
    ns.class = require(lovetoys.config.middleclassPath or folderOfThisFile .. 'lib.middleclass')

    -- Requiring util functions
    ns.util = require(folderOfThisFile .. "src.util")

    -- Requiring all Events
    ns.ComponentAdded = require(folderOfThisFile .. "src.events.ComponentAdded")
    ns.ComponentRemoved = require(folderOfThisFile .. "src.events.ComponentRemoved")

    -- Requiring the lovetoys
    ns.Entity = require(folderOfThisFile .. "src.Entity")
    ns.Engine = require(folderOfThisFile .. "src.Engine")
    ns.System = require(folderOfThisFile .. "src.System")
    ns.EventManager = require(folderOfThisFile .. "src.EventManager")
    ns.Component = require(folderOfThisFile .. "src.Component")
end

--- Initializes the Lovetoys library with the given options.
-- Must be called before using any other Lovetoys functionality.
-- Can only be called once; subsequent calls will print a warning.
-- @tparam[opt={}] table opts Configuration options
-- @tparam[opt=false] boolean opts.debug Enable debug mode to print diagnostic messages
-- @tparam[opt=false] boolean opts.globals If true, all classes are also added to the global namespace
-- @tparam[opt=nil] string opts.middleclassPath Custom path to middleclass library
-- @usage
-- -- Basic initialization
-- lovetoys.initialize()
--
-- -- With options
-- lovetoys.initialize({
--     debug = true,
--     globals = true,
--     middleclassPath = "libs.middleclass"
-- })
function lovetoys.initialize(opts)
    if opts == nil then opts = {} end
    if not lovetoys.initialized then
        lovetoys.config = {
            debug = false,
            globals = false
        }

        for name, val in pairs(opts) do
            lovetoys.config[name] = val
        end

        populateNamespace(lovetoys)

        if lovetoys.config.globals then
            populateNamespace(_G)
        end
        lovetoys.initialized = true
    else
        print('Lovetoys is already initialized.')
    end
end

return lovetoys
