local love, lg = require("love"), love.graphics
local ffi = require("ffi")
local glmod = require("source.gl.opengl")
local gl, GL = glmod.gl, glmod.GL

lg.setDefaultFilter("nearest", "nearest")
lg.setFrontFaceWinding("ccw")

local gamestate = "menu"
local m = math
local sqrt, floor, sin, cos, max, min, random, abs, huge = m.sqrt, m.floor, m.sin, m.cos, m.max, m.min, m.random, m.abs, m.huge

local src = "source."
local hud = src.."hud."
local proj = src.."projectile."
local menu = src.."menus."

local imgF = "image/"
local lastMouseX, lastMouseY = love.mouse.getPosition()

local camera = require(proj.."camera")
local countryball = require(src.."countryball")
local mobs = require(src.."mobs")
local ItemsModule = require(src.."items")
local Inventory = require(hud.."inv")
local Crafting = require(hud.."craft")
local Knapping = require(hud.."knap")
local verts = require(proj.."verts")
local Props = require(src.."props")
local utils = require(src.."utils")
local Collision = require(src.."collision")
local OptMenu = require(menu.."options")
local SkinsMenu = require(menu.."skins")
local ModsMenu = require(menu.."mods")
local ModAPI = require(src.."mod_api")
local Cursor = require(hud.."cursor")
local healthBar = require(hud.."health_bar")
local hungerBar = require(hud.."hunger_bar")
local Mapsave = require(proj.."mapsave")
local Particles = require(proj.."particles")
local skyBox = require(proj.."skybox")
local nightCycle = require(proj.."night_cycle")
local Audio = require(src.."audio")
local Console = require(src.."console")
local Transition = require("source.transition")

local visible_idk = {cursor = true, skyBox = false}
local clamp, perlin = utils.clamp, utils.fastPerlin

local particlesImgs = {
    smoke = lg.newImage(imgF.."smoke.png"),
    fire = lg.newImage(imgF.."placeholder.png"),
}

local itemsOnGround, itemTypes, items = ItemsModule.itemsOnGround, ItemsModule.itemTypes, ItemsModule.items

local chunkCfg = {size = 5, radius = 4}
local base_width, base_height = camera.hw * 2, camera.hh * 2
local renderDistance = chunkCfg.size * chunkCfg.radius
local renderDistanceSq = renderDistance * renderDistance

local bw, bh= 200, 200
local menuItems = {"Play", "Mods", "Skins", "Options", "Credits", "Quit"}
local selectedIndex, menuX, menuSpacing = 1, 20, base_height / 8
local menuCamX, menuCamZ, menuTargetCamX, menuTargetCamZ = 50, 50, 50, 50

local pauseOpen, pauseProgress = false, 0
local worldList = {}
local selectedWorldIndex = 1
local currentWorldName = nil

local pauseItems, pauseSelected = {"Resume", "Options", "Leave"}, 1
local pauseSmooth = 10
local prevGamestate = nil

local autosaveInterval = 30
local autosaveTimer = 0

local titleImage = lg.newImage(imgF.."menu/title.png")

materials = {}

function initializeMaterials()
    local baseMaterials = {
        grassNormal = imgF.."grass_type/normal.png",
        grassHot = imgF.."grass_type/hot.png",
        grassCold= imgF.."grass_type/cold.png",
        sandNormal = imgF.."sand_type/normal.png",
        sandGarnet= imgF.."sand_type/garnet.png",
        sandGypsum = imgF.."sand_type/gypsum.png",
        sandOlivine = imgF.."sand_type/olivine.png",
        sandPinkCoral = imgF.."sand_type/pink_coral.png",
        snow = imgF.."snow.png",
        waterSmall = imgF.."water_type/type1.png",
        waterMedium = imgF.."water_type/type2.png",
        waterDeep = imgF.."water_type/type3.png",
        stone = imgF.."stone_type/stone.png",
        granite = imgF.."stone_type/granite.png",
        gabbro = imgF.."stone_type/gabbro.png",
        porphyry = imgF.."stone_type/porphyry.png",
        basalt = imgF.."stone_type/granite.png",
        stone_dark = imgF.."stone_type/stone_dark.png",
        pumice = imgF.."stone_type/pumice.png",
        rhyolite = imgF.."stone_type/rhyolite.png",
        shale = imgF.."stone_type/shale.png",
        limestone = imgF.."stone_type/limestone.png",
        gravel = imgF.."gravel.png",
        sandWet = imgF.."sand_type/wet.png",
        oak = imgF.."oak.png",
        dirt = imgF.."dirt.png",
        lava = imgF.."lava.png",
        dirt_clay = imgF.."dirt_clay.png",
        farmland = imgF.."farmland.png",
        dirtWet = imgF.."dirtWet.png",
        farmlandWet = imgF.."farmlandWet.png",
        wood_planks = imgF.."wood.png",
    }
    for id, path in pairs(baseMaterials) do
        materials[id] = love.graphics.newImage(path)
    end
    for id, def in pairs(ModAPI.materials) do
        if def.path then
            materials[id] = love.graphics.newImage(def.path)
        end
    end
end

local Blocks = require(proj.."blocks")

local tileGrid, baseplateTiles, heights = {}, {}, {}
local mapSeed = os.time()

local function setSeed(seed)
    mapSeed = tonumber(seed) or os.time()
    math.randomseed(mapSeed)
    math.random(); math.random(); math.random()
end

local function getChunkCoord(v) return floor(v / chunkCfg.size) end

function determineBiome(h, t, h2, volc, x, z)
    local ctx = {height = h, temperature = t, humidity = h2, volcano = volc, x = x, z = z}

    for id, biome in pairs(ModAPI.biomes) do
        if biome.condition(ctx) then return id end
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
    
    if h < 2.3 then return "Beach" end
    
    if h > 6.0 and h2 < 0.2 then return "Canyon" end

    if h < 7.0 then
        if t < -0.15 then return "Tundra" end
        if t > 0.35 then return "Savanna" end
        if h2 > 0.65 then return "Forest" end
        if h2 > 0.35 then return "Grassland" end
        return "Plains"
    end

    return "Highlands"
end

local biomeToTexture = {
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
    Highlands = "stone",
    SnowPeak = "snow",
    Volcanic = "pumice"
}
local C_SCALE = 0.04
local C_BIOME_SCALE = 0.03
local C_VOLCANO_NOISE_SCALE = 0.04
local C_RIVER_FACTOR = 0.15
local C_VOLCANO_H_NOISE = 0.05
local C_CAVE_MASK_NOISE = 0.09

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

