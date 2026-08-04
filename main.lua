local love, lg = require("love"), love.graphics
local ffi = require("ffi")

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
local lib3d = require(proj.."lib3d")
local countryball = require(src.."countryball")
local mobs = require(src.."mobs")
local ItemsModule = require(src.."items")
local Inventory = require(hud.."inv")
local Crafting = require(hud.."craft")
local Knapping = require(hud.."knap")
local Pottery = require(hud.."pottery")
local Achievement = require(hud.."achievement")
local Progression = require(src.."progression")
local verts = require(proj.."verts")
local Props = require(src.."props")
local utils = require(src.."utils")
local Collision = require(src.."collision")
local OptMenu = require(menu.."options")
local SkinsMenu = require(menu.."skins")
local ModsMenu = require(menu.."mods")
local CreditsMenu = require(menu.."credits")
MultiplayerMenu = require(menu.."multiplayer")
local ModAPI = require(src.."apis.mod_api")
local Cursor = require(hud.."cursor")
local healthBar = require(hud.."health_bar")
local hungerBar = require(hud.."hunger_bar")
Mapsave = require(proj.."mapsave")
local Particles = require(proj.."particles")
local skyBox = require(proj.."skybox")
local nightCycle = require(proj.."night_cycle")
local Audio = require(src.."audio")
local Console = require(src.."console")
local Transition = require("source.transition")
local Map = require(proj.."map")
local MultiplayerAPI = require(src.."apis.multiplayer_api")
local Placements = require(proj.."placements")

local visible_idk = {cursor = true, skyBox = false}
local clamp = utils.clamp

local particlesImgs = {
    smoke = lg.newImage(imgF.."smoke.png"),
    fire = lg.newImage(imgF.."placeholder.png"),
}
local breakHitParticleOpts = {
    radius = 0.05,
    speedMin = 0.8,
    speedMax = 1.5,
    upwardBias = 0.15,
    lifetimeMin = 0.20,
    lifetimeMax = 0.45,
    scaleMin = 0.08,
    scaleMax = 0.16,
    alpha = 1
}

local breakParticleOpts = {
    radius = 0.08,
    speedMin = 1.8,
    speedMax = 3.4,
    upwardBias = 0.35,
    lifetimeMin = 0.40,
    lifetimeMax = 0.90,
    scaleMin = 0.12,
    scaleMax = 0.28,
    alpha = 1
}

local itemsOnGround, itemTypes, items = ItemsModule.itemsOnGround, ItemsModule.itemTypes, ItemsModule.items

local chunkCfg = Map.chunkCfg
local base_width, base_height = camera.hw * 2, camera.hh * 2
local renderDistance = chunkCfg.size * chunkCfg.radius
local renderDistanceSq = renderDistance * renderDistance

local bw, bh= 195, 195
local menuItems = {"Play", "Multiplayer", "Mods", "Skins", "Options", "Credits", "Quit"}
local selectedIndex, menuX, menuSpacing = 1, 20, base_height / 8
local menuCamX, menuCamZ, menuTargetCamX, menuTargetCamZ = 50, 50, 50, 50

local pauseOpen, pauseProgress = false, 0
worldList = {}
local selectedWorldIndex = 1
local currentWorldName = nil

local pauseItems, pauseSelected = {"Resume", "Options", "Leave"}, 1
local pauseSmooth = 10
local prevGamestate = nil

local autosaveInterval, autosaveTimer = 30, 0

local titleImage = lg.newImage(imgF.."menu/main/title.png")
local pauseImage = lg.newImage(imgF.."menu/pause/pause.png")

materials = {}

