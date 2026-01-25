local love, lg = require("love"), love.graphics
local ffi = require("ffi")
local glmod = require("source.gl.opengl")
local gl, GL = glmod.gl, glmod.GL

lg.setDefaultFilter("nearest", "nearest")
lg.setDepthMode("lequal", true)
lg.setFrontFaceWinding("ccw")

local gamestate = "menu"
local m = math
local sqrt, floor, sin, cos, max, min, random, abs, huge = m.sqrt, m.floor, m.sin, m.cos, m.max, m.min, m.random, m.abs, m.huge

local src = "source."
local hud = src.."hud."
local proj = src.."projectile."
local menu = src.."menus."

local imgF = "image/"

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

local visible_idk = {cursor = true, skyBox = false}
local clamp, perlin, getChunkKey = utils.clamp, utils.fastPerlin, utils.getChunkKey

local particlesImgs = {
    smoke = lg.newImage(imgF.."smoke.png")
}

local songs = {
    main = "music/music.mp3",
    menu = "music/menu.mp3"
}
local audioSources = {}

local itemsOnGround, itemTypes, items = ItemsModule.itemsOnGround, ItemsModule.itemTypes, ItemsModule.items

local chunkCfg = {size = 5, radius = 4}
local base_width, base_height = 1000, 525
local renderDistance = chunkCfg.size * chunkCfg.radius
local renderDistanceSq = renderDistance * renderDistance

function loadMaterials(tbl)
    local res = {}
    for k, path in pairs(tbl) do
        if love.filesystem.getInfo(path) then
            res[k] = lg.newImage(path)
        end
    end
    return res
end
local bw, bh= 200, 200
local menuItems = {"Play", "Mods", "Skins", "Options", "Credits", "Quit"}
local selectedIndex, menuX, menuSpacing = 1, 50, base_height / 8
local menuCamX, menuCamZ, menuTargetCamX, menuTargetCamZ = 50, 50, 50, 50
local bgSmooth = 0.02

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

local materials = loadMaterials({
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
})

local Blocks = require(proj.."blocks")
Blocks.load(materials)

local tileGrid, baseplateTiles, heights = {}, {}, {}
local mapSeed = os.time()

local function setSeed(seed)
    mapSeed = seed
    m.randomseed(mapSeed)
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

