local Map = {}

local m = math
local sqrt, floor, sin, cos, max, min, random, abs = m.sqrt, m.floor, m.sin, m.cos, m.max, m.min, m.random, m.abs
local utils = require("source.utils.utils")
local perlin = utils.fastPerlin
local ModAPI = require("source.api.mod")

Map.chunkCfg = {size = 8, radius = 6}
Map.tileGrid = {}
Map.baseplateTiles = {}
Map.heights = {}
Map.mapSeed = os.time()
Map.heightOffset = 0
Map.seedOffsetX = 0
Map.seedOffsetZ = 0

local C_SCALE = 0.04
local C_BIOME_SCALE = 0.012
local C_VOLCANO_NOISE_SCALE = 0.04
local C_VOLCANO_H_NOISE = 0.05
local C_CAVE_MASK_NOISE = 0.09
local C_CONTINENTALNESS = 0.003
local C_EROSION = 0.010
local C_PEAKS = 0.015
local C_RIVER = 0.004
local C_LAKE = 0.020
local C_VALLEY = 0.008
local C_MOUNTAINS = 0.006
local C_CLIFF = 0.03
local C_PLATEAU = 0.005
Map.biomeToTexture = {
    OceanDeep = "waterDeep",
    OceanShallow = "waterMedium",
    Beach = "sandNormal",
    Desert = "sandNormal",
    GypsumDesert = "sandGypsum",
    GarnetDesert = "sandGarnet",
    OlivineDesert = "sandOlivine",
    Lake = "waterSmall",
    Canyon = "shale",
    Plains = "grassNormal",
    Grassland = "grassNormal",
    Forest = "grassNormal",
    Savanna = "grassHot",
    Tundra = "grassCold",
    Rainforest = "grassRainforest",
    Highlands = "stone",
    SnowPeak = "snow",
    Volcanic = "pumice",
    RockyLand = "stone",
}

Map.subsurfaceByBiome = {
    OceanDeep = {"sandWet", "sandWet", "stone"},
    OceanShallow = {"sandWet", "sandWet", "stone"},
    Beach = {"sandWet", "sandWet", "stone"},
    Desert = {"sandWet", "sandNormal", "stone"},
    GypsumDesert = {"sandWet", "sandGypsum", "stone"},
    GarnetDesert = {"sandWet", "sandGarnet", "stone"},
    OlivineDesert = {"sandWet", "sandOlivine", "stone"},
    Lake = {"dirt_clay", "dirt", "stone"},
    Canyon = {"stone", "shale", "stone"},
    Plains  = {"dirt", "dirt", "stone"},
    Grassland = {"dirt", "dirt", "stone"},
    Forest = {"dirt", "dirt_clay", "stone"},
    Savanna = {"dirt", "dirt", "stone"},
    Tundra = {"dirt", "stone", "stone"},
    Rainforest = {"dirt", "dirt_clay", "stone"},
    Highlands = {"stone", "stone"},
    SnowPeak = {"stone", "stone"},
    Volcanic = {"basalt", "basalt", "stone"},
    RockyLand = {"gravel", "stone", "stone_dark"},
}

function Map.buildSubsurface(biomeID, biomeDef)
    local template = (biomeDef and biomeDef.subsurface) or Map.subsurfaceByBiome[biomeID]
    if not template then return {"dirt", "stone"} end
    local out = {}
    for i = 1, #template do out[i] = template[i] end
    return out
end

local function setSeed(seed)
    Map.mapSeed = tonumber(seed) or os.time()
    math.randomseed(Map.mapSeed)
    math.random(); math.random(); math.random()
    Map.seedOffsetX = random(-100000, 100000)
    Map.seedOffsetZ = random(-100000, 100000)
end

function Map.getChunkCoord(v)
    return floor(v / Map.chunkCfg.size)
end

local modBiomeOrder = {}
local function refreshModBiomeOrder()
    local n = 0
    for id in pairs(ModAPI.biomes) do
        n = n + 1
        modBiomeOrder[n] = id
    end
    for i = n + 1, #modBiomeOrder do modBiomeOrder[i] = nil end
    table.sort(modBiomeOrder)
end