function createBaseplate(width, depth, seed, formatType)
    formatType = formatType or "normal"
    setSeed(seed)

    local nx, nz = width + 1, depth + 1
    local totalPoints = nx * nz
    local heights_buf = ffi.new("double[?]", totalPoints)

    local function h_index(x, z) return x * nz + z end
    local function set_h(x, z, v) heights_buf[h_index(x, z)] = v end
    local function get_h(x, z) 
        if x < 0 or x >= nx or z < 0 or z >= nz then return 0 end
        return heights_buf[x * nz + z]
    end
    if formatType == "flat" then
        for z = 0, depth do for x = 0, width do set_h(x, z, 2) end end
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
                local base = getFractalNoise(x, z, 3, 0.5, C_SCALE) * 8
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
                local volcanoNoise = perlin(x * C_VOLCANO_H_NOISE, z * C_VOLCANO_H_NOISE)
                if volcanoNoise > 0.95 then h = h + 6 + (volcanoNoise - 0.95) * 10 end
                local caveMask = perlin(x * C_CAVE_MASK_NOISE, z * C_CAVE_MASK_NOISE)
                if caveMask > 0.7 and h > 3 then h = h - caveMask * 2.5 end
                local riverNoise = perlin(x * 0.02, z * 0.02)
                local riverPath = math.abs(riverNoise)
                if riverPath < 0.04 then
                    h = h - (4.0 * (1 - (riverPath / 0.04))) 
                end
                local ctx = {x = x, z = z, height = h}
                for _, layer in ipairs(ModAPI.terrainLayers) do layer(ctx) end
                set_h(x, z, ctx.height)
            end
        end
    end
    baseplateTiles = {}
    tileGrid = {}
    local tileChunks = {}
    local idx = 1
    for z = 0, depth - 1 do
        for x = 0, width - 1 do
            tileGrid[x] = tileGrid[x] or {}

            local h1, h2 = get_h(x, z), get_h(x + 1, z)
            local h3, h4 = get_h(x + 1, z + 1), get_h(x, z + 1)
            local avgH = (h1 + h2 + h3 + h4) * 0.25
            local bNoise, tNoise, hNoise, vNoise = getBiomeNoise(x, z)
            local biomeID = determineBiome(avgH, tNoise, hNoise, vNoise, x, z)
            local biomeDef = ModAPI.biomes[biomeID]
            local texName
            if biomeDef and biomeDef.material then
                texName = biomeDef.material
            else
                texName = biomeToTexture[biomeID] or "grassNormal"
            end
            local detailNoise = perlin(x * 0.4, z * 0.4)
            if biomeID == "Beach" and detailNoise > 0.4 then texName = "gravel" end

            local tile = {
                {x, h1, z}, {x + 1, h2, z}, {x + 1, h3, z + 1}, {x, h4, z + 1},
                x = x, z = z, y = avgH, height = avgH, curHeight = avgH,
                biome = biomeID,
                textureName = texName,
                texture = nil,
                heights = {h1, h2, h3, h4},
                chunkX = getChunkCoord(x),
                chunkZ = getChunkCoord(z),
                needsMesh = true
            }
            tile.texture = materials[tile.textureName] or materials.grassNormal

            baseplateTiles[idx] = tile
            tileGrid[x][z] = tile
            local ck = tile.chunkX .. ":" .. tile.chunkZ
            tileChunks[ck] = tileChunks[ck] or {}
            table.insert(tileChunks[ck], idx)
            ModAPI.runHooks("onTileGenerate", tile)

            idx = idx + 1
        end
    end
    baseplateTiles._tileChunks = tileChunks
    if Blocks then Blocks.baseTiles = baseplateTiles end
    heights = {}
    for x = 0, width do
        heights[x] = {}
        for z = 0, depth do heights[x][z] = get_h(x, z) end
    end
end

local function getTileAt(x, z)
    x, z = floor(x), floor(z)
    if x < 0 or z < 0 then return nil end
    local col = tileGrid[x]
    return col and col[z]
end

local function getSafeSpawnY(x, z)
    local tile = getTileAt(x, z)
    if not tile then return 5 end
    return (tile.curHeight or tile.height or 0) + 1.5
end

local function refreshWorldList()
    worldList = {}
    local items = love.filesystem.getDirectoryItems(Mapsave.saveFolder)
    for _, name in ipairs(items) do
        local info = love.filesystem.getInfo(Mapsave.saveFolder .. "/" .. name .. "/mapsave.json")
        if info then table.insert(worldList, name) end
    end
    if #worldList == 0 then selectedWorldIndex = 0 else selectedWorldIndex = 1 end
end

local function regenerateMap(w, d, seed)
    setSeed(seed)
    createBaseplate(w, d, seed)
end

local function resetWorldFromMods()
    regenerateMap(bh, bw, mapSeed)
    updateTileMeshes(true)
end

local function createNewWorld(name)
    local nm = name or ("World_" .. tostring(os.time()))
    regenerateMap(bh, bw, mapSeed)
    Mapsave.save(baseplateTiles, materials, nm)
    currentWorldName = nm
    --Blocks.baseTiles = baseplateTiles
    
    local sx, sz = math.floor(bw/2), math.floor(bh/2)
    countryball.x = sx
    countryball.z = sz
    countryball.y = getSafeSpawnY(sx, sz)
    countryball.health = countryball.maxHealth
    countryball.hunger = countryball.maxHunger
    countryball.hungerExhaustion = 0
    Mapsave.saveCountryball(countryball, nm)
    
    Inventory.items = {}
    for i = 1, Inventory.maxSlots do Inventory.items[i] = nil end
    Inventory.selectedSlot = 1
    Inventory.heldItem = nil
    Inventory.heldCount = 0
    Mapsave.saveInventory(Inventory, nm)
    
    Blocks.placed = {}
    Mapsave.saveBlocks(Blocks.placed, nm)
    
    updateTileMeshes(true)
    gamestate = "game"
end
local function loadWorld(name)
    if not name then return end
    local loaded, loadedTileGrid = Mapsave.load(materials, nil, name)
    if loaded then
        baseplateTiles = loaded
        tileGrid = loadedTileGrid
        if not baseplateTiles._tileChunks then
            local tileChunks = {}
            local chunkSize = chunkCfg.size or 4
            for i, tile in ipairs(baseplateTiles) do
                local cx, cz = tile.chunkX, tile.chunkZ
                if cx == nil or cz == nil then
                    cx = math.floor((tile.x or 0) / chunkSize)
                    cz = math.floor((tile.z or 0) / chunkSize)
                    tile.chunkX = cx
                    tile.chunkZ = cz
                end
                local ck = tostring(cx) .. ":" .. tostring(cz)
                tileChunks[ck] = tileChunks[ck] or {}
                table.insert(tileChunks[ck], i)
            end
            baseplateTiles._tileChunks = tileChunks
        end
        --Blocks.baseTiles = baseplateTiles
        currentWorldName = name
        
        local cbState = Mapsave.loadCountryball(name)
        if cbState then
            countryball.x = cbState.x or countryball.x
            countryball.y = cbState.y or countryball.y
            countryball.z = cbState.z or countryball.z
            countryball.health = cbState.health or countryball.health
            countryball.hunger = cbState.hunger or countryball.hunger
            countryball.hungerExhaustion = cbState.hungerExhaustion or 0
            countryball.flip = cbState.flip or false
        end
        
        local invData = Mapsave.loadInventory(name)
        if invData then
            Inventory.items = {}
            for i = 1, (invData.maxSlots or Inventory.maxSlots) do
                if invData.items[i] then
                    Inventory.items[i] = {
                        type = invData.items[i].type,
                        count = invData.items[i].count,
                        durability = invData.items[i].durability
                    }
                end
            end
            Inventory.selectedSlot = invData.selectedSlot or 1
            Inventory.heldItem = invData.heldItem
            Inventory.heldCount = invData.heldCount or 0
            Inventory.heldDurability = invData.heldDurability
        end
        
        updateTileMeshes(true)
        gamestate = "game"
    end