function createBaseplate(width, depth, seed, formatType)
    formatType = formatType or "debug"

    setSeed(seed or os.time())
    local nx, nz = width + 1, depth + 1
    local totalPoints = nx * nz
    local heights_buf = ffi.new("double[?]", totalPoints)

    local function h_index(x, z) return x * nz + z end
    local function set_h(x, z, v) heights_buf[h_index(x, z)] = v end
    local function get_h(x, z) return heights_buf[h_index(x, z)] end

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

    if formatType == "flat" then
        for z = 0, depth do for x = 0, width do set_h(x, z, 2) end end
    elseif formatType == "debug" then
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
            local z_scaled = z * C_SCALE
            local z_volcano = z * C_VOLCANO_H_NOISE
            local z_mask = z * C_CAVE_MASK_NOISE
            local z_river = z * C_RIVER_FACTOR
            local cos_z_river = cos(z_river)
            local C_HEIGHT_MULT = 6
            for x = 0, width do
                local base = getFractalNoise(x, z, 4, 0.4, C_SCALE) * 10
                --[[if base < 5 then
                    base = base * 0.7
                end]]

                local dx = (x / width) - 0.5
                local dz = (z / depth) - 0.5
                local dist = math.sqrt(dx*dx + dz*dz) * 2
                local mask = math.max(0, 1.2 - dist^1.5)

                local h = (base - 2) * mask

                for i = 1, #islands do
                    local isl = islands[i]
                    local idx, idz = x - isl.cx, z - isl.cz
                    local distSq = idx * idx + idz * idz
                    local rad = isl.radius
                    if distSq < rad * rad then
                        h = h + isl.height * (1 - sqrt(distSq) / rad)^1.2
                    end
                end
                
                local volcanoNoise = perlin(x * C_VOLCANO_H_NOISE, z_volcano)
                if volcanoNoise > 0.95 then h = h + 6 + (volcanoNoise - 0.95) * 10 end
                
                local caveMask = perlin(x * C_CAVE_MASK_NOISE, z_mask, 0)
                if caveMask > 0.7 and h > 3 then h = h - caveMask * 2.5 end

                local noiseDetail = perlin(x * 0.5, z * 0.5) * 0.5
                h = h + noiseDetail

                local riverNoise = perlin(x * 0.02, z * 0.02)
                local riverPath = math.abs(riverNoise)
                local humidNoise = perlin(x * C_BIOME_SCALE * 1.2 + 400, z * C_BIOME_SCALE * 1.2 + 400)
                if riverPath < 0.04 then
                    local depthMult = (1 - (riverPath / 0.04))
                    h = h - (4.0 * depthMult) 
                    humidNoise = math.min(1, humidNoise + depthMult)
                end

                local ctx = {x = x,z = z,height = h}

                for _, layer in ipairs(ModAPI.terrainLayers) do
                    layer(ctx)
                end

                h = ctx.height
                set_h(x, z, h)
            end
        end
    end

    baseplateTiles = {}
    tileGrid = {}
    local idx = 1
    local tileChunks = {}
    local function chunkKey(cx, cz) return cx..":"..cz end
    local materialNames = {}
    if formatType == "debug" then
        for name, _ in pairs(materials) do
            table.insert(materialNames, name)
        end
        table.sort(materialNames)
    end

    local function getBiomeNoise(x, z)
        return
            perlin(x * C_BIOME_SCALE, z * C_BIOME_SCALE),
            perlin(x * C_BIOME_SCALE * 0.6, z * C_BIOME_SCALE * 0.6 + 200),
            perlin(x * C_BIOME_SCALE * 1.2 + 400, z * C_BIOME_SCALE * 1.2 + 400),
            perlin(x * C_VOLCANO_NOISE_SCALE + 1000, z * C_VOLCANO_NOISE_SCALE + 1000)
    end


    for z = 0, depth - 1 do
        for x = 0, width - 1 do
            tileGrid[x] = tileGrid[x] or {}

            local h1 = get_h(x, z)
            local h2 = get_h(x + 1, z)
            local h3 = get_h(x + 1, z + 1)
            local h4 = get_h(x, z + 1)
            local avgH = (h1 + h2 + h3 + h4) * 0.25

            local texName = "grassNormal"
            local tileTexture = materials.grassNormal

            local biomeNoise, tempNoise, humidNoise, volcanicInfluence =
                getBiomeNoise(x, z)

            local biomeID = determineBiome(
                avgH, tempNoise, humidNoise, volcanicInfluence, x, z
            )

            texName = biomeToTexture[biomeID] or "grassNormal"

            local detailNoise = perlin(x * 0.4, z * 0.4)
            if biomeID == "Beach" and detailNoise > 0.4 then
                texName = "gravel"
            elseif biomeID == "Highlands" then
                local rockSel = perlin(x * 0.2, z * 0.2)
                if rockSel < -0.25 then texName = "stone_dark"
                elseif rockSel > 0.45 then texName = "rhyolite" end
            elseif biomeID == "Volcanic" and avgH > 10 and detailNoise > 0.5 then
                texName = "lava"
            end

            tileTexture = materials[texName] or materials.grassNormal

            -- Subsurface layers
            local subsurface
            local clayChance = perlin(x * 0.1, z * 0.1)

            if avgH < 2.5 then
                subsurface = {texName, "sandWet", "shale"}
            elseif avgH < 6 then
                subsurface = {
                    (clayChance > 0.7 and humidNoise > 0.2) and "dirt_clay" or "dirt",
                    "limestone",
                    "shale"
                }
            elseif avgH < 9 then
                subsurface = {"stone", "limestone", "gabbro"}
            else
                subsurface = {"granite", "basalt", "porphyry"}
            end

            if volcanicInfluence > 0.90 then
                subsurface = {"pumice", "basalt", "lava"}
            end

            local chunkX = getChunkCoord(x)
            local chunkZ = getChunkCoord(z)

            local tile = {
                {x, h1, z},
                {x + 1, h2, z},
                {x + 1, h3, z + 1},
                {x, h4, z + 1},

                x = x, z = z,
                y = avgH,
                height = avgH,
                curHeight = avgH,

                biome = biomeID,
                texture = tileTexture,
                textureName = texName,
                subsurface = subsurface,
                wallTex = tileTexture,

                isVolcano = (volcanicInfluence > 0.92 and avgH > 6),
                heights = {h1, h2, h3, h4},

                chunkX = chunkX,
                chunkZ = chunkZ,

                mesh = nil,
                floorY = 0,
                needsMesh = true
            }

            ModAPI.runHooks("onTileGenerate", tile)

            baseplateTiles[idx] = tile
            tileGrid[x][z] = tile

            local ck = chunkX .. ":" .. chunkZ
            tileChunks[ck] = tileChunks[ck] or {}
            table.insert(tileChunks[ck], idx)

            idx = idx + 1
        end
    end

    baseplateTiles._tileChunks = tileChunks
    heights = {}
    for x = 0, width do
        local col = {}
        for z = 0, depth do col[z] = get_h(x, z) end
        heights[x] = col
    end