function Map.determineBiome(h, t, h2, volc, x, z)
    local ctx = {height = h, temperature = t, humidity = h2, volcano = volc, x = x, z = z}

    for i = 1, #modBiomeOrder do
        local id = modBiomeOrder[i]
        local biome = ModAPI.biomes[id]
        if biome and biome.condition(ctx) then return id end
    end
    
    if volc > 0.96 and h > 8 then return "Volcanic" end
    if h > 9.5 then return "SnowPeak" end
    if h < 0.8 then return "OceanDeep" end
    if h < 1.8 then return "OceanShallow" end
    if h < 2.2 and h2 > 0.6 then return "Lake" end
    
    if t > 0.5 and h2 < 0.25 then 
        if h2 < 0.08 then return "GarnetDesert" end 
        if h2 < 0.15 then return "GypsumDesert" end
        if t > 0.7 then return "OlivineDesert" end
        return "Desert"
    end
    
    if h < 2.3 then
        if h2 < 0.25 then return "RockyLand" end
        return "Beach"
    end
    
    if h > 6.0 and h2 < 0.2 then return "Canyon" end

    if h < 7.0 then
        if t < -0.2 then
            return "Tundra"
        end
        if t > 0.45 and h2 > 0.55 then
            return "Rainforest"
        end
        if t > 0.25 and h2 < 0.45 then
            return "Savanna"
        end
        if h2 > 0.60 then
            return "Forest"
        end
        if h2 > 0.35 then
            return "Grassland"
        end
        if h2 < 0.2 then
            return "RockyLand"
        end

        return "Plains"
    end

    return "Highlands"
end

