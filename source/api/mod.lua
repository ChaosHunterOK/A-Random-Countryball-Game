local ModAPI = {}

ModAPI.VERSION = 2
ModAPI.CANCEL = setmetatable({}, { __tostring = function() return "ModAPI.CANCEL" end })

local unpack = unpack or table.unpack

local function tag(kind, modId)
    if modId then return "[ModAPI][" .. kind .. "][" .. modId .. "]" end
    return "[ModAPI][" .. kind .. "]"
end

ModAPI.errors = {}

local function log(...)  print("[ModAPI]", ...) end
local function warn(...) print(tag("Warn", ModAPI.currentModId), ...) end
local function err(...)
    print(tag("Error", ModAPI.currentModId), ...)
    ModAPI.errors[#ModAPI.errors + 1] = table.concat({ tostring(ModAPI.currentModId or "core"), ... }, " ")
end

ModAPI.log, ModAPI.warn, ModAPI.err = log, warn, err

local function ensureTable(t) return type(t) == "table" and t or {} end
local function clearTable(t) for k in pairs(t) do t[k] = nil end end

local registries = {}

local Registry = {}
Registry.__index = Registry

function Registry:_touch()
    self.revision = self.revision + 1
    if self.worldReset then ModAPI.needsWorldReset = true end
    for i = 1, #self.listeners do
        local ok, e = pcall(self.listeners[i], self)
        if not ok then err("registry listener (" .. self.name .. "):", e) end
    end
end

function Registry:register(id, def, owner)
    if self.ordered then
        def, owner = id, def
        id = "auto:" .. (#self.order + 1)
    end

    if type(id) ~= "string" then
        warn("register(" .. self.name .. ") needs a string id")
        return nil
    end
    if def == nil then
        warn("register(" .. self.name .. ") missing definition:", id)
        return nil
    end

    if self.validate then
        local ok, reason = self.validate(id, def)
        if not ok then
            warn("invalid " .. self.name .. " '" .. id .. "':", reason or "?")
            return nil
        end
    end

    if self.entries[id] then
        local prev = self.entries[id]
        if prev.owner ~= owner then
            warn("'" .. id .. "' in registry '" .. self.name .. "' overwritten by",
                 tostring(owner), "(was", tostring(prev.owner) .. ")")
        end
    else
        self.order[#self.order + 1] = id
    end

    if self.transform then def = self.transform(id, def) or def end

    self.entries[id] = { id = id, def = def, owner = owner }
    if self.mirror then self.mirror[id] = def end

    self:_touch()
    return def
end

function Registry:unregister(id)
    if not self.entries[id] then return false end
    self.entries[id] = nil
    if self.mirror then self.mirror[id] = nil end
    for i = #self.order, 1, -1 do
        if self.order[i] == id then table.remove(self.order, i) break end
    end
    self:_touch()
    return true
end

function Registry:removeOwned(owner)
    local removed = 0
    for i = #self.order, 1, -1 do
        local id = self.order[i]
        local e = self.entries[id]
        if e and e.owner == owner then
            self.entries[id] = nil
            if self.mirror then self.mirror[id] = nil end
            table.remove(self.order, i)
            removed = removed + 1
        end
    end
    if removed > 0 then self:_touch() end
    return removed
end

function Registry:get(id)
    local e = self.entries[id]
    return e and e.def or nil
end

function Registry:owner(id)
    local e = self.entries[id]
    return e and e.owner or nil
end

function Registry:iter()
    local i = 0
    return function()
        i = i + 1
        local id = self.order[i]
        if not id then return nil end
        local e = self.entries[id]
        return id, e.def, e.owner
    end
end

function Registry:list()
    local out = {}
    for i = 1, #self.order do out[i] = self.entries[self.order[i]].def end
    return out
end

function Registry:all()
    local out = {}
    for id, e in pairs(self.entries) do out[id] = e.def end
    return out
end

function Registry:onChange(fn)
    self.listeners[#self.listeners + 1] = fn
    return fn
end

function ModAPI.defineRegistry(name, opts)
    if registries[name] then return registries[name] end
    opts = ensureTable(opts)

    local reg = setmetatable({
        name = name,
        entries = {},
        order = {},
        listeners = {},
        revision = 0,
        worldReset = opts.worldReset or false,
        mirror = opts.mirror,
        ordered = opts.ordered or false,
        validate = opts.validate,
        transform = opts.transform,
    }, Registry)

    registries[name] = reg
    return reg
end

function ModAPI.registry(name)
    local reg = registries[name]
    if not reg then warn("unknown registry:", name) end
    return reg
end

function ModAPI.registryNames()
    local out = {}
    for name in pairs(registries) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function ModAPI.register(name, id, def)
    local reg = registries[name] or ModAPI.defineRegistry(name)
    return reg:register(id, def, ModAPI.currentModId)
end

function ModAPI.unregister(name, id)
    local reg = registries[name]
    return reg and reg:unregister(id) or false
end

function ModAPI.get(name, id)
    local reg = registries[name]
    return reg and reg:get(id) or nil
end

function ModAPI.getAll(name)
    local reg = registries[name]
    return reg and reg:all() or {}
end

function ModAPI.list(name)
    local reg = registries[name]
    return reg and reg:list() or {}
end

function ModAPI.revision(name)
    local reg = registries[name]
    return reg and reg.revision or 0
end

ModAPI.materials = {}
ModAPI.biomes = {}
ModAPI.terrainLayers = {}

local function resolveAssetField(def, key)
    if type(def[key]) == "string" then
        def[key] = ModAPI.asset(def[key])
    end
end

local R = {}

R.material = ModAPI.defineRegistry("material", {
    mirror = ModAPI.materials,
    worldReset = true,
    transform = function(id, def)
        resolveAssetField(def, "path")
        def.id = id
        return def
    end,
})

R.biome = ModAPI.defineRegistry("biome", {
    mirror = ModAPI.biomes,
    worldReset = true,
    validate = function(id, def)
        if type(def.condition) ~= "function" then return false, "missing condition function" end
        if def.texture ~= nil and type(def.texture) ~= "string" then return false, "texture must be a string" end
        return true
    end,
})

R.item = ModAPI.defineRegistry("item", {
    transform = function(id, def)
        resolveAssetField(def, "img")
        def.id = id
        def.stack = def.stack or 10
        def.eatable = def.eatable or false
        return def
    end,
})

R.prop = ModAPI.defineRegistry("prop", {
    worldReset = true,
    validate = function(id, def)
        if def.spawnOn ~= nil and type(def.spawnOn) ~= "table" then return false, "spawnOn must be a list of tile names" end
        if not (def.img or def.imgBottom or def.imgObj or def.imgBottomObj) then return false, "needs img or imgBottom/Middle/Top" end
        return true
    end,
    transform = function(id, def)
        resolveAssetField(def, "img")
        resolveAssetField(def, "imgBottom")
        resolveAssetField(def, "imgMiddle")
        resolveAssetField(def, "imgTop")
        def.id = id
        def.maxHealth = def.maxHealth or 5
        def.weight = def.weight or 10
        def.spawnOn = def.spawnOn or {}
        return def
    end,
})

R.recipe = ModAPI.defineRegistry("recipe")
R.structure = ModAPI.defineRegistry("structure")
R.toolType = ModAPI.defineRegistry("toolType")
R.toolMaterial = ModAPI.defineRegistry("toolMaterial")
R.terrainLayer = ModAPI.defineRegistry("terrainLayer", {
    mirror = nil, ordered = true, worldReset = true,
})

R.terrainLayer:onChange(function(reg)
    clearTable(ModAPI.terrainLayers)
    local i = 0
    for _, def in reg:iter() do
        i = i + 1
        ModAPI.terrainLayers[i] = def
    end
end)

function ModAPI.registerMaterial(id, def)
    if type(id) ~= "string" or type(def) ~= "table" then
        warn("registerMaterial invalid args:", id)
        return
    end
    return R.material:register(id, def, ModAPI.currentModId)
end

function ModAPI.registerBiome(id, def)
    if type(id) ~= "string" or type(def) ~= "table" then
        warn("registerBiome invalid args:", id)
        return
    end
    return R.biome:register(id, def, ModAPI.currentModId)
end

function ModAPI.registerItem(id, def)
    if type(id) ~= "string" or type(def) ~= "table" then
        warn("registerItem invalid args:", id)
        return
    end
    return R.item:register(id, def, ModAPI.currentModId)
end

function ModAPI.registerProp(id, def)
    if type(id) ~= "string" or type(def) ~= "table" then
        warn("registerProp invalid args:", id)
        return
    end
    return R.prop:register(id, def, ModAPI.currentModId)
end

function ModAPI.registerRecipe(id, def)     return R.recipe:register(id, def, ModAPI.currentModId) end
function ModAPI.registerStructure(id, def)  return R.structure:register(id, def, ModAPI.currentModId) end
function ModAPI.registerToolType(id, def)
    if type(def) == "number" then def = { power = def } end
    return R.toolType:register(id, def, ModAPI.currentModId)
end
function ModAPI.registerToolMaterial(id, def)
    if type(def) == "number" then def = { power = def } end
    return R.toolMaterial:register(id, def, ModAPI.currentModId)
end

function ModAPI.registerTerrainLayer(fn)
    if type(fn) ~= "function" then
        warn("registerTerrainLayer expects a function")
        return
    end
    return R.terrainLayer:register(fn, ModAPI.currentModId)
end

function ModAPI.modify(registryName, id, fn)
    local reg = registries[registryName]
    if not reg then warn("modify: unknown registry", registryName) return end
    local entry = reg.entries[id]
    if not entry then warn("modify: no '" .. id .. "' in", registryName) return end
    local def = entry.def
    if type(fn) == "table" then
        for k, v in pairs(fn) do def[k] = v end
    elseif type(fn) == "function" then
        local ok, res = pcall(fn, def)
        if not ok then err("modify hook failed:", res) return end
        if type(res) == "table" then def = res end
    end
    if reg.transform then def = reg.transform(id, def) or def end
    entry.def = def
    if reg.mirror then reg.mirror[id] = def end
    reg:_touch()
    return def
end

local hooks = {}

local BUILTIN_HOOKS = {
    "load", "update", "draw", "keypressed", "keyreleased", "mousemoved",
    "onTileGenerate", "onMousePressed", "onItemUse", "onItemPickup",
    "onBlockBreak", "onBlockPlace", "onEntityEat", "onCalculateToolPower",
    "onTileBreak", "onPropBreak", "onPropRewards", "onWorldLoad", "onWorldSave",
    "onPlayerDamage", "onCraft", "onModsLoaded", "onRegistriesReady",
}

ModAPI.hooks = hooks

local function hookList(name)
    local list = hooks[name]
    if not list then
        list = {}
        hooks[name] = list
    end
    return list
end

for i = 1, #BUILTIN_HOOKS do hookList(BUILTIN_HOOKS[i]) end
function ModAPI.defineHook(name)
    hookList(name)
    return name
end

function ModAPI.addHook(name, fn, opts)
    if type(fn) ~= "function" then
        warn("hook must be a function:", name)
        return nil
    end
    opts = ensureTable(opts)

    local list = hooks[name]
    if not list then
        list = hookList(name)
        if not opts.quiet then log("new hook channel:", name) end
    end

    local entry = {
        fn = fn,
        priority = opts.priority or 100,
        id = opts.id,
        owner = ModAPI.currentModId,
        name = name,
    }

    list[#list + 1] = entry
    table.sort(list, function(a, b)
        if a.priority == b.priority then return (a.seq or 0) < (b.seq or 0) end
        return a.priority < b.priority
    end)

    if name == "onTileGenerate" then ModAPI.needsWorldReset = true end
    return entry
end

function ModAPI.removeHook(handle, name)
    if type(handle) == "string" then
        local list = hooks[handle]
        if not list then return false end
        for i = #list, 1, -1 do
            if list[i].id == name then table.remove(list, i) return true end
        end
        return false
    end
    if type(handle) ~= "table" then return false end
    local list = hooks[handle.name]
    if not list then return false end
    for i = #list, 1, -1 do
        if list[i] == handle then table.remove(list, i) return true end
    end
    return false
end

local function removeHooksOwnedBy(owner)
    local n = 0
    for _, list in pairs(hooks) do
        for i = #list, 1, -1 do
            if list[i].owner == owner then table.remove(list, i) n = n + 1 end
        end
    end
    return n
end

function ModAPI.runHooks(name, ...)
    local list = hooks[name]
    if not list or #list == 0 then return nil end

    for i = 1, #list do
        local entry = list[i]
        local ok, res = pcall(entry.fn, ...)
        if not ok then
            err("hook error (" .. name .. (entry.owner and " / " .. entry.owner or "") .. "):", res)
        elseif res ~= nil then
            if res == ModAPI.CANCEL then return true end
            return res
        end
    end
    return nil
end

function ModAPI.runFilter(name, value, ...)
    local list = hooks[name]
    if not list or #list == 0 then return value end

    for i = 1, #list do
        local entry = list[i]
        local ok, res = pcall(entry.fn, value, ...)
        if not ok then
            err("filter error (" .. name .. "):", res)
        elseif res ~= nil then
            value = res
        end
    end
    return value
end

function ModAPI.emit(name, ...)
    local list = hooks[name]
    if not list then return end
    for i = 1, #list do
        local ok, e = pcall(list[i].fn, ...)
        if not ok then err("event error (" .. name .. "):", e) end
    end
end

ModAPI.currentModPath = nil
ModAPI.currentModId = nil

function ModAPI.asset(path, modPath)
    if type(path) ~= "string" then return path end
    if not love or not love.filesystem then return path end

    if love.filesystem.getInfo(path) then return path end

    modPath = modPath or ModAPI.currentModPath
    if modPath then
        local alt = modPath .. "/" .. path
        if love.filesystem.getInfo(alt) then return alt end
        local alt2 = modPath .. "/assets/" .. path
        if love.filesystem.getInfo(alt2) then return alt2 end
    end

    warn("missing asset:", path)
    return path
end

local imageCache = {}
function ModAPI.image(path, modPath)
    if type(path) ~= "string" then return path end
    local resolved = ModAPI.asset(path, modPath)
    local cached = imageCache[resolved]
    if cached ~= nil then return cached or nil end

    local ok, img = pcall(love.graphics.newImage, resolved)
    if not ok then
        warn("failed to load image:", resolved)
        imageCache[resolved] = false
        return nil
    end
    imageCache[resolved] = img
    return img
end

function ModAPI.clearImageCache() clearTable(imageCache) end
local STORAGE_DIR = "mods_data"

function ModAPI.storage(modId)
    modId = modId or ModAPI.currentModId
    if not modId then warn("storage() needs a mod id") return nil end

    local file = STORAGE_DIR .. "/" .. modId .. ".json"
    local store = { data = {} }

    function store.load()
        if not love.filesystem.getInfo(file) then return store.data end
        local raw = love.filesystem.read(file)
        local ok, decoded = pcall(ModAPI.json.decode, raw)
        store.data = (ok and type(decoded) == "table") and decoded or {}
        return store.data
    end

    function store.save()
        love.filesystem.createDirectory(STORAGE_DIR)
        local ok, encoded = pcall(ModAPI.json.encode, store.data, { indent = true })
        if not ok then warn("storage encode failed:", modId) return false end
        return love.filesystem.write(file, encoded)
    end

    function store.get(key, default)
        local v = store.data[key]
        if v == nil then return default end
        return v
    end

    function store.set(key, value)
        store.data[key] = value
        return store
    end

    store.load()
    return store
end

ModAPI.loadedMods = {}
ModAPI.loadOrder = {}
ModAPI.needsWorldReset = false
ModAPI.disabled = {}

ModAPI.utils = require("source.utils.utils")
ModAPI.tweens = require("source.utils.tweens")
ModAPI.lib3d = require("source.projectile.lib3d")
ModAPI.json = require("source.utils.dkjson")
ModAPI.transition = require("source.utils.transition")

function ModAPI.areDependenciesMet(deps)
    deps = ensureTable(deps)
    for _, id in ipairs(deps) do
        local mod = ModAPI.loadedMods[id]
        if not mod or not mod.enabled then return false, id end
    end
    return true
end

function ModAPI.declareMod(id, metadata)
    if type(id) ~= "string" then
        warn("declareMod missing id")
        return
    end

    metadata = ensureTable(metadata)
    local existing = ModAPI.loadedMods[id]

    if existing and existing.declared then
        warn("mod already declared:", id)
        return existing
    end

    local mod = existing or {}
    mod.id = id
    mod.declared = true
    mod.name = metadata.name or id
    mod.version = metadata.version or "1.0.0"
    mod.author = metadata.author
    mod.description = metadata.description
    mod.apiVersion = metadata.apiVersion or 1
    mod.dependencies = ensureTable(metadata.dependencies)
    mod.optional = ensureTable(metadata.optional)
    mod.enabled = not ModAPI.disabled[id]
    mod.standalone = metadata.standalone or false
    mod.path = mod.path or ModAPI.currentModPath

    if mod.apiVersion > ModAPI.VERSION then
        warn("mod '" .. id .. "' wants ModAPI v" .. mod.apiVersion ..
             " but this game provides v" .. ModAPI.VERSION)
    end

    ModAPI.loadedMods[id] = mod
    return mod
end

function ModAPI.hasStandaloneConflict(modId)
    local current = ModAPI.loadedMods[modId]
    if not current or not current.standalone then return false end

    local count = 0
    for _, mod in pairs(ModAPI.loadedMods) do
        if mod.enabled then count = count + 1 end
    end
    return count > 1
end

local function readManifest(modPath)
    local file = modPath .. "/mod.json"
    if not love.filesystem.getInfo(file) then return nil end
    local raw = love.filesystem.read(file)
    local ok, decoded = pcall(ModAPI.json.decode, raw)
    if not ok or type(decoded) ~= "table" then
        warn("bad mod.json in", modPath)
        return nil
    end
    return decoded
end

local function buildEnv(modPath, modId)
    local env
    env = setmetatable({
        ModAPI = ModAPI,
        modPath = modPath,
        modId = modId,
        utils = ModAPI.utils,
        lib3d = ModAPI.lib3d,
        json = ModAPI.json,
        tweens = ModAPI.tweens,
        transition = ModAPI.transition,
        asset = function(p) return ModAPI.asset(p, modPath) end,
        image = function(p) return ModAPI.image(p, modPath) end,
        storage = function() return ModAPI.storage(modId) end,
        print = function(...) print("[" .. tostring(modId) .. "]", ...) end,
        modrequire = function(rel)
            local path = modPath .. "/" .. rel:gsub("%.", "/") .. ".lua"
            local chunk, e = love.filesystem.load(path)
            if not chunk then err("modrequire failed:", path, e) return nil end
            if setfenv then setfenv(chunk, env)
            else chunk = load(love.filesystem.read(path), path, "t", env) end
            local ok, res = pcall(chunk)
            if not ok then err("modrequire error:", path, res) return nil end
            return res
        end,
    }, { __index = _G })
    return env
end

local function runInit(modPath, modId)
    local initFile = modPath .. "/init.lua"
    if not love.filesystem.getInfo(initFile) then
        warn("missing init.lua:", modId)
        return false
    end

    local chunk, loadErr = love.filesystem.load(initFile)
    if not chunk then
        err("load error:", modId, loadErr)
        return false
    end

    local env = buildEnv(modPath, modId)
    if setfenv then
        setfenv(chunk, env)
    else
        chunk = load(love.filesystem.read(initFile), initFile, "t", env)
    end

    local prevPath, prevId = ModAPI.currentModPath, ModAPI.currentModId
    ModAPI.currentModPath, ModAPI.currentModId = modPath, modId

    local ok, result = pcall(chunk)

    ModAPI.currentModPath, ModAPI.currentModId = prevPath, prevId

    if not ok then
        err("runtime error:", modId, result)
        return false
    end
    return true, result
end

function ModAPI.loadMod(modPath)
    if type(modPath) ~= "string" then return end

    local folder = modPath:match("([^/]+)$")
    if not folder then return end

    local manifest = readManifest(modPath) or {}
    local id = manifest.id or folder

    if ModAPI.disabled[id] then
        log("skipped (disabled):", id)
        return
    end

    local existing = ModAPI.loadedMods[id]
    if existing and existing.loaded then return existing end
    if manifest.id then
        ModAPI.currentModPath = modPath
        ModAPI.declareMod(id, manifest)
        ModAPI.currentModPath = nil
    end

    local mod = ModAPI.loadedMods[id]
    if mod then
        local met, missing = ModAPI.areDependenciesMet(mod.dependencies)
        if not met then
            warn("missing dependency '" .. tostring(missing) .. "' for", id)
            return
        end
    end

    local ok, result = runInit(modPath, id)
    if not ok then
        ModAPI.loadedMods[id] = nil
        return
    end

    local resultId = (type(result) == "table" and result.id) or id
    mod = ModAPI.loadedMods[resultId] or ModAPI.declareMod(resultId, type(result) == "table" and result or {})
    mod.loaded = true
    mod.path = modPath
    mod.exports = type(result) == "table" and result or nil
    local met, missing = ModAPI.areDependenciesMet(mod.dependencies)
    if not met then
        warn("missing dependency '" .. tostring(missing) .. "' for", resultId, "- unloading")
        ModAPI.unloadMod(resultId)
        return
    end

    ModAPI.loadOrder[#ModAPI.loadOrder + 1] = resultId
    log("loaded:", resultId, mod.version)
    local loadedCount, standaloneMod = 0, nil
    for _, m in pairs(ModAPI.loadedMods) do
        if m.enabled then
            loadedCount = loadedCount + 1
            if m.standalone then standaloneMod = m end
        end
    end
    if standaloneMod and loadedCount > 1 then
        warn("standalone mod '" .. standaloneMod.id .. "' cannot run alongside other mods")
        standaloneMod.enabled = false
        ModAPI.unloadMod(standaloneMod.id)
        return
    end

    return mod
end

function ModAPI.loadAll(dir)
    dir = dir or "mods"
    if not love.filesystem.getInfo(dir) then return end

    local candidates = {}
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = dir .. "/" .. name
        local info = love.filesystem.getInfo(path)
        if info and info.type == "directory" and love.filesystem.getInfo(path .. "/init.lua") then
            local manifest = readManifest(path) or {}
            candidates[#candidates + 1] = {
                path = path,
                id = manifest.id or name,
                deps = ensureTable(manifest.dependencies),
                priority = manifest.priority or 100,
            }
        end
    end

    table.sort(candidates, function(a, b)
        if a.priority == b.priority then return a.id < b.id end
        return a.priority < b.priority
    end)
    local remaining = candidates
    while #remaining > 0 do
        local progressed = false
        local stillWaiting = {}

        for i = 1, #remaining do
            local c = remaining[i]
            if ModAPI.areDependenciesMet(c.deps) then
                ModAPI.loadMod(c.path)
                progressed = true
            else
                stillWaiting[#stillWaiting + 1] = c
            end
        end

        remaining = stillWaiting
        if not progressed then
            for i = 1, #remaining do
                warn("could not load '" .. remaining[i].id .. "': unresolved dependencies")
            end
            break
        end
    end

    ModAPI.emit("onModsLoaded", ModAPI.loadedMods)
end

function ModAPI.unloadMod(id)
    local mod = ModAPI.loadedMods[id]
    if not mod then return false end

    local removed = 0
    for _, reg in pairs(registries) do
        removed = removed + reg:removeOwned(id)
    end
    removeHooksOwnedBy(id)

    ModAPI.loadedMods[id] = nil
    for i = #ModAPI.loadOrder, 1, -1 do
        if ModAPI.loadOrder[i] == id then table.remove(ModAPI.loadOrder, i) end
    end

    ModAPI.needsWorldReset = true
    log("unloaded:", id, "(" .. removed .. " entries removed)")
    return true
end

function ModAPI.setEnabled(id, enabled)
    ModAPI.disabled[id] = (not enabled) or nil
    local mod = ModAPI.loadedMods[id]
    if mod then
        mod.enabled = enabled and true or false
        if not enabled then ModAPI.unloadMod(id) end
    end
    ModAPI.needsWorldReset = true
end

function ModAPI.reset()
    for _, reg in pairs(registries) do
        clearTable(reg.entries)
        for i = #reg.order, 1, -1 do reg.order[i] = nil end
        if reg.mirror then clearTable(reg.mirror) end
        reg:_touch()
    end
    clearTable(ModAPI.materials)
    clearTable(ModAPI.biomes)
    for i = #ModAPI.terrainLayers, 1, -1 do ModAPI.terrainLayers[i] = nil end

    for name in pairs(hooks) do hooks[name] = {} end
    for i = 1, #BUILTIN_HOOKS do hookList(BUILTIN_HOOKS[i]) end

    clearTable(ModAPI.loadedMods)
    for i = #ModAPI.loadOrder, 1, -1 do ModAPI.loadOrder[i] = nil end
    for i = #ModAPI.errors, 1, -1 do ModAPI.errors[i] = nil end

    ModAPI.needsWorldReset = false
end

function ModAPI.reloadAll(dir)
    ModAPI.reset()
    ModAPI.loadAll(dir)
    ModAPI.needsWorldReset = true
end

function ModAPI.applyChanges()
    if not ModAPI.needsWorldReset then return false end
    ModAPI.needsWorldReset = false
    return true
end

return ModAPI