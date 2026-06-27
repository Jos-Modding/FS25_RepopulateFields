source(g_currentModDirectory .. "src/RepopulateFields.lua")

local environment = nil

local function load()
    environment = RepopulateFields:new()
    getfenv(0)["g_repopulateFields"] = environment
end

local function unload()
    environment = nil
    getfenv(0)["g_repopulateFields"] = nil
end

local function init()
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
    Mission00.load = Utils.prependedFunction(Mission00.load, load)
end

init()
