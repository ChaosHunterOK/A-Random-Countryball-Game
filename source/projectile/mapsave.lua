local love = require("love")
local json = require("source.dkjson")
local floor, min, max = math.floor, math.min, math.max

local fs = love.filesystem
local Mapsave = {}
Mapsave.saveFolder = "mapsave"

local function getFilePath(worldName, fileName)
    local folder = Mapsave.saveFolder .. "/" .. (worldName or "default")
    if not fs.getInfo(folder) then
        fs.createDirectory(folder)
    end
    return folder .. "/" .. fileName
end

local function loadJSON(path)
    if not fs.getInfo(path) then return nil end
    local str = fs.read(path)
    if not str or #str == 0 then return nil end
    local ok, data = pcall(json.decode, str)
    return ok and data or nil
end

local function saveJSON(path, data)
    local ok, encoded = pcall(json.encode, data, { indent = false })
    if not ok then return false end
    return fs.write(path, encoded)
end

local function buildMaterialLookup(materials)
    local lookup = {}
    if not materials then return lookup end
    for name, img in pairs(materials) do
        if img ~= nil then lookup[img] = name end
    end
    return lookup
end

function Mapsave.save(baseplateTiles, materials, worldName, extra)
    if not baseplateTiles or next(baseplateTiles) == nil then
        return false
    end
    
    local texLookup = buildMaterialLookup(materials)
    local out = {}

    for i = 1, #baseplateTiles do
        local tile = baseplateTiles[i]
        if type(tile) == "table" and tile[1] then
            out[#out + 1] = {
                verts = {
                    {tile[1][1], tile[1][2], tile[1][3]},
                    {tile[2][1], tile[2][2], tile[2][3]},
                    {tile[3][1], tile[3][2], tile[3][3]},
                    {tile[4][1], tile[4][2], tile[4][3]},
                },
                x = tile.x, y = tile.y, z = tile.z,
                w = tile.w, d = tile.d, h = tile.h,
                height = tile.height,
                heights = tile.heights,
                curHeight = tile.curHeight or tile.height or 0,
                subsurface = tile.subsurface,
                biome = tile.biome,
                containsCave = tile.containsCave, isVolcano = tile.isVolcano, chunkX = tile.chunkX, chunkZ = tile.chunkZ,
                textureName = texLookup[tile.texture] or tile.textureName or "default"
            }
        end
    end

    local data = {
        tiles = out,
        meta = extra or {}
    }

    saveJSON(getFilePath(worldName, "mapsave.json"), data)
end

function Mapsave.load(materials, baseplateTiles, worldName)
    local data = loadJSON(getFilePath(worldName, "mapsave.json"))
    if not data then return nil end

    local tbl = data.tiles or data
    local meta = data.meta or {}

    local loadedTiles = {}
    local tileGrid = {}
    local defMat = materials and materials.default

    for i = 1, #tbl do
        local t = tbl[i]
        local v = t.verts
        if v and v[1] and v[2] and v[3] and v[4] then
            local v1, v2, v3, v4 = v[1], v[2], v[3], v[4]

            local textureName = t.texture
            local resolvedTexture = defMat
            if materials and textureName then
                resolvedTexture = materials[textureName] or defMat
            end

            local tile = {
                {v1[1], v1[2], v1[3]},
                {v2[1], v2[2], v2[3]},
                {v3[1], v3[2], v3[3]},
                {v4[1], v4[2], v4[3]},

                height = t.height or 0,
                heights = t.heights or {},
                curHeight = t.curHeight or t.height or 0,

                x = t.x, y = t.y, z = t.z,
                w = t.w, d = t.d, h = t.h,

                biome = t.biome,
                subsurface = t.subsurface,
                containsCave = t.containsCave,
                isVolcano = t.isVolcano,
                chunkX = t.chunkX,
                chunkZ = t.chunkZ,
                textureName = textureName,
                texture = resolvedTexture
            }

            tile.collision = {
                x = tile.x, y = tile.y, z = tile.z,
                w = tile.w, h = tile.h, d = tile.d
            }

            table.insert(loadedTiles, tile)

            local gx, gz = floor(tile.x + 0.5), floor(tile.z + 0.5)
            tileGrid[gx] = tileGrid[gx] or {}
            tileGrid[gx][gz] = tile
        end
    end

    return loadedTiles, tileGrid, meta
end

function Mapsave.saveCountryball(state, worldName)
    if not state then return end
    saveJSON(getFilePath(worldName, "countryball.json"), {
        x = state.x, y = state.y, z = state.z,
        health = state.health, maxHealth = state.maxHealth,
        hunger = state.hunger, maxHunger = state.maxHunger,
        hungerExhaustion = state.hungerExhaustion,
        velocityY = state.velocityY,
        onGround = state.onGround, flip = state.flip,
    })
end

function Mapsave.loadCountryball(worldName)
    return loadJSON(getFilePath(worldName, "countryball.json"))
end

function Mapsave.saveInventory(state, worldName)
    if not state then return end
    local items = {}
    for i = 1, #state.items do
        local slot = state.items[i]
        if slot and slot.count > 0 then
            items[i] = { type = slot.type, count = slot.count, durability = slot.durability }
        end
    end
    saveJSON(getFilePath(worldName, "inventory.json"), {
        items = items, selectedSlot = state.selectedSlot, maxSlots = state.maxSlots,
        heldItem = state.heldItem, heldCount = state.heldCount, heldDurability = state.heldDurability
    })
end

function Mapsave.loadInventory(worldName)
    return loadJSON(getFilePath(worldName, "inventory.json"))
end

function Mapsave.saveBlocks(blocks, worldName)
    if not blocks or next(blocks) == nil then
        return false
    end
    local data = {}
    for i = 1, #blocks do
        local b = blocks[i]
        data[i] = { x = b.x, y = b.y, z = b.z, type = b.type }
    end
    saveJSON(getFilePath(worldName, "blocks.json"), data)
end

function Mapsave.loadBlocks(worldName)
    return loadJSON(getFilePath(worldName, "blocks.json"))
end

function Mapsave.saveProps(props, worldName)
    if not props or type(props) ~= "table" then
        return false
    end

    local data = {}
    for i = 1, #props do
        local p = props[i]
        data[i] = {
            type = p.type,
            typeIndex = p.typeIndex,
            x = p.x, y = p.y, z = p.z,
            health = p.health, maxHealth = p.maxHealth,
            shakeTimer = p.shakeTimer, shakeOffsetX = p.shakeOffsetX, shakeOffsetY = p.shakeOffsetY,
            length = p.length, stage = p.stage, growTimer = p.growTimer,
            isCut = p.isCut
        }
    end

    return saveJSON(getFilePath(worldName, "props.json"), data)
end

function Mapsave.loadProps(worldName)
    return loadJSON(getFilePath(worldName, "props.json"))
end

return Mapsave