end

local function deleteWorld(name)
    if not name then return end
    local folder = Mapsave.saveFolder .. "/" .. name
    local saveFile = folder .. "/mapsave.json"
    if love.filesystem.getInfo(saveFile) then
        love.filesystem.remove(saveFile)
    end
    if love.filesystem.getInfo(folder) then
        pcall(function() love.filesystem.remove(folder) end)
    end
    refreshWorldList()
end

local dirtTimers = {}
local DIRT_TO_GRASS_TIME = 30

--Blocks.baseTiles = baseplateTiles
local preloadedTiles = {}
function updateTileMeshes(force)
    if not force and math.abs(camera.x - lastCamX) < 0.1 and math.abs(camera.z - lastCamZ) < 0.1 then
        return
    end
    lastCamX, lastCamZ = camera.x, camera.z

    local camChunkX, camChunkZ = getChunkCoord(camera.x), getChunkCoord(camera.z)
    local r = chunkCfg.radius
    local tilesToRender = {}
    for cz = camChunkZ - r, camChunkZ + r do
        for cx = camChunkX - r, camChunkX + r do
            local key = cx .. ":" .. cz
            local tileIndices = baseplateTiles._tileChunks[key]
            
            if tileIndices then
                for i = 1, #tileIndices do
                    local tile = baseplateTiles[tileIndices[i]]
                    table.insert(tilesToRender, tile)
                end
            end
        end
    end
    preloadedTiles = verts.generate(tilesToRender, camera, renderDistanceSq, tileGrid, materials)
    verts.ensureAllMeshes(preloadedTiles, materials.grass or materials.waterSmall)
end

local baseScale = 3
local function drawWithStencil(objX, objY, objZ, img, flip, rotation, alpha, yOffset)
    if not img then return end
    local objChunkX, objChunkZ = getChunkCoord(objX), getChunkCoord(objZ)
    local camChunkX, camChunkZ = getChunkCoord(camera.x), getChunkCoord(camera.z)
    if (objChunkX - camChunkX)^2 + (objChunkZ - camChunkZ)^2 > chunkCfg.radius^2 then
        return
    end
    
    local sx, sy, z = camera:project3D(objX, objY + (yOffset or -0.04), objZ)
    if not sx or z <= 0 then return end

    local scale = (camera._f / z) * (baseScale/1.25)
    local w, h = img:getWidth(), img:getHeight()
    local textureMul = nightCycle.getTextureMultiplier() or {1,1,1}

    lg.push("all")
    lg.setDepthMode("lequal", true)
    --clipping was useless
    lg.setColor(textureMul[1], textureMul[2], textureMul[3], alpha or 1)
    lg.draw(img, sx, sy, rotation or 0, flip and -scale or scale, scale, w / 2, h)
    lg.pop()
end

local function isCursorOverInteractive(mx, my)
    mx = mx or love.mouse.getX()
    my = my or love.mouse.getY()
    for _, item in ipairs(itemsOnGround) do
        local sx, sy2, z2 = camera:project3D(item.x, item.y, item.z)
        if sx and z2 > 0 then
            local scale = (1 / z2) * 6
            local img = ItemsModule.getItemImage(item.type)
            if img then
                local w, h = img:getWidth(), img:getHeight()
                local left, top = sx - w/2 * scale, sy2 - h * scale
                local right, bottom = left + w * scale, top + h * scale
                if mx >= left and mx <= right and my >= top and my <= bottom then
                    return true
                end
            end
        end
    end
    if Props and Props.props then
        for _, prop in ipairs(Props.props) do
            local px, py, pz = prop.x or prop.posX or prop.xpos, prop.y or prop.posY or prop.ypos, prop.z or prop.posZ or prop.zpos
            local img = prop.img or prop.image or prop.sprite or prop.texture
            if px and py and pz and img then
                local sx, sy2, z2 = camera:project3D(px, py, pz)
                if sx and z2 > 0 then
                    local w, h = img:getWidth(), img:getHeight()
                    local scale = (camera.hw / z2) * camera.zoom * 0.0025 * 3.0
                    if prop.scale then scale = scale * prop.scale end
                    local left, top = sx - w/2 * scale, sy2 - h * scale
                    local right, bottom = left + w * scale, top + h * scale
                    if mx >= left and mx <= right and my >= top and my <= bottom then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function revealUnderground(tile)
    if not tile or not tile.subsurface or #tile.subsurface == 0 then
        tile.texture = materials.stone
        tile.textureName = "stone"
        return
    end

    local nextMatName = table.remove(tile.subsurface, 1)
    if nextMatName and materials[nextMatName] then
        tile.texture = materials[nextMatName]
        tile.textureName = nextMatName
    else
        tile.texture = materials.stone
        tile.textureName = "stone"
    end
end

function breakTileAt(tileX, tileZ)
    local col = tileGrid[tileX]
    if not col then return end
    local tile = col[tileZ]
    if not tile then return end
    tile.height = tile.height - 1
    for i = 1, 4 do
        tile[i][2] = tile[i][2] - 1
    end
    if tile.height <= 0 then
        tile.isAir = true
        tile.texture = nil
        tile.textureName = nil
        for i = 1, 4 do tile[i][2] = 0 end
        tile.subsurface = nil
    else
        revealUnderground(tile)
    end
    tile.showSide = true
    updateTileMeshes(true)
end

local unbreakableMaterials = {
    waterSmall = true,
    waterMedium = true,
    waterDeep = true,
    lava = true,
}

local blockPlacables = {
    oak = true,
    stone = true,
    dark_stone = true,
    phenocryst = true
}

function isMouseOnItem(mx, my, item, image, scale, sx, sy2)
    local w, h = image:getWidth(), image:getHeight()
    local halfW, scaledH = (w * scale) * 0.5, h * scale
    local left = sx - halfW
    local top = sy2 - scaledH
    local right = sx + halfW
    local bottom = sy2

    return mx >= left and mx <= right and my >= top and my <= bottom
end

local function getGrassForBiome(tile)
    if not tile or not tile.biome then return materials.grassNormal end
    return materials[biomeToTexture[tile.biome]] or materials.grassNormal