local function getFractalNoise(x, z, octaves, persistence, scale)
    local total = 0
    local frequency = scale
    local amplitude = 1
    local maxValue = 0
    for i = 1, octaves do
        total = total + perlin(x * frequency, z * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    return total / maxValue
end

local function getBiomeNoise(x, z)
    return
        perlin(x * C_BIOME_SCALE, z * C_BIOME_SCALE),
        perlin(x * C_BIOME_SCALE * 0.6, z * C_BIOME_SCALE * 0.6 + 200),
        perlin(x * C_BIOME_SCALE * 1.2 + 400, z * C_BIOME_SCALE * 1.2 + 400),
        perlin(x * C_VOLCANO_NOISE_SCALE + 1000, z * C_VOLCANO_NOISE_SCALE + 1000)
end

function Map.createBaseplate(width, depth, seed, formatType, materials, Placements)
    formatType = formatType or "normal"
    setSeed(seed)
    refreshModBiomeOrder()

    local ox, oz = Map.seedOffsetX, Map.seedOffsetZ

    local nx, nz = width + 1, depth + 1
    local ffi = require("ffi")
    local totalPoints = nx * nz
    local heights_buf = ffi.new("double[?]", totalPoints)

    local function h_index(x, z) return x * nz + z end
    local function set_h(x, z, v) heights_buf[h_index(x, z)] = v end
    local function get_h(x, z) 
        if x < 0 or x >= nx or z < 0 or z >= nz then return 0 end
        return heights_buf[x * nz + z]
    end
    
    if formatType == "flat" then
        for z = 0, depth do for x = 0, width do set_h(x, z, 2 + Map.heightOffset) end end
    else
        local islands = {}
        for i = 1, 12 do
            islands[i] = {
                cx = random(5, width - 5), 
                cz = random(5, depth - 5),
                radius = random(2, 6),
                height = random(3, 8)
            }
        end

        for z = 0, depth do
            for x = 0, width do
                local base = getFractalNoise(x+ox, z+oz, 3, 0.5, C_SCALE) * 8
                local continentalness = getFractalNoise(x+ox, z+oz, 4, 0.55, C_CONTINENTALNESS)
                local erosion = getFractalNoise(x+ox+2000, z+oz+2000, 4, 0.5, C_EROSION)
                local peaks = getFractalNoise(x+ox+4000, z+oz+4000, 5, 0.45, C_PEAKS)
                local valley = getFractalNoise(x+ox+6000, z+oz+6000, 3, 0.5, C_VALLEY)
                local dx, dz = (x / width) - 0.5, (z / depth) - 0.5
                local dist = math.sqrt(dx*dx + dz*dz) * 2
                local mask = math.max(0, 1.2 - dist^1.5)
                local h = (base - 2) * mask
                for i = 1, #islands do
                    local isl = islands[i]
                    local distSq = (x - isl.cx)^2 + (z - isl.cz)^2
                    if distSq < isl.radius^2 then
                        h = h + isl.height * (1 - sqrt(distSq) / isl.radius)^1.2
                    end
                end
                local volcanoNoise = perlin((x+ox) * C_VOLCANO_H_NOISE, (z+oz) * C_VOLCANO_H_NOISE)
                if volcanoNoise > 0.95 then h = h + 6 + (volcanoNoise - 0.95) * 10 end
                local lakeNoise = getFractalNoise(x+ox+12000,z+oz+12000,3,0.5,C_LAKE)
                local caveMask = perlin((x+ox) * C_CAVE_MASK_NOISE, (z+oz) * C_CAVE_MASK_NOISE)
                if caveMask > 0.7 and h > 3 then h = h - caveMask * 2.5 end
                local river = abs(getFractalNoise(x+ox+9000,z+oz+9000,4,0.5,C_RIVER))
                if river < 0.04 then
                    h = h - (4.0 * (1 - (river / 0.04))) 
                end
                if lakeNoise > 0.68 and erosion > 0.65 and continentalness > 0.45 then
                    h = min(h, 1.6)
                end
                local mountainNoise = getFractalNoise(x+ox + 15000, z+oz + 15000, 5, 0.5, C_MOUNTAINS)
                if mountainNoise > 0.45 then
                    local strength = ((mountainNoise - 0.45) / 0.55)^2
                    h = h + strength * 18
                end
                local cliff = perlin((x+ox) * C_CLIFF + 900, (z+oz) * C_CLIFF + 900)
                if cliff > 0.7 then
                    h = floor(h + 0.5)
                end
                local plateau = getFractalNoise(x+ox+18000,z+oz+18000,4,0.5,C_PLATEAU)
                if plateau > 0.65 then
                    h = max(h,10)
                    h = floor(h)
                end
                h = h + Map.heightOffset
                local ctx = {x = x, z = z, height = h}
                for _, layer in ipairs(ModAPI.terrainLayers) do layer(ctx) end
                set_h(x, z, ctx.height)
            end
        end
    end
    
    Map.baseplateTiles = {}
    Map.tileGrid = {}
    local tileChunks = {}
    local idx = 1
    for z = 0, depth - 1 do
        for x = 0, width - 1 do
            Map.tileGrid[x] = Map.tileGrid[x] or {}

            local h1, h2 = get_h(x, z), get_h(x + 1, z)
            local h3, h4 = get_h(x + 1, z + 1), get_h(x, z + 1)
            local avgH = (h1 + h2 + h3 + h4) * 0.25
            local bNoise, tNoise, hNoise, vNoise = getBiomeNoise(x+ox, z+oz)
            local biomeID = Map.determineBiome(avgH, tNoise, hNoise, vNoise, x, z)
            local biomeDef = ModAPI.biomes[biomeID]
            local texName
            if biomeDef and biomeDef.material then
                texName = biomeDef.material
            else
                texName = Map.biomeToTexture[biomeID] or "grassNormal"
            end
            local detailNoise = perlin((x+ox) * 0.4, (z+oz) * 0.4)
            if biomeID == "Beach" and detailNoise > 0.4 then texName = "gravel" end
            local isLava = false
            if biomeID == "Volcanic" and vNoise > 0.985 then
                isLava = true
                if materials.lava then texName = "lava" end
            end

            local tile = {
                {x, h1, z}, {x + 1, h2, z}, {x + 1, h3, z + 1}, {x, h4, z + 1},
                x = x, z = z, y = avgH, height = avgH, curHeight = avgH,
                biome = biomeID,
                textureName = texName,
                texture = nil,
                heights = {h1, h2, h3, h4},
                chunkX = Map.getChunkCoord(x),
                chunkZ = Map.getChunkCoord(z),
                needsMesh = true,
                isLava = isLava,
                subsurface = Map.buildSubsurface(biomeID, biomeDef),
            }
            tile.texture = materials[tile.textureName] or materials.grassNormal

            Map.baseplateTiles[idx] = tile
            Map.tileGrid[x][z] = tile
            local ck = tile.chunkX .. ":" .. tile.chunkZ
            tileChunks[ck] = tileChunks[ck] or {}
            table.insert(tileChunks[ck], idx)
            ModAPI.runHooks("onTileGenerate", tile)

            idx = idx + 1
        end
    end
    Map.baseplateTiles._tileChunks = tileChunks
    if Placements then Placements.baseTiles = Map.baseplateTiles end
    Map.heights = {}
    for x = 0, width do
        Map.heights[x] = {}
        for z = 0, depth do Map.heights[x][z] = get_h(x, z) end
    end
end

function Map.getTileAt(x, z)
    x, z = floor(x), floor(z)
    if x < 0 or z < 0 then return nil end
    local col = Map.tileGrid[x]
    return col and col[z]
end

function Map.getSafeSpawnY(x, z)
    local tile = Map.getTileAt(x, z)
    if not tile then return 5 end
    return (tile.curHeight or tile.height or 0) + 1.5
end

function Map.regenerateMap(w, d, seed, materials, Placements)
    setSeed(seed)
    Map.createBaseplate(w, d, seed, "normal", materials, Placements)
end

return Map