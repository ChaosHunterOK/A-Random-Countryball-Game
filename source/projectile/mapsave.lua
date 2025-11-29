local love = require("love")
local json = require("source.dkjson")
local floor = math.floor

local Mapsave = {}

Mapsave.saveFolder = "mapsave"
Mapsave.saveFile = Mapsave.saveFolder .. "/mapsave.json"

if not love.filesystem.getInfo(Mapsave.saveFolder) then
    love.filesystem.createDirectory(Mapsave.saveFolder)
end

local function buildMaterialLookup(materials)
    local lookup = {}
    for name, img in pairs(materials) do
        lookup[img] = name
    end
    return lookup
end

function Mapsave.save(baseplateTiles, materials)
    if not baseplateTiles then return end

    local texLookup = buildMaterialLookup(materials)
    local out = {}

    for _, tile in ipairs(baseplateTiles) do
        if tile[1] and tile.texture then

            local texName = texLookup[tile.texture] or "default"

            out[#out+1] = {
                verts = {
                    {tile[1][1], tile[1][2], tile[1][3]},
                    {tile[2][1], tile[2][2], tile[2][3]},
                    {tile[3][1], tile[3][2], tile[3][3]},
                    {tile[4][1], tile[4][2], tile[4][3]},
                },
                x = tile.x,
                y = tile.y,
                z = tile.z,
                w = tile.w,
                d = tile.d,
                h = tile.h,
                height = tile.height,
                curHeight = tile.curHeight,
                subsurface = tile.subsurface,
                containsCave = tile.containsCave,
                isVolcano = tile.isVolcano,
                biome = tile.biome,
                texture = texName
            }
        end
    end

    love.filesystem.write(Mapsave.saveFile, json.encode(out, { indent = true }))
end

function Mapsave.load(materials)
    if not love.filesystem.getInfo(Mapsave.saveFile) then return nil end

    local str = love.filesystem.read(Mapsave.saveFile)
    local ok, tbl = pcall(json.decode, str)
    if not ok or not tbl then return nil end

    local loadedTiles = {}
    local tileGrid = {}

    for _, t in ipairs(tbl) do
        local v = t.verts
        if not (v and v[1] and v[2] and v[3] and v[4]) then
            goto continue
        end

        local minX = math.min(v[1][1], v[2][1], v[3][1], v[4][1])
        local maxX = math.max(v[1][1], v[2][1], v[3][1], v[4][1])
        local minZ = math.min(v[1][3], v[2][3], v[3][3], v[4][3])
        local maxZ = math.max(v[1][3], v[2][3], v[3][3], v[4][3])
        local tile = {
            {v[1][1], v[1][2], v[1][3]},
            {v[2][1], v[2][2], v[2][3]},
            {v[3][1], v[3][2], v[3][3]},
            {v[4][1], v[4][2], v[4][3]},

            height = t.height or 0,
            curHeight = t.curHeight or t.height or 0,
            subsurface = t.subsurface,
            containsCave = t.containsCave,
            isVolcano = t.isVolcano,
            biome = t.biome,

            x = t.x or minX,
            z = t.z or minZ,
            y = t.y or (t.curHeight or t.height or 0),

            w = t.w or (maxX - minX),
            d = t.d or (maxZ - minZ),
            h = t.h or 1,

            texture = (t.texture and materials[t.texture]) or materials.default or nil,
        }
        tile.collision = {
            x = tile.x,
            y = tile.y,
            z = tile.z,
            w = tile.w,
            h = tile.h,
            d = tile.d
        }

        loadedTiles[#loadedTiles+1] = tile
        local gx = floor(tile.x + 0.5)
        local gz = floor(tile.z + 0.5)

        tileGrid[gx] = tileGrid[gx] or {}
        tileGrid[gx][gz] = tile

        ::continue::
    end

    return loadedTiles, tileGrid
end

return Mapsave