end

local function getTileAt(x, z)
    x, z = floor(x), floor(z)
    if x < 0 or z < 0 then return nil end
    local col = tileGrid[x]
    return col and col[z]
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
    m.randomseed(seed or os.time())
    createBaseplate(w, d)
end

local function resetWorldFromMods()
    regenerateMap(bh, bw, os.time())
    updateTileMeshes(true)
end

local function createNewWorld(name)
    local nm = name or ("World_" .. tostring(os.time()))
    regenerateMap(bh, bw, os.time())
    Mapsave.save(baseplateTiles, materials, nm)
    currentWorldName = nm
    Blocks.baseTiles = baseplateTiles
    
    countryball.x, countryball.y, countryball.z = bh /2, 10, bh /2
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
        Blocks.baseTiles = baseplateTiles
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
        
        local blocksData = Mapsave.loadBlocks(name)
        if blocksData then
            Blocks.placed = {}
            for i = 1, #blocksData do
                local blockData = blocksData[i]
                if blockData then
                    table.insert(Blocks.placed, {
                        x = blockData.x,
                        y = blockData.y,
                        z = blockData.z,
                        type = blockData.type
                    })
                end
            end
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

Blocks.baseTiles = baseplateTiles
local preloadedTiles = {}
local lastCamChunkX, lastCamChunkZ = -999, -999
local visibleTileSet = {}
function updateTileMeshes(force)
    local camChunkX, camChunkZ = getChunkCoord(camera.x), getChunkCoord(camera.z)
    if not force and camChunkX == lastCamChunkX and camChunkZ == lastCamChunkZ then
        return
    end
    lastCamChunkX, lastCamChunkZ = camChunkX, camChunkZ

    local r = chunkCfg.radius
    local newVisibleSet = {}
    local tilesToRender = {}
    for cz = camChunkZ - r, camChunkZ + r do
        for cx = camChunkX - r, camChunkX + r do
            local key = cx .. ":" .. cz
            local tileIndices = baseplateTiles._tileChunks[key]
            
            if tileIndices then
                for i = 1, #tileIndices do
                    local tile = baseplateTiles[tileIndices[i]]
                    table.insert(tilesToRender, tile)
                    newVisibleSet[tile] = true
                end
            end
        end
    end
    for tile, _ in pairs(visibleTileSet) do
        if not newVisibleSet[tile] then
            if tile.mesh then
                tile.mesh:release()
                tile.mesh = nil
            end
            tile.needsMesh = true
        end
    end

    visibleTileSet = newVisibleSet
    preloadedTiles = verts.generate(tilesToRender, camera, renderDistanceSq, tileGrid, materials)
    verts.ensureAllMeshes(preloadedTiles, materials)