function initializeMaterials()
    local baseMaterials = {
        grassNormal = imgF.."grass_type/normal.png",
        grassHot = imgF.."grass_type/hot.png",
        grassCold= imgF.."grass_type/cold.png",
        grassRainforest= imgF.."grass_type/rainforest.png",
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

local getTileAt = Map.getTileAt
local getChunkCoord = Map.getChunkCoord
local getSafeSpawnY = Map.getSafeSpawnY
local biomeToTexture = Map.biomeToTexture
local function regenerateMap(w, d, seed)
    Map.regenerateMap(w, d, seed, materials, Placements)
end

function refreshWorldList()
    worldList = {}
    local items = love.filesystem.getDirectoryItems(Mapsave.saveFolder)
    for _, name in ipairs(items) do
        local info = love.filesystem.getInfo(Mapsave.saveFolder .. "/" .. name .. "/mapsave.json")
        if info then table.insert(worldList, name) end
    end
    if #worldList == 0 then selectedWorldIndex = 0 else selectedWorldIndex = 1 end
end

local function resetWorldFromMods()
    regenerateMap(bh, bw, Map.mapSeed)
    updateTileMeshes(true)
end

function createNewWorld(name)
    local nm = name or ("World_" .. tostring(os.time()))
    regenerateMap(bh, bw, Map.mapSeed)
    Mapsave.save(Map.baseplateTiles, materials, nm)
    currentWorldName = nm
    --Placements.baseTiles = baseplateTiles
    
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
    
    Placements.placed = {}
    Props.clearProps()
    Props.spawnProps(550, bw, bh, getTileAt)
    Mapsave.savePlacements(Placements.placed, nm)
    Mapsave.saveProps(Props.props, nm)
    
    updateTileMeshes(true)
    gamestate = "game"
end
function loadWorld(name)
    if not name then return end
    local loaded, loadedTileGrid = Mapsave.load(materials, nil, name)
    if loaded then
        Map.baseplateTiles = loaded
        Map.tileGrid = loadedTileGrid
        if not Map.baseplateTiles._tileChunks then
            local tileChunks = {}
            local chunkSize = chunkCfg.size or 4
            for i, tile in ipairs(Map.baseplateTiles) do
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
            Map.baseplateTiles._tileChunks = tileChunks
        end
        --Placements.baseTiles = baseplateTiles
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

        local savedPlacements = Mapsave.loadPlacements(name)
        Placements.placed = savedPlacements or {}
        for _, b in ipairs(Placements.placed) do
            b.texture = materials[b.type] or materials.stone
        end

        local savedProps = Mapsave.loadProps(name)
        if savedProps then
            Props.loadSavedProps(savedProps)
        else
            Props.clearProps()
            Props.spawnProps(550, bw, bh, getTileAt)
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

--Placements.baseTiles = baseplateTiles
local preloadedTiles = {}
local preloadedTileCount = 0
local preloadedTerrainBatches = {}
local preloadedTerrainBatchCount = 0
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
            local tileIndices = Map.baseplateTiles._tileChunks[key]
            
            if tileIndices then
                for i = 1, #tileIndices do
                    local tile = Map.baseplateTiles[tileIndices[i]]
                    table.insert(tilesToRender, tile)
                end
            end
        end
    end
    local quads = verts.generate(tilesToRender, camera, renderDistanceSq, Map.tileGrid, materials)
    preloadedTiles, preloadedTileCount, preloadedTerrainBatches, preloadedTerrainBatchCount =
        verts.buildBatches(quads, materials.grass or materials.waterSmall)
end

local baseScale = 3
local function drawWithStencil(objX, objY, objZ, img, flip, scaleX, scaleY, rotation, alpha, yOffset)
    if not img then return end

    local objChunkX, objChunkZ = getChunkCoord(objX), getChunkCoord(objZ)
    local camChunkX, camChunkZ = getChunkCoord(camera.x), getChunkCoord(camera.z)
    if (objChunkX - camChunkX)^2 + (objChunkZ - camChunkZ)^2 > chunkCfg.radius^2 then
        return
    end

    local sx, sy, z = camera:project3D(objX, objY + (yOffset or -0.04), objZ)
    if not sx or z <= 0 then return end
    local base = (camera._f / z) * (baseScale / 1.25)
    local targetScaleX = base * (scaleX or 1)
    local targetScaleY = base * (scaleY or 1)
    local w, h = img:getDimensions()
    
    local pixelWidth  = math.max(1, math.floor(w * targetScaleX + 0.5))
    local pixelHeight = math.max(1, math.floor(h * targetScaleY + 0.5))
    local sxScale = pixelWidth / w
    local syScale = pixelHeight / h

    if flip then
        sxScale = -sxScale
    end

    local textureMul = nightCycle.getTextureMultiplier() or {1,1,1}

    lg.push("all")
    lg.setDepthMode("lequal", false)
    
    lg.setColor(textureMul[1], textureMul[2], textureMul[3], alpha or 1)
    lg.draw(img, math.floor(sx + 0.5), math.floor(sy - 1.5), rotation or 0, sxScale, syScale, w / 2, h)
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
    if tile.textureName and string.find(tile.textureName, "grass") then
        local nextMatName = (math.random() > 0.12) and "dirt" or "dirt_clay"
        tile.texture = materials[nextMatName]
        tile.textureName = nextMatName
        return
    end

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
    local col = Map.tileGrid[tileX]
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
    MultiplayerAPI.sendTileBreak(tileX, tileZ, tile.isAir, tile.textureName, tile.height)
end

local unbreakableMaterials = {
    waterSmall = true,
    waterMedium = true,
    waterDeep = true,
    lava = true,
}

local placementPlacables = {
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
    local matName = tile.textureName
    if not matName then return end

    if matName == "grassNormal" or matName == "grassHot" or matName == "grassCold" or matName == "grassRainforest" or matName == "dirt" then
        tile.texture = materials.farmland
        tile.textureName = "farmland"
        updateTileMeshes(true)
    elseif matName == "grassNormal" then
        tile.texture = materials.dirt
        tile.textureName = "dirt"
        updateTileMeshes(true)
    end
end

local function scheduleDirt(tile)
    if tile and tile.texture == materials.dirt and tile.biome and not dirtTimers[tile] then
        dirtTimers[tile] = random() * DIRT_TO_GRASS_TIME
    end
end

local function updateDirtToGrass(dt)
    for i = 1, #Map.baseplateTiles do
        local tile = Map.baseplateTiles[i]
        if tile.textureName == "dirt" and (tile.height == tile.curHeight or (tile.subsurface and tile.subsurface[1] == "dirt")) then
            scheduleDirt(tile)
        end
    end
    
    for tile, t in pairs(dirtTimers) do
        t = t - dt
        if t <= 0 then
            local newGrass = getGrassForBiome(tile)
            tile.texture = newGrass
            tile.textureName = biomeToTexture[tile.biome] or "grassNormal" 
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

    local required = Placements.bestTools[matName]
    return required and itemDef.toolType == required
end

function love.mousepressed(mx, my, button)
    if ModAPI.runHooks("onMousePressed", mx, my, button) then return end
    if gamestate == "options" then
        OptMenu:mousepressed(mx, my, button, camera, chunkCfg, visible_idk)
    end
    if pauseOpen or gamestate ~= "game" then return end

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

    if Pottery.open then
        Pottery:mousepressed(mx, my, button, Inventory, itemTypes, ItemsModule, countryball)
        return
    end

    local overInteractive = nil

    if button == 1 and slot and slot.count >= 2 and not Crafting.open and not Pottery.open and not Knapping.open then
        if slot.type == "stone" then
            overInteractive = isCursorOverInteractive(mx, my)
            if not overInteractive then
                slot.count = slot.count - 1
                Knapping.open = true
                Knapping:resetGrid()
                Knapping.timer = 0
                if slot.count <= 0 then Inventory.items[Inventory.selectedSlot] = nil end
                return
            end
        elseif slot.type == "clay" then
            if overInteractive == nil then overInteractive = isCursorOverInteractive(mx, my) end
            if not overInteractive then
                slot.count = slot.count - 1
                Pottery.open = true
                Pottery:resetGrid()
                Pottery.timer = 0
                if slot.count <= 0 then Inventory.items[Inventory.selectedSlot] = nil end
                return
            end
        end
    end

    if Props and Props.handleMousePressed and Props.handleMousePressed(mx, my) then
        return
    end

    if button == 2 and slot then
        if slot.type == "stone_hoe" then
            local tile = getTileUnderCursor(mx, my)
            tillTile(tile)
            damageSelectedItem(1)
            return
        elseif slot.type == "firestarter" then
            local tile, cx, cy, cz = getTileUnderCursor(mx, my)
            if tile then
                for i = 1, 10 do
                    Particles.spawnSmoke(particlesImgs.smoke, cx, cy + 0.5, cz)
                end
                damageSelectedItem(1)
            end
            return
        end

        local tile, cx, cy, cz = getTileUnderCursor(mx, my)
        ModAPI.runHooks("onItemUse", slot, tile, cx, cy, cz, button)
        
        local itemDef = itemTypes[slot.type]
        if itemDef and itemDef.eatable then
            ModAPI.runHooks("onEntityEat", countryball, itemDef)
            if countryball.hunger < countryball.maxHunger then
                countryball.hunger = min(countryball.hunger + 1, countryball.maxHunger)
                slot.count = slot.count - 1
                if slot.count <= 0 then Inventory.items[Inventory.selectedSlot] = nil end
            end
            return
        end

        if slot.type == "apple_seed" and tile and Props.plantAppleSeed(tile, cx, cz) then
            MultiplayerAPI.sendPropPlant(cx, cz)
            slot.count = slot.count - 1
            if slot.count <= 0 then Inventory.items[Inventory.selectedSlot] = nil end
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
        if button == 1 then
            local baseMultiplier = selected and ItemsModule.getToolMultiplier(selected.type) or 0.5
            local multiplier = ModAPI.runHooks("onCalculateToolPower", selected, baseMultiplier) or baseMultiplier

            if kind == "block" then
                local matName = tile.type
                if not matName or unbreakableMaterials[matName] then return end

                local br = Placements.currentBreaking
                if br.tile ~= tile then
                    br.tile = tile
                    br.progress = 0
                    br.max = Placements.durabilities[matName] or 3
                else
                    br.progress = br.progress + multiplier
                    Particles.spawnBurst(tile.texture or materials[matName], tile.x, tile.y + 0.5, tile.z, 3, breakHitParticleOpts)
                    if br.progress >= br.max then
                        ModAPI.runHooks("onBlockBreak", tile, matName)
                        if not Placements.requiresTool[matName] or hasCorrectTool(selected, matName) then
                            ItemsModule.dropItem(tile.x, tile.y + 1, tile.z, matName, 1, nil, 0)
                        end

                        Particles.spawnBurst(tile.texture or materials[matName], tile.x, tile.y + 0.5, tile.z, 10, breakParticleOpts)

                        for idx = #Placements.placed, 1, -1 do
                            if Placements.placed[idx] == tile then
                                table.remove(Placements.placed, idx)
                                break
                            end
                        end
                        MultiplayerAPI.sendPlacementBreak(tile.x, tile.y, tile.z)
                        br.tile = nil
                        br.progress = 0
                        damageSelectedItem(1)
                    end
                end
            else
                local matName = tile.textureName
                if not matName or unbreakableMaterials[matName] then return end

                local br = Placements.currentBreaking
                if br.tile ~= tile then
                    br.tile = tile
                    br.progress = 0
                    br.max = Placements.durabilities[matName] or 3
                else
                    br.progress = br.progress + multiplier
                    Particles.spawnBurst(materials[matName], cx, cy + 0.5, cz, 3, breakHitParticleOpts)
                    if br.progress >= br.max then
                        if not Placements.requiresTool[matName] or hasCorrectTool(selected, matName) then
                            if matName == "dirt_clay" then
                                ItemsModule.dropItem(cx + 0.5, cy + 1, cz, "dirt", 1, nil, 0)
                                ItemsModule.dropItem(cx, cy + 1, cz, "clay", 1, nil, 0)
                            else
                                ItemsModule.dropItem(cx, cy + 1, cz, matName, 1, nil, 0)
                            end
                        end
                        ModAPI.runHooks("onTileBreak", tile, matName, cx, cy, cz)

                        Particles.spawnBurst(materials[matName], cx, cy + 0.5, cz, 10, breakParticleOpts)

                        breakTileAt(floor(tile[1][1]), floor(tile[1][3]))
                        br.tile = nil
                        br.progress = 0
                        damageSelectedItem(1)
                    end
                end
            end
        elseif button == 2 and selected then
            if itemTypes[selected.type] and itemTypes[selected.type].toolType == "axe" and kind == "block" and tile.type == "oak" then
                tile.type = "wood_planks"
                tile.texture = materials.wood_planks or materials.stone
                tile.textureName = "wood_planks"
                damageSelectedItem(1)
                return
            end
            
            if placementPlacables[selected.type] then
                local newX, newY, newZ, mode, yaw = Placements.resolvePlacement(cx, cy, cz)

                Placements.place(newX, newY, newZ, selected.type, mode, yaw)
                MultiplayerAPI.sendPlacementPlace(newX, newY, newZ, selected.type)
                slot.count = slot.count - 1
                if slot.count <= 0 then Inventory.items[Inventory.selectedSlot] = nil end
            end
        end
    end
end

function love.mousereleased(mx, my, button)
    if gamestate == "options" then
        OptMenu:mousereleased(mx, my, button)
    end
    if gamestate == "game" then
        if not Crafting.open then
            Inventory:mousereleased(mx, my, button, ItemsModule, countryball)
        else
            --Crafting:mousereleased(mx, my, button, Inventory)
        end
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

local pauseVolume = 0
local fadeSpeed = 2

function love.update(dt)
    local mx, my = love.mouse.getPosition()
    love.timer.sleep(0.001)
    --Audio.update(dt)
    Transition.update(dt)
    Cursor.update(dt)
    if ModAPI.applyChanges() then
        print("Mods changed, regenerating world...")
        initializeMaterials()
        resetWorldFromMods()
    end
    updateTileMeshes(true)
    ModAPI.runHooks("update", dt, Map.baseplateTiles, Map.tileGrid)
    Console:installGlobalHooks()
    if visible_idk.cursor then love.mouse.setVisible(false) else love.mouse.setVisible(true) end
    SkinsMenu:update(dt)
    MultiplayerMenu:update(dt)
    if MultiplayerMenu.shouldStartGame == "host" then
        MultiplayerAPI.startHostGame()
    elseif MultiplayerMenu.shouldStartGame == "client" then
        MultiplayerAPI.startClientGame()
    end
    if gamestate == "credits" then
        CreditsMenu.update(dt)
        Audio.switchSong("credits")
    elseif gamestate == "options" then
        OptMenu:update(dt, camera, chunkCfg, visible_idk)
        Audio.switchSong("menu")
    end
    if gamestate == "menu" or gamestate == "options" or gamestate == "skins" or gamestate == "mods" or gamestate == "multiplayer" then
        Audio.switchSong("menu")
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
    local pauseSource = Audio.getMusic("pause")
    local mainSource = Audio.getMusic("main")
    if pauseSource then
        if pauseOpen then
            if mainSource and mainSource:isPlaying() then
                mainSource:stop()
            end

            if not pauseSource:isPlaying() then
                pauseSource:setVolume(0)
                pauseSource:play()
            end

            pauseVolume = math.min(pauseVolume + fadeSpeed * dt, 1)
            pauseSource:setVolume(pauseVolume)
        else
            pauseVolume = 0

            if pauseSource:isPlaying() then
                pauseSource:stop()
            end
        end
    end
    if gamestate == "game" then
        Audio.switchSong("main")
        local target = pauseOpen and 1 or 0
        pauseProgress = pauseProgress + (target - pauseProgress) * (1 - math.exp(-pauseSmooth * dt))
        if pauseProgress < 1e-4 then pauseProgress = 0 end
        if 1 - pauseProgress < 1e-4 then pauseProgress = 1 end
        if not pauseOpen then
            nightCycle.update(dt)
            verts.setTime(nightCycle.time)
            Particles.updateSmoke(dt)
            Achievement:update(dt)
            updateDirtToGrass(dt)
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
                countryball.update(dt, love.keyboard, Map.heights, materials, getTileAt, Placements, camera, healthBar)
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
            if mainSource and not mainSource:isPlaying() then mainSource:play() end
            healthBar:update(dt)
            hungerBar:update(dt)
            Knapping:update(dt)
            mobs.update(dt, getTileAt)
            local cue = Collision.updateEntity
            cue(countryball, dt, Map.tileGrid)
            for _, t in ipairs(itemsOnGround) do
                cue(t, dt, Map.tileGrid)
            end
            for _, p in ipairs(Props.props) do
                cue(p, dt, Map.tileGrid)
            end
            for _, e in ipairs(mobs.entities) do
                cue(e, dt, Map.tileGrid)
            end
            Inventory:update(dt)
            Crafting:update(dt)
            Pottery:update(dt)
            Props.updateProps(dt)
            Particles.updateSmoke(dt)
            autosaveTimer = autosaveTimer + dt
            if autosaveTimer >= autosaveInterval and currentWorldName then
                Mapsave.saveCountryball(countryball, currentWorldName)
                Mapsave.saveInventory(Inventory, currentWorldName)
                Mapsave.savePlacements(Placements.placed, currentWorldName)
                autosaveTimer = 0
            end
            countryball.networkSync(MultiplayerMenu, dt)
            countryball.updateRemotePlayers(dt)
        end
    else
        if mainSource and mainSource:isPlaying() then mainSource:stop() end
    end
end

function getTileUnderCursor(mx, my, maxDistance)
    maxDistance = maxDistance or 100
    local rdx, rdy, rdz = camera:getRay(mx, my, camera.hw * 2, camera.hh * 2)

    local px, py, pz = camera.x, camera.y, camera.z
    local Placements = Placements.placed

    local step = 0.05
    local prevTile, prevDiff = nil, nil

    local t = 0
    while t <= maxDistance do
        local wx, wy, wz = px + rdx*t, py + rdy*t, pz + rdz*t

        for i = 1, #Placements do
            local block = Placements[i]
            if abs(wx - block.x) <= 0.5 and abs(wy - block.y) <= 0.5 and abs(wz - block.z) <= 0.5 then
                return block, block.x, block.y, block.z, "block"
            end
        end

        local tile = getTileAt(wx, wz)
        if tile and not tile.isAir then
            local t1, t2, t3, t4 = tile[1], tile[2], tile[3], tile[4]
            local gridX, gridZ = floor(t1[1]), floor(t1[3])
            local fx, fz = wx - gridX, wz - gridZ
            local surfY = lib3d.bilinearInterpolate(t1[2], t2[2], t4[2], t3[2], fx, fz)
            local diff = wy - surfY

            if tile == prevTile and prevDiff and ((prevDiff >= 0 and diff <= 0) or (prevDiff <= 0 and diff >= 0)) then
                local denom = prevDiff - diff
                local frac = (denom ~= 0) and (prevDiff / denom) or 0
                local hitT = t - step + step * frac
                local hx, hy, hz = px + rdx*hitT, py + rdy*hitT, pz + rdz*hitT
                return tile, hx, hy, hz, "terrain"
            end

            prevTile, prevDiff = tile, diff
        else
            prevTile, prevDiff = nil, nil
        end

        t = t + step
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
    local renderQueue = {}
    local placementEntries = Placements.generate(camera, renderDistanceSq)
    for i = 1, preloadedTileCount do
        local t = preloadedTiles[i]
        if t.mesh then
            renderQueue[#renderQueue + 1] = { dist = t.dist, kind = "tile", obj = t }
        end
    end
    for i = 1, preloadedTerrainBatchCount do
        local b = preloadedTerrainBatches[i]
        renderQueue[#renderQueue + 1] = { dist = b.dist, kind = "terrainBatch", obj = b }
    end
    local function getObjDepth(obj)
        if not obj then return nil end
        local ox, oy, oz = obj.x or 0, obj.y or 0, obj.z or 0
        local sx, sy, sz = camera:project3D(ox, oy, oz)
        if not sx or not sz or sz <= 0 then return nil end
        return sz
    end

    local function addToQueue(obj, kind)
        local d = getObjDepth(obj)
        if d then
            renderQueue[#renderQueue + 1] = { dist = d, kind = kind, obj = obj }
        end
    end
    for _, p in ipairs(Props.props) do addToQueue(p, "prop") end
    for _, mob in ipairs(mobs.entities) do addToQueue(mob, "mob") end
    for _, item in ipairs(itemsOnGround) do addToQueue(item, "item") end
    addToQueue(countryball, "player")
    for _, rp in pairs(countryball.remotePlayers) do addToQueue(rp, "remotePlayer") end
    for i = 1, #placementEntries do addToQueue(placementEntries[i], "placement") end

    table.sort(renderQueue, function(a, b)
        return a.dist > b.dist
    end)

    for _, entry in ipairs(renderQueue) do
        local e = entry.obj
        if entry.kind == "tile" then
            lg.setColor(1, 1, 1, 1)
            lg.draw(e.mesh)
        elseif entry.kind == "terrainBatch" then
            verts.drawTerrainMesh(e.mesh)
        elseif entry.kind == "placement" then
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
        elseif entry.kind == "remotePlayer" then
            local skinImages = countryball.getSkinImages(e.skin)
            local img = e.currentFrame or (skinImages.idle and skinImages.idle[1])
            if img then drawWithStencil(e.x, e.y, e.z, img, e.flip) end
        elseif entry.kind == "mob" then
            mobs.draw(drawWithStencil, e)
        end
    end

    Particles.drawSmoke(drawWithStencil)

    ModAPI.runHooks("draw")
    lg.setDepthMode("lequal", true)
end

local function drawPlacementGhost(cx, cy, cz)
    if pauseOpen or Crafting.open or Knapping.open or Pottery.open then return end

    local slot = Inventory:getSelected()
    if not slot or not placementPlacables[slot.type] then return end
    if not cx then return end

    local gx, gy, gz, mode, yaw, attached = Placements.resolvePlacement(cx, cy, cz)
    local corners = Placements.getPanelCorners(gx, gy, gz, mode, yaw)

    local pts = {}
    for i = 1, 4 do
        local c = corners[i]
        local sx, sy, sz = camera:project3D(c[1], c[2], c[3])
        if not sx or not sz or sz <= 0 then return end
        pts[#pts + 1] = sx
        pts[#pts + 1] = sy
    end

    if attached then
        lg.setColor(0.3, 1, 0.4, 0.35)
    else
        lg.setColor(1, 1, 1, 0.3)
    end
    lg.polygon("fill", pts)
    lg.setColor(1, 1, 1, 0.8)
    lg.polygon("line", pts)
    lg.setColor(1, 1, 1, 1)
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
        drawPlacementGhost(cx, cy, cz)
    end

    healthBar:draw()
    hungerBar:draw()
    Crafting:draw(Inventory, itemTypes, items)
    Knapping:draw(Inventory, itemTypes)
    Pottery:draw(Inventory, itemTypes)
    if not Knapping.open and not Pottery.open then
        Inventory:draw(itemTypes)
    end
    Achievement:draw()
    if pauseProgress > 0 then
        local alpha = pauseProgress * 0.9
        lg.setColor(0, 0, 0, 0.5 * alpha)
        lg.rectangle("fill", 0, 0, base_width, base_height)
        lg.draw(pauseImage, 675, 215)
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
        CreditsMenu:draw()
    elseif gamestate == "multiplayer" then
        drawTiles()
        MultiplayerMenu:draw()
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
    camera:updateProjectionConstants(love.graphics.getDimensions())
    Console:installGlobalHooks()
    print("i guess bro")
    love.window.setTitle("A Random Countryball Game")
    love.window.setIcon(love.image.newImageData("icon/icon.png"))
    initializeMaterials()
    local loaded, loadedTileGrid, meta = Mapsave.load(materials)
    if loaded then
        Map.baseplateTiles = loaded
        Map.tileGrid = loadedTileGrid
        Map.mapSeed = meta.seed
        currentWorldName = "default"
        if not Map.baseplateTiles._tileChunks then
            local tileChunks = {}
            local chunkSize = chunkCfg.size or 4
            for i, tile in ipairs(Map.baseplateTiles) do
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
            Map.baseplateTiles._tileChunks = tileChunks
        end
        Placements.placed = Mapsave.loadPlacements(currentWorldName) or {}
        for _, b in ipairs(Placements.placed) do
            b.texture = materials[b.type] or materials.stone
        end
        local savedProps = Mapsave.loadProps(currentWorldName)
        if savedProps then
            Props.loadSavedProps(savedProps)
        else
            Props.clearProps()
            Props.spawnProps(550, bw, bh, getTileAt)
        end
    else
        Map.createBaseplate(bw, bh, Map.mapSeed, "normal", materials, Placements)
        Props.clearProps()
        Props.spawnProps(550, bw, bh, getTileAt)
    end
    mobs.spawn("racoon_dog", 14, 14, getTileAt)
    Cursor.load()
    font = lg.newFont("font/font.ttf", 26)
    lg.setFont(font)
    OptMenu:load(camera, chunkCfg, visible_idk)

    SkinsMenu.load()
    SkinsMenu.applySkin("countryball")
    ModsMenu.load()
    MultiplayerMenu.load()
    MultiplayerAPI.init({
        MultiplayerMenu = MultiplayerMenu,
        Map = Map,
        Placements = Placements,
        Props = Props,
        countryball = countryball,
        materials = materials,
        updateTileMeshes = updateTileMeshes,
        refreshWorldList = refreshWorldList,
        loadWorld = loadWorld,
        createNewWorld = createNewWorld,
        getSafeSpawnY = getSafeSpawnY,
        regenerateMap = regenerateMap,
        setGamestate = function(s) gamestate = s end,
        worldList = worldList,
        bw = bw,
        bh = bh,
    })
    Audio.load()

    updateTileMeshes(true)
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
            elseif selected == "Multiplayer" then
                Transition.startFade(0.5, function()
                    gamestate = "multiplayer"
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
        if key == "r" then
            Placements.rotateMode()
        end
        if key == "t" then
            Placements.rotateYaw()
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
        --if key == "p" and not Knapping.open and not Crafting.open then Pottery:toggle() end
        Inventory:keypressed(key, itemTypes)

        if key == "q" then healthBar:damageHealth(1) end

        if key == "f5" then
            Mapsave.save(Map.baseplateTiles, materials, currentWorldName, {seed = Map.mapSeed})
            Mapsave.savePlacements(Placements.placed, currentWorldName)
            Mapsave.saveProps(Props.props, currentWorldName)
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
            CreditsMenu.toggle(false)
            Transition.startFade(0.5, function()
                gamestate = "menu"
            end)
        end
    elseif gamestate == "multiplayer" then
        if key == "escape" and not MultiplayerMenu:handlesEscape() then
            Transition.startFade(0.5, function()
                gamestate = "menu"
            end)
        else
            MultiplayerMenu:keypressed(key)
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

function love.textinput(t)
    if gamestate == "multiplayer" then
        MultiplayerMenu:textinput(t)
    end
end

function love.resize(w, h)
    camera:updateProjectionConstants(w, h)
end

function love.quit()
    MultiplayerMenu:shutdown()
end