end

local function tillTile(tile)
    if not tile or tile.isAir then return end
    local matName
    for k,v in pairs(materials) do
        if v == tile.texture then matName = k break end
    end
    if not matName then return end

    if matName == "grassNormal" or matName == "grassHot" or matName == "grassCold" or matName == "dirt" then
        tile.texture = materials.farmland
        updateTileMeshes(true)
    elseif matName == "grassNormal" then
        tile.texture = materials.dirt
        updateTileMeshes(true)
    end
end

local function scheduleDirt(tile)
    if tile and tile.texture == materials.dirt and tile.biome and not dirtTimers[tile] then
        dirtTimers[tile] = random() * DIRT_TO_GRASS_TIME
    end
end

local function updateDirtToGrass(dt)
    for _, tile in ipairs(baseplateTiles) do
        if tile.texture == materials.dirt and (tile.height == tile.curHeight or tile.subsurface[1] == "dirt") then
            scheduleDirt(tile)
        end
    end
    for tile, t in pairs(dirtTimers) do
        t = t - dt
        if t <= 0 then
            tile.texture = getGrassForBiome(tile)
            dirtTimers[tile] = nil
            updateTileMeshes(true)
        else
            dirtTimers[tile] = t
        end
    end
end

local function damageSelectedItem(amount)
    local slot = Inventory:getSelected()
    if not slot then return end

    local def = itemTypes[slot.type]
    if not def or not def.durability then return end
    if slot.durability == nil then
        slot.durability = def.durability
    end

    slot.durability = slot.durability - (amount or 1)
    if slot.durability <= 0 then
        slot.count = slot.count - 1
        slot.durability = nil

        if slot.count <= 0 then
            Inventory.items[Inventory.selectedSlot] = nil
        end
    end
end

local function hasCorrectTool(selected, matName)
    if not selected then return false end

    local itemDef = itemTypes[selected.type]
    if not itemDef or not itemDef.toolType then return false end

    local required = Blocks.bestTools[matName]
    return required and itemDef.toolType == required
end

function love.mousepressed(mx, my, button)
    if ModAPI.runHooks("onMousePressed", mx, my, button) then return end
    if not pauseOpen and gamestate == "game" then
        if Props and Props.handleMousePressed and Props.handleMousePressed(mx, my) then
            return
        end

        Inventory:mousepressed(mx, my, button, itemTypes)
        local slot = Inventory:getSelected()

        if Crafting.open then
            Crafting:mousepressed(mx, my, button, Inventory, itemTypes, ItemsModule, countryball)
            return
        end

        if Knapping.open then
            Knapping.timer = (Knapping.timer or 0) + love.timer.getDelta()
            if Knapping.timer >= 0.1 then
                Knapping:mousepressed(mx, my, button, Inventory, itemTypes, ItemsModule, countryball)
            end
            return
        end

        if button == 1 and slot and slot.type == "stone" and slot.count >= 2 and not isCursorOverInteractive(mx, my) and not Crafting.open then
            if not Knapping.open then
                slot.count = slot.count - 1
            end
            Knapping.open = true
            Knapping:resetGrid()
            Knapping.timer = 0
            if slot.count <= 0 then
                Inventory.items[Inventory.selectedSlot] = nil
            end
            return
        end
        if button == 2 then
            local selected = Inventory:getSelected()
            if selected and selected.type == "stone_hoe" then
                local tile, cx, cy, cz = getTileUnderCursor(mx, my)
                tillTile(tile)
                damageSelectedItem(1)
                return
            end
            if selected and selected.type == "firestarter" then
                local tile, cx, cy, cz = getTileUnderCursor(mx, my)
                if tile then
                    for i = 1, 10 do
                        Particles.spawnSmoke(particlesImgs.smoke, cx, cy + 0.5, cz)
                    end
                    damageSelectedItem(1)
                end
                return
            end
            if selected then
                ModAPI.runHooks("onItemUse", selected, getTileUnderCursor(mx, my), button)
                local itemDef = itemTypes[selected.type]
                if itemDef and itemDef.eatable then
                    ModAPI.runHooks("onEntityEat", countryball, itemDef)
                    if countryball.hunger < countryball.maxHunger then
                        countryball.hunger = math.min(countryball.hunger + 1,countryball.maxHunger)
                        selected.count = selected.count - 1
                        if selected.count <= 0 then
                            Inventory.items[Inventory.selectedSlot] = nil
                        end
                    end
                    return
                end
            end
            if selected and selected.type == "apple_seed" then
                local tile, cx, cy, cz = getTileUnderCursor(mx, my)
                if tile and Props.plantAppleSeed(tile, cx, cz) then
                    selected.count = selected.count - 1
                    if selected.count <= 0 then
                        Inventory.items[Inventory.selectedSlot] = nil
                    end
                end
                return
            end
        end
        for i = #itemsOnGround, 1, -1 do
            local item = itemsOnGround[i]
            local sx, sy2, z2 = camera:project3D(item.x, item.y, item.z)
            if sx and z2 > 0 then
                local scale = (1 / z2) * 6
                local img = ItemsModule.getItemImage(item.type)
                if img and isMouseOnItem(mx, my, item, img, scale, sx, sy2) then
                    if Inventory:hasFreeSlot() or Inventory:canAddEvenIfFull(item.type, itemTypes) then
                        Inventory:add(item.type, item.count, itemTypes, item.durability)
                        ItemsModule.removeItem(i)
                        return
                    end
                end
            end
        end
            local tile, cx, cy, cz, kind = getTileUnderCursor(mx, my)
            if tile and button == 1 then
                local selected = Inventory:getSelected()
                local baseMultiplier = selected and ItemsModule.getToolMultiplier(selected.type) or 0.5
                local multiplier = ModAPI.runHooks("onCalculateToolPower", selected, baseMultiplier) or baseMultiplier

                if kind == "block" then
                    local block = tile
                    local matName = block.type
                    if not matName or unbreakableMaterials[matName] then return end

                    local maxDur = Blocks.durabilities[matName] or 3
                    local br = Blocks.currentBreaking
                    if br.tile ~= block then
                        br.tile = block
                        br.progress = 0
                        br.max = maxDur
                    else
                        br.progress = br.progress + multiplier
                        if br.progress >= br.max then
                            ModAPI.runHooks("onBlockBreak", block, matName)

                            local requiresTool = Blocks.requiresTool[matName]
                            local correctTool = hasCorrectTool(selected, matName)

                            if not requiresTool or correctTool then
                                ItemsModule.dropItem(block.x, block.y + 1, block.z, matName, 1, nil, 0)
                            end

                            for i = #Blocks.placed, 1, -1 do
                                if Blocks.placed[i] == block then
                                    table.remove(Blocks.placed, i)
                                    break
                                end
                            end

                            br.tile = nil
                            br.progress = 0
                            damageSelectedItem(1)
                        end
                    end
                else
                    local matName
                    for k,v in pairs(materials) do
                        if v == tile.texture then matName = k break end
                    end
                    if not matName or unbreakableMaterials[matName] then return end

                    local maxDur = Blocks.durabilities[matName] or 3
                    local br = Blocks.currentBreaking
                    if br.tile ~= tile then
                        br.tile = tile
                        br.progress = 0
                        br.max = maxDur
                    else
                        br.progress = br.progress + multiplier
                        if br.progress >= br.max then
                            local matName = tile.textureName or nil

                            local requiresTool = Blocks.requiresTool[matName]
                            local correctTool = hasCorrectTool(selected, matName)

                            if not requiresTool or correctTool then
                                ItemsModule.dropItem(cx, cy+1, cz, matName, 1, nil, 0)
                            end
                            ModAPI.runHooks("onTileBreak", tile, matName, cx, cy, cz)

                            breakTileAt(floor(tile[1][1]), floor(tile[1][3]))
                            br.tile = nil
                            br.progress = 0
                            damageSelectedItem(1)
                        end
                    end
                end
            end
        if button == 2 then
            local selected = Inventory:getSelected()
            local hitObj, cx, cy, cz, kind = getTileUnderCursor(mx, my, 20)
            if hitObj and selected and itemTypes[selected.type] and itemTypes[selected.type].toolType == "axe" and kind == "block" and hitObj.type == "oak" then
                hitObj.type = "wood_planks"
                hitObj.texture = materials.wood_planks or materials.stone
                damageSelectedItem(1)
                return
            end
            if selected and blockPlacables[selected.type] then
                if hitObj then
                    local newX, newY, newZ
                    if kind == "block" then
                        local dx, dy, dz = cx - hitObj.x, cy - hitObj.y, cz - hitObj.z
                        if math.abs(dy) > math.abs(dx) and math.abs(dy) > math.abs(dz) then
                            newX, newY, newZ = hitObj.x, hitObj.y + (dy > 0 and 1 or -1), hitObj.z
                        elseif math.abs(dx) > math.abs(dy) and math.abs(dx) > math.abs(dz) then
                            newX, newY, newZ = hitObj.x + (dx > 0 and 1 or -1), hitObj.y, hitObj.z
                        else
                            newX, newY, newZ = hitObj.x, hitObj.y, hitObj.z + (dz > 0 and 1 or -1)
                        end
                    else
                        newX, newY, newZ = math.floor(cx) + 0.5, math.floor(cy) + 0.5, math.floor(cz) + 0.5
                    end
                    
                    Blocks.place(newX, newY, newZ, selected.type)
                    selected.count = selected.count - 1
                    if selected.count <= 0 then Inventory.items[Inventory.selectedSlot] = nil end
                end
            end
        end
    end
