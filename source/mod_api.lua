local ModAPI = {}

ModAPI.materials = {}
ModAPI.biomes = {}
ModAPI.terrainLayers = {}

ModAPI.hooks = {
    load = {},
    update = {},
    draw = {},
    onTileGenerate = {},
    onMousePressed = {},
    onItemUse = {},
    onItemPickup = {},
    onBlockBreak = {},
    onBlockPlace = {},
    onEntityEat = {},
    onCalculateToolPower = {},
    onTileBreak = {}
}

ModAPI.utils = require("source.utils")
ModAPI.lib3d = require("source.projectile.lib3d")
ModAPI.json = require("source.dkjson")

ModAPI.loadedMods = {}
ModAPI.needsWorldReset = false
ModAPI.currentModPath = nil

local function log(...) print("[ModAPI]", ...) end
local function warn(...) print("[ModAPI][Warn]", ...) end
local function err(...) print("[ModAPI][Error]", ...) print(...) end

local function clearTable(t)
    for k in pairs(t) do t[k] = nil end
end

local function ensureTable(t)
    return type(t) == "table" and t or {}
end

function ModAPI.areDependenciesMet(deps)
    deps = ensureTable(deps)

    for _, id in ipairs(deps) do
        if not ModAPI.loadedMods[id] then
            return false
        end
    end

    return true
end

function ModAPI.reset()
    clearTable(ModAPI.materials)
    clearTable(ModAPI.biomes)
    ModAPI.terrainLayers = {}

    for name in pairs(ModAPI.hooks) do
        ModAPI.hooks[name] = {}
    end

    clearTable(ModAPI.loadedMods)
    ModAPI.needsWorldReset = false
end

function ModAPI.declareMod(id, metadata)
    if type(id) ~= "string" then
        warn("declareMod missing id")
        return
    end

    if ModAPI.loadedMods[id] then
        warn("mod already declared:", id)
        return
    end

    metadata = ensureTable(metadata)

    ModAPI.loadedMods[id] = {
        id = id,
        version = metadata.version or "1.0.0",
        dependencies = ensureTable(metadata.dependencies),
        enabled = true
    }
end

function ModAPI.registerMaterial(id, def)
    if type(id) ~= "string" or type(def) ~= "table" then
        warn("registerMaterial invalid args:", id)
        return
    end

    if ModAPI.materials[id] then
        warn("overwriting material:", id)
    end

    if type(def.path) == "string" then
        local path = def.path

        if not love.filesystem.getInfo(path) and ModAPI.currentModPath then
            local alt = ModAPI.currentModPath .. "/" .. path
            if love.filesystem.getInfo(alt) then
                path = alt
            end
        end

        if not love.filesystem.getInfo(path) then
            warn("missing asset:", id, path)
        end

        def.path = path
    end

    ModAPI.materials[id] = def
    ModAPI.needsWorldReset = true
end

function ModAPI.registerBiome(id, def)
    if type(id) ~= "string" or type(def) ~= "table" then
        warn("registerBiome invalid args:", id)
        return
    end

    if type(def.condition) ~= "function" then
        warn("biome missing condition:", id)
        return
    end

    if def.texture and type(def.texture) ~= "string" then
        warn("biome texture must be string:", id)
        def.texture = nil
    end

    ModAPI.biomes[id] = def
    ModAPI.needsWorldReset = true
end

function ModAPI.registerTerrainLayer(fn)
    if type(fn) ~= "function" then
        warn("registerTerrainLayer expects function")
        return
    end

    table.insert(ModAPI.terrainLayers, fn)
    ModAPI.needsWorldReset = true
end

function ModAPI.addHook(name, fn)
    local list = ModAPI.hooks[name]

    if not list then
        warn("unknown hook:", name)
        return
    end

    if type(fn) ~= "function" then
        warn("hook must be function:", name)
        return
    end

    table.insert(list, fn)

    if name == "onTileGenerate" then
        ModAPI.needsWorldReset = true
    end
end

function ModAPI.runHooks(name, ...)
    local list = ModAPI.hooks[name]
    if not list then return end

    for i = 1, #list do
        local ok, res = pcall(list[i], ...)
        if not ok then
            err("hook error (" .. name .. "):", res)
        end
    end
end

function ModAPI.loadMod(modPath)
    if type(modPath) ~= "string" then return end

    local modName = modPath:match("([^/]+)$")
    if not modName or ModAPI.loadedMods[modName] then return end

    local initFile = modPath .. "/init.lua"
    if not love.filesystem.getInfo(initFile) then
        warn("missing init.lua:", modName)
        return
    end

    local chunk, loadErr = love.filesystem.load(initFile)
    if not chunk then
        err("load error:", modName, loadErr)
        return
    end

    local env = setmetatable({
        ModAPI = ModAPI,
        modPath = modPath,
        utils = ModAPI.utils,
        lib3d = ModAPI.lib3d,
        json = ModAPI.json,
    }, { __index = _G })

    if setfenv then
        setfenv(chunk, env)
    else
        local code = love.filesystem.read(initFile)
        chunk = load(code, initFile, "t", env)
    end

    local prevPath = ModAPI.currentModPath
    ModAPI.currentModPath = modPath

    local ok, result = pcall(chunk)

    ModAPI.currentModPath = prevPath

    if not ok then
        err("runtime error:", modName, result)
        return
    end

    local id = (type(result) == "table" and result.id) or modName

    local meta = ModAPI.loadedMods[id]
    if meta and not ModAPI.areDependenciesMet(meta.dependencies) then
        warn("missing dependencies:", modName)
        ModAPI.loadedMods[id] = nil
        return
    end

    ModAPI.loadedMods[id] = ModAPI.loadedMods[id] or { id = id }

    log("loaded:", modName)
end

function ModAPI.applyChanges()
    if not ModAPI.needsWorldReset then
        return false
    end

    ModAPI.needsWorldReset = false
    return true
end

return ModAPI