end

local baseScale = 3.0
local function drawWithStencil(objX, objY, objZ, img, flip, rotation, alpha, yOffset)
    if not img then return end
    local objChunkX, objChunkZ = getChunkCoord(objX), getChunkCoord(objZ)
    local camChunkX, camChunkZ = getChunkCoord(camera.x), getChunkCoord(camera.z)
    if (objChunkX - camChunkX)^2 + (objChunkZ - camChunkZ)^2 > chunkCfg.radius^2 then
        return
    end
    yOffset = yOffset or -0.04
    
    local sx, sy, z = camera:project3D(objX, objY + yOffset, objZ)
    if not sx or z <= 0 then return end

    local scale = (camera.hw / z) * (camera.zoom * 0.0025) * baseScale
    local w, h = img:getWidth(), img:getHeight()
    local textureMul = nightCycle.getTextureMultiplier() or {1,1,1}
    
    local halfW = (w * scale) * 0.5
    local halfH = h * scale
    local left = sx - halfW
    local top = sy - halfH
    local right = sx + halfW
    local bottom = sy + halfH

    lg.push("all")
    lg.setDepthMode("always", false)
    local clipLeft = max(0, left)
    local clipTop = max(0, top)
    local clipRight = min(base_width, right)
    local clipBottom = min(base_height, bottom)
    
    if clipLeft < clipRight and clipTop < clipBottom then
        lg.setScissor(clipLeft, clipTop, clipRight - clipLeft, clipBottom - clipTop)
    else
        lg.pop()
        return
    end
    
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
        return
    end
    local nextMatName = table.remove(tile.subsurface, 1)
    
    if nextMatName and materials[nextMatName] then
        tile.texture = materials[nextMatName]
        tile.textureName = nextMatName
    end
end

function breakTileAt(tileX, tileZ)
    local col = tileGrid[tileX]
    if not col then return end
    local tile = col[tileZ]
    if not tile then return end
    tile.height = tile.height - 1
    for i=1,4 do
        tile[i][2] = tile[i][2] - 1
    end
    if tile.height <= 0 then
        tile.isAir = true
        tile.texture = nil
        for i=1,4 do tile[i][2] = 0 end
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

function love.mousepressed(mx, my, button)
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
            if selected then
                local itemDef = itemTypes[selected.type]
                if itemDef and itemDef.eatable then
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
            local selected = Inventory:getSelected()
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
            if tile then
                local selected = Inventory:getSelected()
                local multiplier = selected and ItemsModule.getToolMultiplier(selected.type) or 0.5

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
                            ItemsModule.dropItem(block.x, block.y + 1, block.z, matName, 1, nil, 0)
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
                            ItemsModule.dropItem(cx, cy+1, cz, matName, 1, nil, 0)
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
            if selected and blockPlacables[selected.type] then
                local tile, cx, cy, cz = getTileUnderCursor(mx, my, 20)
                if tile then
                    local newX, newY, newZ = floor(cx), floor(cy)+1, floor(cz)
                    local occupied = false
                    for _, b in ipairs(Blocks.placed) do
                        if b.x==newX and b.y==newY and b.z==newZ then
                            occupied = true
                            break
                        end
                    end
                    if not occupied then
                        Blocks.place(newX,newY,newZ,selected.type)
                        selected.count = selected.count - 1
                        if selected.count <= 0 then
                            Inventory.items[Inventory.selectedSlot] = nil
                        end
                    end
                end
            end
        end
    end
end

function love.mousereleased(mx, my, button)
    if not Crafting.open then
        Inventory:mousereleased(mx, my, button, ItemsModule, countryball)
    end
end

local titleX = 2000
local titleTargetX = base_width - titleImage:getWidth() - 30
local titleSlideSpeed = 8

local function expEase(current, target, speed, dt)
    return current + (target - current) * (1 - math.exp(-speed * dt))
end