end

function love.mousereleased(mx, my, button)
    if not Crafting.open then
        Inventory:mousereleased(mx, my, button, ItemsModule, countryball)
    else
        --Crafting:mousereleased(mx, my, button, Inventory)
    end
end

local function expEase(current, target, speed, dt)
    return current + (target - current) * (1 - math.exp(-speed * dt))
end

local title = {
    x = base_width + 400,
    y = 30,
    rot = 0,
    scale = 1.2,
    float = 0,
    targetX = base_width - titleImage:getWidth() - 30,
    intro = 0
}

local menuAnim = {}
for i = 1, #menuItems do
    menuAnim[i] = {
        offset = 0,
        pulse = 0
    }
end

function love.update(dt)
    local mx, my = love.mouse.getPosition()
    love.timer.sleep(0.001)
    Transition.update(dt)
    Cursor.update(dt)
    if ModAPI.applyChanges() then
        print("Mods changed, regenerating world...")
        initializeMaterials()
        resetWorldFromMods()
    end
    updateTileMeshes(true)
    ModAPI.runHooks("update", dt, baseplateTiles, tileGrid)
    Console:installGlobalHooks()
    if visible_idk.cursor then love.mouse.setVisible(false) else love.mouse.setVisible(true) end
    SkinsMenu:update(dt)
    if gamestate == "menu" or gamestate == "options" or gamestate == "skins" or gamestate == "mods" then
        local dx = (mx / base_width - 0.5) * 6
        local dz = (my / base_height - 0.5) * 6
        menuTargetCamX = bw / 2 + dx + math.sin(love.timer.getTime() * 0.4) * 0.2
        menuTargetCamZ = bh / 2 + dz + math.cos(love.timer.getTime() * 0.4) * 0.2
        menuCamX = expEase(menuCamX, menuTargetCamX, 4, dt)
        menuCamZ = expEase(menuCamZ, menuTargetCamZ, 4, dt)

        camera.x, camera.z = menuCamX, menuCamZ
        local targetY = getTileAt(camera.x, camera.z).height + 2.5
        camera.y = expEase(camera.y, targetY, 4, dt)
        title.intro = math.min(title.intro + dt * 0.9, 1)
        local overshoot = math.sin(title.intro * math.pi) * 40

        title.x = expEase(title.x,title.targetX - overshoot,6,dt)

        title.scale = expEase(title.scale, 1, 5, dt)
        title.rot = math.sin(love.timer.getTime() * 0.6) * 0.02
        title.float = math.sin(love.timer.getTime() * 1.5) * 6
        for i = 1, #menuItems do
            local anim = menuAnim[i]
            local target = (i == selectedIndex) and 16 or 0
            anim.offset = expEase(anim.offset, target, 10, dt)
            anim.pulse = anim.pulse + dt * ((i == selectedIndex) and 6 or 2)
        end

        return
    end
    if gamestate == "game" then
        nightCycle.update(dt)
        verts.setTime(nightCycle.time)
        Particles.updateSmoke(dt)
        updateDirtToGrass(dt)
        local target = pauseOpen and 1 or 0
        pauseProgress = pauseProgress + (target - pauseProgress) * (1 - math.exp(-pauseSmooth * dt))
        if pauseProgress < 1e-4 then pauseProgress = 0 end
        if 1 - pauseProgress < 1e-4 then pauseProgress = 1 end
        if not pauseOpen then
            local dtSpeed = camera.speed * dt
            local lki = love.keyboard.isDown
            if camera.free then
                if lki("w") then
                    local f = camera:getForward()
                    camera.x = camera.x + f.x * dtSpeed
                    camera.y = camera.y + f.y * dtSpeed
                    camera.z = camera.z + f.z * dtSpeed
                end
                if lki("s") then
                    local f = camera:getForward()
                    camera.x = camera.x - f.x * dtSpeed
                    camera.y = camera.y - f.y * dtSpeed
                    camera.z = camera.z - f.z * dtSpeed
                end
                if lki("a") then
                    local r = camera:getRight()
                    camera.x = camera.x - r.x * dtSpeed
                    camera.z = camera.z - r.z * dtSpeed
                end
                if lki("d") then
                    local r = camera:getRight()
                    camera.x = camera.x + r.x * dtSpeed
                    camera.z = camera.z + r.z * dtSpeed
                end
                local dx, dy = mx - lastMouseX, my - lastMouseY
                camera.yaw = camera.yaw - dx * camera.sensitivity
                camera.pitch = clamp(camera.pitch - dy * camera.sensitivity, -1.2, 1.2)
                lastMouseX, lastMouseY = mx, my
            else
                local sy, sp = 1.5 * dt, 1.2 * dt
                if lki("a") then camera.yaw = camera.yaw + sy end
                if lki("d") then camera.yaw = camera.yaw - sy end
                if lki("w") then camera.pitch = camera.pitch - sp end
                if lki("s") then camera.pitch = camera.pitch + sp end
                camera.pitch = clamp(camera.pitch, -1.2, 1.2)
                countryball.update(dt, love.keyboard, heights, materials, getTileAt, Blocks, camera, healthBar)
                local zoom = camera.zoom
                local d, h = 12 / zoom, 15 / zoom
                local yaw, pitch = camera.yaw, camera.pitch
                local cx = countryball.x - sin(yaw) * d
                local cz = countryball.z - cos(yaw) * d
                local cy = countryball.y - sin(pitch) * h
                local s = clamp(camera.smoothness * dt, 0, 1)
                camera.x = camera.x + (cx - camera.x) * s
                camera.y = camera.y + (cy - camera.y) * s
                camera.z = camera.z + (cz - camera.z) * s
            end
            if countryball.y <= -10 then healthBar:setHealth(0) end
            local mainSource = Audio.getSource("main")
            if mainSource and not mainSource:isPlaying() then mainSource:play() end
            healthBar:update(dt)
            hungerBar:update(dt)
            Knapping:update(dt)
            mobs.update(dt, getTileAt)
            local cue = Collision.updateEntity
            cue(countryball, dt, tileGrid)
            for _, t in ipairs(itemsOnGround) do
                cue(t, dt, tileGrid)
            end
            for _, p in ipairs(Props.props) do
                cue(p, dt, tileGrid)
            end
            for _, e in ipairs(mobs.entities) do
                cue(e, dt, tileGrid)
            end
            Inventory:update(dt)
            Crafting:update(dt)
            Props.updateProps(dt)
            Particles.updateSmoke(dt)
            autosaveTimer = autosaveTimer + dt
            if autosaveTimer >= autosaveInterval and currentWorldName then
                Mapsave.saveCountryball(countryball, currentWorldName)
                Mapsave.saveInventory(Inventory, currentWorldName)
                Mapsave.saveBlocks(Blocks.placed, currentWorldName)
                autosaveTimer = 0
            end
        end
    end
