local ModAPI = {}

ModAPI.materials = {}
ModAPI.biomes = {}
ModAPI.terrainLayers = {}
ModAPI.hooks = {
    load = {},
    update = {},
    draw = {},
    onTileGenerate = {},
}

ModAPI.loadedMods = {}
ModAPI.needsWorldReset = false

function ModAPI.reset()
    ModAPI.materials = {}
    ModAPI.biomes = {}
    ModAPI.terrainLayers = {}
    ModAPI.hooks = {
        load = {},
        update = {},
        draw = {},
        onTileGenerate = {},
    }
    ModAPI.loadedMods = {}
end

function ModAPI.registerMaterial(id, def)
    assert(id and def, "Material requires id + def")
    ModAPI.materials[id] = def
    ModAPI.needsWorldReset = true
end

function ModAPI.registerBiome(id, def)
    assert(id and def and def.condition, "Biome requires condition()")
    ModAPI.biomes[id] = def
    ModAPI.needsWorldReset = true
end

function ModAPI.registerTerrainLayer(fn)
    assert(type(fn) == "function", "Terrain layer must be function")
    table.insert(ModAPI.terrainLayers, fn)
    ModAPI.needsWorldReset = true
end

function ModAPI.addHook(name, fn)
    assert(ModAPI.hooks[name], "Unknown hook: " .. tostring(name))
    table.insert(ModAPI.hooks[name], fn)
end

function ModAPI.runHooks(name, ...)
    local list = ModAPI.hooks[name]
    if not list then return end
    for i = 1, #list do
        list[i](...)
    end
end

function ModAPI.loadMod(modPath)
    if ModAPI.loadedMods[modPath] then return end

    local chunk, err = love.filesystem.load(modPath .. "/init.lua")
    if not chunk then
        error("Failed loading mod: " .. err)
    end

    local env = setmetatable({
        ModAPI = ModAPI,
        modPath = modPath,
    }, { __index = _G })

    setfenv(chunk, env)
    chunk()

    ModAPI.loadedMods[modPath] = true
end

function ModAPI.applyChanges()
    if not ModAPI.needsWorldReset then return false end
    ModAPI.needsWorldReset = false
    return true
end

return ModAPI