local function lerp(a, b, t)
    return a + (b - a) * t
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
    love.timer.sleep(0.001)
    Cursor.update(dt)
    updateTileMeshes(true)

    if ModAPI.applyChanges() then
        resetWorldFromMods()
    end
    ModAPI.runHooks("update", dt, baseplateTiles, tileGrid)
    if visible_idk.cursor then love.mouse.setVisible(false) else love.mouse.setVisible(true) end
    if gamestate == "menu" or gamestate == "options" or gamestate == "skins" or gamestate == "mods" then
        local mx, my = love.mouse.getPosition()
        local dx = (mx / base_width - 0.5) * 6
        local dz = (my / base_height - 0.5) * 6
        menuTargetCamX = 11 + dx + math.sin(love.timer.getTime() * 0.4) * 0.2
        menuTargetCamZ = -0.1 + dz + math.cos(love.timer.getTime() * 0.4) * 0.2
        menuCamX = expEase(menuCamX, menuTargetCamX, 4, dt)
        menuCamZ = expEase(menuCamZ, menuTargetCamZ, 4, dt)

        camera.x, camera.z = menuCamX, menuCamZ
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
        updateDirtToGrass(dt)
        local target = pauseOpen and 1 or 0
        pauseProgress = pauseProgress + (target - pauseProgress) * (1 - math.exp(-pauseSmooth * dt))
        if pauseProgress < 1e-4 then pauseProgress = 0 end
        if 1 - pauseProgress < 1e-4 then pauseProgress = 1 end
        if not pauseOpen then
            local sy, sp = 1.5 * dt, 1.2 * dt
            if love.keyboard.isDown("a") then camera.yaw = camera.yaw + sy end
            if love.keyboard.isDown("d") then camera.yaw = camera.yaw - sy end
            if love.keyboard.isDown("w") then camera.pitch = camera.pitch - sp end
            if love.keyboard.isDown("s") then camera.pitch = camera.pitch + sp end
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
            if countryball.y <= -10 then healthBar:setHealth(0) end
            audioSources.main:play()
            healthBar:update(dt)
            hungerBar:update(dt)
            Knapping:update(dt)
            mobs.update(dt, getTileAt)
            local cue = Collision.updateEntity
            cue(countryball, dt, tileGrid, Blocks.placed)
            for _, t in ipairs(itemsOnGround) do
                cue(t, dt, tileGrid, Blocks.placed)
            end
            for _, p in ipairs(Props.props) do
                cue(p, dt, tileGrid, Blocks.placed)
            end
            for _, e in ipairs(mobs.entities) do
                cue(e, dt, tileGrid, Blocks.placed)
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
    local nx = (mx / base_width - 0.5) * 2
    local ny = (my / base_height - 0.5) * -2
    
    local aspect = base_width / base_height
    local tanFOV = math.tan(math.rad(camera.fov / 2))
    local sx = nx * aspect * tanFOV
    local sy_scalar = ny * tanFOV

    local yaw, pitch = camera.yaw, camera.pitch
    local cy, sy = math.cos(yaw), math.sin(yaw)
    local cp, sp = math.cos(pitch), math.sin(pitch)
    local rdx = (sy * cp) + (cy * sx) + (-sy * sp * sy_scalar)
    local rdy = sp + (cp * sy_scalar)
    local rdz = (cy * cp) + (-sy * sx) + (-cy * sp * sy_scalar)

    local len = math.sqrt(rdx*rdx + rdy*rdy + rdz*rdz)
    local rdx, rdy, rdz = rdx/len, rdy/len, rdz/len
    
    local px, py, pz = camera.x, camera.y, camera.z
    local blocks = Blocks.placed

    for t = 0, maxDistance, 0.1 do
        local wx, wy, wz = px + rdx*t, py + rdy*t, pz + rdz*t
        for i = 1, #blocks do
            local block = blocks[i]
            if math.abs(wx - block.x) <= 0.5 and math.abs(wy - block.y) <= 0.5 and math.abs(wz - block.z) <= 0.5 then
                return block, block.x, block.y, block.z, "block"
            end
        end

        local tile = getTileAt(wx, wz)
        if tile and not tile.isAir then
            local t1, t2, t3, t4 = tile[1], tile[2], tile[3], tile[4]
            local avgY = (t1[2] + t2[2] + t3[2] + t4[2]) * 0.25
            
            if wy <= avgY + 0.2 and wy >= avgY - 1.0 then
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
    if visible_idk.skyBox then
        local lightFactor = (nightCycle.getLight and nightCycle.getLight() or 1.0)
        lg.setColor(lightFactor, lightFactor, lightFactor, 1)
        skyBox.draw()
        lg.setColor(1, 1, 1, 1)
    end
    local blockEntries = Blocks.generate(camera, renderDistanceSq)
    Blocks.ensureAllMeshes(blockEntries)
    local renderQueue = {}
    for i=1, #preloadedTiles do
        local tile = preloadedTiles[i]
        table.insert(renderQueue, {
            dist = tile.dist,
            type = "terrain",
            obj = tile
        })
    end
    for i=1, #blockEntries do
        local block = blockEntries[i]
        table.insert(renderQueue, {
            dist = block.dist,
            type = "block",
            obj = block
        })
    end
    
    for _, p in ipairs(Props.props) do
        table.insert(renderQueue, {
            dist = (p.x - camera.x)^2 + (p.z - camera.z)^2,
            type = "prop",
            obj = p
        })
    end
    for _, mob in ipairs(mobs.entities) do
        table.insert(renderQueue, {
            dist = (mob.x - camera.x)^2 + (mob.z - camera.z)^2,
            type = "mob",
            obj = mob
        })
    end
    for _, item in ipairs(itemsOnGround) do
        table.insert(renderQueue, {
            dist = (item.x - camera.x)^2 + (item.z - camera.z)^2,
            type = "item",
            obj = item
        })
    end
    table.insert(renderQueue, {
        dist = (countryball.x - camera.x)^2 + (countryball.z - camera.z)^2,
        type = "player",
        obj = countryball
    })
    
    table.sort(renderQueue, function(a, b) return a.dist > b.dist end)
    
    for _, entry in ipairs(renderQueue) do
        if entry.type == "terrain" then
            local e = entry.obj
            lg.setColor(1, 1, 1, 1)
            lg.draw(e.mesh or e.verts)
        elseif entry.type == "block" then
            local e = entry.obj
            lg.setColor(e.color or {1, 1, 1})
            lg.draw(e.mesh or e.verts)
        elseif entry.type == "prop" then
            local singlePropTable = { entry.obj } 
            Props.drawProps(singlePropTable, drawWithStencil)
        elseif entry.type == "item" then
            local img = ItemsModule.getItemImage(entry.obj.type)
            drawWithStencil(entry.obj.x, entry.obj.y, entry.obj.z, img, false)
        elseif entry.type == "player" then
            countryball.draw(drawWithStencil, Inventory, ItemsModule)
        elseif entry.type == "mob" then
            mobs.draw(drawWithStencil)
        end
    end
    ModAPI.runHooks("draw")
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