end

function getTileUnderCursor(mx, my, maxDistance)
    maxDistance = maxDistance or 100
    local rdx, rdy, rdz = camera:getRay(mx, my, base_width, base_height)

    local len = sqrt(rdx*rdx + rdy*rdy + rdz*rdz)
    local rdx, rdy, rdz = rdx/len, rdy/len, rdz/len
    rdx = -rdx
    rdz = rdz * 0.5
    
    local px, py, pz = camera.x, camera.y, camera.z
    local blocks = Blocks.placed

    for t = 0, maxDistance, 0.02 do
        local wx, wy, wz = px + rdx*t, py + rdy*t, pz + rdz*t
        for i = 1, #blocks do
            local block = blocks[i]
            if abs(wx - block.x) <= 0.5 and abs(wy - block.y) <= 0.5 and abs(wz - block.z) <= 0.5 then
                return block, block.x, block.y, block.z, "block"
            end
        end

        local tile = getTileAt(wx, wz)
        if tile and not tile.isAir then
            local t1, t2, t3, t4 = tile[1], tile[2], tile[3], tile[4]
            local avgY = (t1[2] + t2[2] + t3[2] + t4[2]) * 0.25
            
            if abs(wy - avgY) <= 0.15 then
                local cx = (t1[1] + t2[1] + t3[1] + t4[1]) * 0.25
                local cz = (t1[3] + t2[3] + t3[3] + t4[3]) * 0.25
                return tile, cx, avgY, cz, "terrain"
            end
        end
    end
end
skyBox.load()

function drawTiles()
    camera:updateProjectionConstants()
    lg.clear(false, true, false)
    lg.setDepthMode("lequal", true)
    if visible_idk.skyBox then
        lg.setDepthMode("always", false)
        local lightFactor = (nightCycle.getLight and nightCycle.getLight() or 1.0)
        lg.setColor(lightFactor, lightFactor, lightFactor, 1)
        skyBox.draw()
        lg.setColor(1, 1, 1, 1)
        lg.setDepthMode("lequal", true)
    end
    for i = 1, #preloadedTiles do
        local e = preloadedTiles[i]
        if e.mesh then
            lg.setColor(1, 1, 1, 1)
            lg.draw(e.mesh)
        end
    end
    local function getDistanceSq(obj)
        if not obj then return 0 end
        local ox, oy, oz = obj.x or 0, obj.y or 0, obj.z or 0
        local dx, dy, dz = ox - camera.x, oy - camera.y, oz - camera.z
        return dx*dx + dy*dy + dz*dz
    end

    local renderQueue = {}
    local blockEntries = Blocks.generate(camera, renderDistanceSq)

    local function addToQueue(obj, kind)
        table.insert(renderQueue, {
            dist = getDistanceSq(obj),
            kind = kind,
            obj = obj
        })
    end
    for _, p in ipairs(Props.props) do addToQueue(p, "prop") end
    for _, mob in ipairs(mobs.entities) do addToQueue(mob, "mob") end
    for _, item in ipairs(itemsOnGround) do addToQueue(item, "item") end
    addToQueue(countryball, "player")
    for i = 1, #blockEntries do addToQueue(blockEntries[i], "block") end
    table.sort(renderQueue, function(a, b)
        return a.dist > b.dist
    end)
    for _, entry in ipairs(renderQueue) do
        local e = entry.obj
        if entry.kind == "block" then
            lg.setColor(1, 1, 1, 1)
            for _, faceVerts in ipairs(e.faces) do
                lg.polygon("fill", faceVerts)
            end
        elseif entry.kind == "prop" then
            Props.drawProps({e}, drawWithStencil)
        elseif entry.kind == "item" then
            local img = ItemsModule.getItemImage(e.type)
            drawWithStencil(e.x, e.y, e.z, img, false)
        elseif entry.kind == "player" then
            e.draw(drawWithStencil, Inventory, ItemsModule)
        elseif entry.kind == "mob" then
            mobs.draw(drawWithStencil)
        end
    end

    Particles.drawSmoke(drawWithStencil)
    
    ModAPI.runHooks("draw")
    lg.setDepthMode("lequal", true)
end

