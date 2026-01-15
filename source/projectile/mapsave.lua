local love = require("love")
local json = require("source.dkjson")
local countryball = require("source.countryball")
local floor = math.floor
local min = math.min
local max = math.max
local fs = love.filesystem

local Mapsave = {}

Mapsave.saveFolder = "mapsave"
Mapsave.saveFile = Mapsave.saveFolder .. "/mapsave.json"

if not fs.getInfo(Mapsave.saveFolder) then
    fs.createDirectory(Mapsave.saveFolder)
end

local function buildMaterialLookup(materials)
    local lookup = {}
    if not materials then return lookup end
    for name, img in pairs(materials) do
        if img ~= nil then
            lookup[img] = name
        end
    end
    return lookup
end

function Mapsave.save(baseplateTiles, materials, worldName)
    if not baseplateTiles or #baseplateTiles == 0 then return end

    local folder = Mapsave.saveFolder .. "/" .. (worldName or "default")
    if not fs.getInfo(folder) then
        fs.createDirectory(folder)
    end
    local saveFile = folder .. "/mapsave.json"

    local texLookup = buildMaterialLookup(materials)
    local out = {}

    for _, tile in ipairs(baseplateTiles) do
        if type(tile) == "table" and tile[1] then
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
                heights = tile.heights,
                curHeight = tile.curHeight,

                subsurface = tile.subsurface,
                containsCave = tile.containsCave,
                isVolcano = tile.isVolcano,

                chunkX = tile.chunkX,
                chunkZ = tile.chunkZ,

                texture = texName,
            }
        end
    end

    local encoded = json.encode(out, { indent = true })
    fs.write(saveFile, encoded)
end

function Mapsave.load(materials, baseplateTiles, worldName)
    local folder = Mapsave.saveFolder .. "/" .. (worldName or "default")
    local saveFile = folder .. "/mapsave.json"
    if not fs.getInfo(saveFile) then
        return nil
    end

    local str = fs.read(saveFile)
    if not str or #str == 0 then return nil end

    local ok, tbl = pcall(function() return json.decode(str) end)
    if not ok or type(tbl) ~= "table" then
        return nil
    end

    local loadedTiles = {}
    local tileGrid = {}
    local tileChunks = {}

    for _, t in ipairs(tbl) do
        local v = t.verts
        if not (v and v[1] and v[2] and v[3] and v[4]) then
        else
            local minX = min(v[1][1], v[2][1], v[3][1], v[4][1])
            local maxX = max(v[1][1], v[2][1], v[3][1], v[4][1])
            local minZ = min(v[1][3], v[2][3], v[3][3], v[4][3])
            local maxZ = max(v[1][3], v[2][3], v[3][3], v[4][3])

            local tex = (materials and materials[t.texture]) or (materials and materials.default) or nil

            local tile = {
                {v[1][1], v[1][2], v[1][3]},
                {v[2][1], v[2][2], v[2][3]},
                {v[3][1], v[3][2], v[3][3]},
                {v[4][1], v[4][2], v[4][3]},

                height = t.height or 0,
                heights = t.heights or {},
                curHeight = t.curHeight or (t.height or 0),

                subsurface = t.subsurface or {},
                containsCave = t.containsCave or false,
                isVolcano = t.isVolcano or false,

                x = t.x or minX,
                y = t.y or t.curHeight or t.height or 0,
                z = t.z or minZ,

                w = t.w or (maxX - minX),
                d = t.d or (maxZ - minZ),
                h = t.h or 1,

                chunkX = t.chunkX,
                chunkZ = t.chunkZ,

                texture = tex,
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
        end
    end

    return loadedTiles, tileGrid
end

return Mapsave