function menuScreen()
    lg.setDepthMode("lequal", true)
    drawTiles()
    lg.setDepthMode()

    for i, text in ipairs(menuItems) do
        local anim = menuAnim[i]
        local y = 131.5 + (i-1) * menuSpacing

        local x = menuX + anim.offset
        local scale = (i == selectedIndex) and (1) or 1

        local borderColor = {0, 0, 0}
        local textColor = (i == selectedIndex)and {1, 1, 0}or {1, 1, 1}

        lg.push()
        lg.translate(x, y)
        lg.scale(scale, scale)
        utils.drawTextWithBorder(text, 0, 0, base_width, "left", borderColor, textColor)
        lg.pop()
    end

    local text = "2025 REVIVAL"
    utils.drawTextWithBorder(text, base_width - font:getWidth(text) - 10, base_height - 30, base_width)
    lg.push()
    lg.translate(title.x + titleImage:getWidth()/2,title.y + title.float + titleImage:getHeight()/2)
    lg.rotate(title.rot)
    lg.scale(title.scale, title.scale)
    lg.draw(titleImage, -titleImage:getWidth()/2, -titleImage:getHeight()/2)
    lg.pop()
end

local function worldSelectScreen()
    drawTiles()
    lg.setDepthMode()

    local title = "Select World"
    utils.drawTextWithBorder(title, 50, 30)

    local y = 80
    if #worldList == 0 then
        utils.drawTextWithBorder("No worlds found. Press C to create.", 50, y)
    else
        for i, name in ipairs(worldList) do
            local isSelected = i == selectedWorldIndex
            local borderColor = {0,0,0}
            local textColor = isSelected and {1,1,0} or {1,1,1}
            utils.drawTextWithBorder(name, 60, y, base_width, "left", borderColor, textColor)
            y = y + 30
        end
    end
    lg.setColor(1,1,1)
    utils.drawTextWithBorder("Enter: Play | C: Create World | D: Delete World | Esc: Back", 20, base_height - 40)
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
    end
    utils.drawTextWithBorder("FPS: "..love.timer.getFPS(), 10, 5)
    if visible_idk.cursor then
        Cursor.draw()
    end