function mainGame()
    lg.setDepthMode("lequal", true)
    drawTiles()
    lg.setDepthMode()
    local tile, cx, cy, cz = getTileUnderCursor(love.mouse.getX(), love.mouse.getY())
    if tile then
        local sx, sy, sz = camera:project3D(cx, cy + 0.05, cz)
        if sx then
            local scale = (camera.hw / sz) * camera.zoom * 0.05
            lg.setColor(1, 0, 0, 0.6)
            lg.circle("line", sx, sy, scale)
            lg.setColor(1, 1, 1, 1)
        end
    end

    healthBar:draw()
    hungerBar:draw()
    Crafting:draw(Inventory, itemTypes, items)
    Knapping:draw(Inventory, itemTypes)
    if not Knapping.open then
        Inventory:draw(itemTypes)
    end

    if pauseProgress > 0 then
        local alpha = pauseProgress * 0.9
        lg.setColor(0, 0, 0, 0.5 * alpha)
        lg.rectangle("fill", 0, 0, base_width, base_height)
        local centerX = base_width / 2
        local startY = base_height * 0.35
        local spacing = menuSpacing * 0.9
        for i, text in ipairs(pauseItems) do
            local slideOffset = (1 - pauseProgress) * 80
            local y = startY + (i - 1) * spacing + slideOffset
            local isSelected = (i == pauseSelected)
            local borderColor = {0, 0, 0, alpha}
            local textColor = isSelected and {1, 1, 0, alpha} or {1, 1, 1, alpha}
            utils.drawTextWithBorder(text, centerX / font:getWidth(text), y, base_width, "center", borderColor, textColor)
        end
        lg.setColor(1,1,1,1)
    end
end

local gradientWidth = base_width * 0.5
gradientUhh = love.graphics.newMesh({
    {0, 0, 0, 0, 0, 0, 0, 1},
    {gradientWidth, 0, 1, 0, 0, 0, 0, 0},
    {gradientWidth, base_height, 1, 1, 0, 0, 0, 0},
    {0, base_height, 0, 1, 0, 0, 0, 1},
}, "fan")

function menuScreen()
    lg.setDepthMode("lequal", true)
    drawTiles()
    lg.setDepthMode()

    lg.setColor(1, 1, 1, 1)
    lg.draw(gradientUhh, 0, 0)

    local maxPerRow = 2
    local buttonWidth = 150
    local buttonHeight = 40
    local spacingX = 20
    local spacingY = 30

    local startX = menuX
    local totalItems = #menuItems
    local totalRows = math.ceil(totalItems / maxPerRow)
    local totalHeight = totalRows * buttonHeight + (totalRows - 1) * spacingY
    local startY = (base_height - totalHeight) / 2

    for i, text in ipairs(menuItems) do
        local anim = menuAnim[i]

        local col = (i-1) % maxPerRow
        local row = math.floor((i-1) / maxPerRow)

        local x = startX + col * (buttonWidth + spacingX)
        local y = startY + row * (buttonHeight + spacingY)

        local isSelected = (i == selectedIndex)
        local boxColor = {0, 0, 0, 0.5}
        local textColor = isSelected and {1, 1, 0} or {1, 1, 1}
        lg.setColor(boxColor)
        lg.rectangle("fill", x, y, buttonWidth, buttonHeight)
        lg.setColor(1, 1, 1)
        utils.drawTextWithBorder(text,x,y + buttonHeight/2 - font:getHeight()/2,buttonWidth,"center",{0, 0, 0},textColor)
    end

    local text = "2026 REVIVAL"
    utils.drawTextWithBorder(text, base_width - font:getWidth(text) - 10, base_height - 30, base_width)

    lg.push()
    lg.translate(title.x + titleImage:getWidth()/2, title.y + title.float + titleImage:getHeight()/2)
    lg.rotate(title.rot)
    lg.scale(title.scale, title.scale)
    lg.draw(titleImage, -titleImage:getWidth()/2, -titleImage:getHeight()/2)
    lg.pop()
end

local function worldSelectScreen()
    drawTiles()
    lg.setDepthMode()
    utils.drawTextWithBorder("Select World", 50, 30)

    local startY = 80
    local spacing = 35

    if #worldList == 0 then
        utils.drawTextWithBorder("No worlds found. Press 'C' to create.", 50, startY, {1, 0.5, 0.5})
    else
        for i, name in ipairs(worldList) do
            local isSelected = (i == selectedWorldIndex)
            local yPos = startY + (i - 1) * spacing
            local displayName = isSelected and ("> " .. name) or ("  " .. name)
            local textColor = isSelected and {1, 1, 0} or {0.8, 0.8, 0.8}
            
            utils.drawTextWithBorder(displayName, 60, yPos, base_width, "left", {0, 0, 0}, textColor)
        end
    end
    lg.setColor(1, 1, 1, 0.8) 
    local footerText = "[Enter] Play  |  [C] Create  |  [D] Delete  |  [Esc] Back"
    utils.drawTextWithBorder(footerText, 20, base_height - 40)
    lg.setColor(1, 1, 1, 1)
end

function love.draw()
    local r, g, b = unpack(nightCycle.getSkyColor())
    lg.clear(r, g, b, 1, true, true)
    if gamestate == "game" then
        mainGame()
    elseif gamestate == "menu" then
        menuScreen()
    elseif gamestate == "worldselect" then
        worldSelectScreen()
    elseif gamestate == "options" then
        drawTiles()
        OptMenu:draw()
    elseif gamestate == "mods" then
        drawTiles()
        ModsMenu:draw()
    elseif gamestate == "skins" then
        drawTiles()
        SkinsMenu:draw()
    elseif gamestate == "credits" then
        drawTiles()
    end
    Transition.draw(base_width, base_height)
    utils.drawTextWithBorder("FPS: "..love.timer.getFPS(), 10, 5)
    Console:draw()
    if visible_idk.cursor then
        Cursor.draw()
    end
end
function love.load()
    love.window.setMode(base_width, base_height, {resizable=true, vsync=true, depth = 24, stencil = 8, msaa = 0, highdpi = false})
    Console:installGlobalHooks()
    print("i guess bro")
    love.window.setTitle("A Random Countryball Game")
    love.window.setIcon(love.image.newImageData("icon/icon.png"))
    initializeMaterials()
    local loaded, loadedTileGrid, meta = Mapsave.load(materials)
    if loaded then
        baseplateTiles = loaded
        tileGrid = loadedTileGrid
        mapSeed = meta.seed
        if not baseplateTiles._tileChunks then
            local tileChunks = {}
            local chunkSize = chunkCfg.size or 4
            for i, tile in ipairs(baseplateTiles) do
                local cx, cz = tile.chunkX, tile.chunkZ
                if cx == nil or cz == nil then
                    cx = math.floor((tile.x or 0) / chunkSize)
                    cz = math.floor((tile.z or 0) / chunkSize)
                    tile.chunkX = cx
                    tile.chunkZ = cz
                end
                local ck = tostring(cx) .. ":" .. tostring(cz)
                tileChunks[ck] = tileChunks[ck] or {}
                table.insert(tileChunks[ck], i)
            end
            baseplateTiles._tileChunks = tileChunks
        end
    else
        createBaseplate(bw,bh)
    end
    Props.spawnProps(200, bw, bh, getTileAt)
    mobs.spawn("racoon_dog", 14, 14, getTileAt)
    Cursor.load()
    font = lg.newFont("font/font.ttf", 26)
    lg.setFont(font)
    OptMenu:load(camera, chunkCfg, visible_idk)

    SkinsMenu.load()
    SkinsMenu.applySkin("countryball")
    ModsMenu.load()
    Audio.load()

    gl.glEnable(GL.DEPTH_TEST)
    gl.glEnable(GL.CULL_FACE)
    gl.glCullFace(GL.BACK)
    gl.glFrontFace(GL.CCW)

    updateTileMeshes(true)
    lg.setDepthMode("lequal", true)
end

function switchSong(name)
    Audio.switchSong(name)
end

function love.mousemoved(x, y, dx, dy)
    if camera.freeLook then
        camera.yaw = camera.yaw - dx * 0.5 * camera.sensitivity
        camera.pitch = camera.pitch - dy * 0.3 * camera.sensitivity
        if camera.pitch < -1.2 then camera.pitch = -1.2 end
        if camera.pitch > 1.2 then camera.pitch = 1.2 end
    end
end

function love.wheelmoved(x, y)
    camera.zoom = camera.zoom - y * 0.1
    if camera.zoom < 0.5 then camera.zoom = 0.5 end
    if camera.zoom > 2.5 then camera.zoom = 2.5 end
end

function love.keypressed(key)
    if gamestate == "menu" then
        local maxPerRow = 2

        if key == "left" then
            selectedIndex = selectedIndex - 1
            if selectedIndex < 1 then
                selectedIndex = #menuItems
            end
        elseif key == "right" then
            selectedIndex = selectedIndex + 1
            if selectedIndex > #menuItems then
                selectedIndex = 1
            end
        elseif key == "up" then
            selectedIndex = selectedIndex - maxPerRow
            if selectedIndex < 1 then
                local col = (selectedIndex - 1) % maxPerRow
                selectedIndex = #menuItems + col + 1
                if selectedIndex > #menuItems then
                    selectedIndex = #menuItems
                end
            end
        elseif key == "down" then
            selectedIndex = selectedIndex + maxPerRow
            if selectedIndex > #menuItems then
                local col = (selectedIndex - 1) % maxPerRow
                selectedIndex = col + 1
            end
        elseif key == "return" then
            local selected = menuItems[selectedIndex]

            if selected == "Play" then
                refreshWorldList()
                Transition.startFade(0.5, function()
                    gamestate = "worldselect"
                end)
            elseif selected == "Mods" then
                Transition.startFade(0.5, function()
                    gamestate = "mods"
                end)
            elseif selected == "Skins" then
                Transition.startFade(0.5, function()
                    gamestate = "skins"
                end)
            elseif selected == "Options" then
                Transition.startFade(0.5, function()
                    gamestate = "options"
                end)
            elseif selected == "Credits" then
                Transition.startFade(0.5, function()
                    gamestate = "credits"
                end)
            elseif selected == "Quit" then
                love.event.quit()
            end
        end
    elseif gamestate == "worldselect" then
        if key == "up" then
            selectedWorldIndex = selectedWorldIndex - 1
            if selectedWorldIndex < 1 then selectedWorldIndex = #worldList end
        elseif key == "down" then
            selectedWorldIndex = selectedWorldIndex + 1
            if selectedWorldIndex > #worldList then selectedWorldIndex = 1 end
        elseif key == "c" then
            createNewWorld()
        elseif key == "d" then
            if worldList[selectedWorldIndex] then deleteWorld(worldList[selectedWorldIndex]) end
        elseif key == "return" then
            if worldList[selectedWorldIndex] then loadWorld(worldList[selectedWorldIndex]) end
        elseif key == "escape" then
            Transition.startFade(0.5, function()
                gamestate = "menu"
            end)
        end
    elseif gamestate == "game" then
        if key == "escape" and Knapping.open then
            Knapping.open = false
            return
        end
        if key == "escape" and Crafting.open then
            Crafting.open = false
            return
        end
        if key == "k" then
            camera.free = not camera.free
            love.mouse.setRelativeMode(camera.free)
            if camera.free then
                lastMouseX, lastMouseY = love.mouse.getPosition()
            end
        end
        if pauseOpen then
            if key == "up" then
                pauseSelected = pauseSelected - 1
                if pauseSelected < 1 then pauseSelected = #pauseItems end
            elseif key == "down" then
                pauseSelected = pauseSelected + 1
                if pauseSelected > #pauseItems then pauseSelected = 1 end
            elseif key == "return" then
                local choice = pauseItems[pauseSelected]
                if choice == "Resume" then
                    pauseOpen = false
                    love.mouse.setVisible(false)
                elseif choice == "Options" then
                    prevGamestate = "game"
                    gamestate = "options"
                    pauseOpen = false
                    love.mouse.setVisible(false)
                elseif choice == "Leave" then
                    pauseOpen = false
                    love.mouse.setVisible(false)
                    Transition.startFade(0.5, function()
                        gamestate = "menu"
                    end)
                end
            elseif key == "escape" then
                pauseOpen = not pauseOpen
                if pauseOpen then
                    pauseSelected = 1
                end
            end
            return
        end
        if key == "e" and not Knapping.open then Crafting:toggle() end
        Inventory:keypressed(key, itemTypes)

        if key == "q" then healthBar:damageHealth(1) end

        if key == "f5" then
            Mapsave.save(baseplateTiles, materials, currentWorldName, {seed = mapSeed})
        end

        if key == "escape" then
            pauseOpen = not pauseOpen
            if pauseOpen then
                pauseSelected = 1
            end
        end
    elseif gamestate == "options" then
        OptMenu:keypressed(key, camera, chunkCfg, visible_idk)
        if key == "escape" and OptMenu.state ~= "items" then
            gamestate = prevGamestate or "menu"
            prevGamestate = nil
        end
    elseif gamestate == "skins" then
        SkinsMenu:keypressed(key)
        if key == "escape" then
            Transition.startFade(0.5, function()
                gamestate = "menu"
            end)
        end
    elseif gamestate == "credits" then
        if key == "escape" then
            Transition.startFade(0.5, function()
                gamestate = "menu"
            end)
        end
    elseif gamestate == "mods" then
        ModsMenu:keypressed(key)
        ModAPI.reset()
        if key == "escape" then
            Transition.startFade(0.5, function()
                gamestate = "menu"
            end)
        end
    end
    if key == "f1" then
        Console:toggle()
        return
    end
end

function love.resize(w, h)
    camera:updateProjectionConstants(w, h)
end

function love.quit()
end