end
function love.load()
    love.window.setMode(base_width, base_height, {resizable=false, vsync=true, depth = 24, stencil = 8, msaa = 0, highdpi = false})
    love.window.setTitle("A Random Countryball Game")
    love.window.setIcon(love.image.newImageData("icon/icon.png"))
    local loaded, loadedTileGrid = Mapsave.load(materials)
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

    for name, path in pairs(songs) do
        audioSources[name] = love.audio.newSource(path, "stream")
        audioSources[name]:setLooping(true)
    end

    gl.glEnable(GL.DEPTH_TEST)
    gl.glEnable(GL.CULL_FACE)
    gl.glCullFace(GL.BACK)
    gl.glFrontFace(GL.CCW)

    updateTileMeshes(true)
    lg.setDepthMode("lequal", true)
end

function switchSong(name)
    for _, source in pairs(audioSources) do
        source:stop()
    end
    if audioSources[name] then
        audioSources[name]:setLooping(true)
        audioSources[name]:play()
    end
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
        if key == "up" then
            selectedIndex = selectedIndex - 1
            if selectedIndex < 1 then selectedIndex = #menuItems end
        elseif key == "down" then
            selectedIndex = selectedIndex + 1
            if selectedIndex > #menuItems then selectedIndex = 1 end
        elseif key == "return" then
            if menuItems[selectedIndex] == "Play" then
                refreshWorldList()
                gamestate = "worldselect"
            elseif menuItems[selectedIndex] == "Mods" then
                gamestate = "mods"
            elseif menuItems[selectedIndex] == "Skins" then
                gamestate = "skins"
            elseif menuItems[selectedIndex] == "Options" then
                gamestate = "options"
            elseif menuItems[selectedIndex] == "Quit" then
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
            gamestate = "menu"
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
                    gamestate = "menu"
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
        Inventory:keypressed(key)

        if key == "q" then healthBar:damageHealth(1) end

        if key == "f5" then
            Mapsave.save(baseplateTiles, materials, currentWorldName)
        end

        if key == "escape" then
            pauseOpen = not pauseOpen
            if pauseOpen then
                pauseSelected = 1
            end
        end
    elseif gamestate == "options" then
        OptMenu:keypressed(key, camera, chunkCfg, visible_idk)
        if key == "escape" then
            gamestate = prevGamestate or "menu"
            prevGamestate = nil
        end
    elseif gamestate == "skins" then
        SkinsMenu:keypressed(key)
        if key == "escape" then gamestate = "menu" end
    elseif gamestate == "mods" then
        ModsMenu:keypressed(key)
        ModAPI.reset()
        if key == "escape" then gamestate = "menu" end
    end
end

function love.quit()
end