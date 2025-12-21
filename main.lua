local love, lg = require("love"), love.graphics
local ffi = require("ffi")
local glmod = require("source.gl.opengl")
local gl, GL = glmod.gl, glmod.GL

lg.setDefaultFilter("nearest", "nearest")
lg.setDepthMode("lequal", true)
lg.setFrontFaceWinding("ccw")

local gamestate = "menu"
local m = math
local sqrt, floor, sin, cos, max, min, random, abs = m.sqrt, m.floor, m.sin, m.cos, m.max, m.min, m.random, m.abs

local src = "source."
local hud = src.."hud."
local proj = src.."projectile."
local menu = src.."menus."

local camera = require(proj.."camera")
local countryball = require(src.."countryball")
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
local Cursor = require(hud.."cursor")
local healthBar = require(hud.."health_bar")
local hungerBar = require(hud.."hunger_bar")
local Mapsave = require(proj.."mapsave")
local Particles = require(proj.."particles")
local skyBox = require(proj.."skybox")
local nightCycle = require(proj.."night_cycle")

local visible_idk = {cursor = true, skyBox = false}
local clamp, perlin, any = utils.clamp, utils.fastPerlin, utils.any

local particlesImgs = {
    smoke = lg.newImage("image/smoke.png")
}

local songs = {
    main = "music/music.mp3"
}
local audioSources = {}

local itemsOnGround = ItemsModule.itemsOnGround
local itemTypes = ItemsModule.itemTypes
local items = ItemsModule.items

local chunkCfg = {size = 4, radius = 4}
local base_width, base_height = 1000, 525
local renderDistance = chunkCfg.size * chunkCfg.radius
local renderDistanceSq = renderDistance * renderDistance

function loadMaterials(tbl)
    local res = {}
    for k, path in pairs(tbl) do
        local info = love.filesystem.getInfo(path)
        if info then res[k] = lg.newImage(path) end
    end
    return res
end

local menuItems = {"Play", "Mods", "Skins", "Options", "Quit"}
local selectedIndex = 1
local menuX = 50
local menuSpacing = 81.25
local menuCamX, menuCamZ = 50, 50
local menuTargetCamX, menuTargetCamZ = 50, 50
local bgSmooth = 0.02

local pauseOpen = false
local pauseProgress = 0
local pauseItems = {"Resume", "Options", "Leave"}
local pauseSelected = 1
local pauseSmooth = 10
local prevGamestate = nil

local titleImage = lg.newImage("image/menu/title.png")

local materials = loadMaterials({
    grassNormal = "image/grass_type/normal.png",
    grassHot = "image/grass_type/hot.png",
    grassCold= "image/grass_type/cold.png",
    sandNormal = "image/sand_type/normal.png",
    sandGarnet= "image/sand_type/garnet.png",
    sandGypsum = "image/sand_type/gypsum.png",
    sandOlivine = "image/sand_type/olivine.png",
    snow = "image/snow.png",
    waterSmall = "image/water_type/type1.png",
    waterMedium = "image/water_type/type2.png",
    waterDeep = "image/water_type/type3.png",
    stone = "image/stone_type/stone.png",
    granite = "image/stone_type/granite.png",
    gabbro = "image/stone_type/gabbro.png",
    porphyry = "image/stone_type/porphyry.png",
    basalt = "image/stone_type/granite.png",
    stone_dark = "image/stone_type/stone_dark.png",
    pumice = "image/stone_type/pumice.png",
    rhyolite = "image/stone_type/rhyolite.png",
    oak = "image/oak.png",
    dirt = "image/dirt.png",
    lava = "image/lava.png",
    dirt_clay = "image/dirt_clay.png",
    farmland = "image/farmland.png",
})

local Blocks = require(proj.."blocks")
Blocks.load(materials)

local tileGrid, baseplateTiles, heights = {}, {}, {}
local mapSeed = os.time()

local function getTileAt(x, z)
    local col = tileGrid[floor(x)]
    return col and col[floor(z)]
end
Props.spawnProps(25, 20, 20, getTileAt)
ItemsModule.dropItem(countryball.x, countryball.x, countryball.x, "stone_pickaxe")

local function setSeed(seed)
    mapSeed = seed
    m.randomseed(mapSeed)
end

local function getChunkCoord(v) return floor(v / chunkCfg.size) end

function determineBiome(h, t, h2, volc)
    if h < 0.6 then return "OceanDeep" end
    if h < 1.8 then return "OceanShallow" end
    if h < 3.6 then return t>0.45 and "HotDesert" or t<-0.2 and "ColdDesert" or "Desert" end
    if volc>0.92 and h>6 then return h>10 and "VolcanicPeak" or "Volcanic" end
    if h<6 then return t<-0.25 and "Tundra" or t>0.4 and "Savanna" or "Grassland" end
    if h<9.5 then return h2<-0.2 and "DryHighlands" or h2>0.4 and "WetHighlands" or "Highlands" end
    return h<11 and "Alpine" or "SnowPeak"
end

function caveNoise3D(x, y, z, scale)
    return perlin(x * scale, y * scale, z * scale)
end

local C_SCALE = 0.08
local C_BIOME_SCALE = 0.05
local C_TOPSOIL_DEPTH = 3
local C_MAX_SUB_DEPTH = 25
local C_CAVE_3D_SCALE = 0.12
local C_CAVE_DEPTH_SCALE = 0.4
local C_CAVE_THRESHOLD = 0.62
local C_VOLCANO_NOISE_SCALE = 0.04
local C_RIVER_FACTOR = 0.25
local C_VOLCANO_H_NOISE = 0.05
local C_CAVE_MASK_NOISE = 0.09

local function createBaseplate(width, depth, formatType)
    formatType = formatType or "normal"
    
    local nx, nz = width + 1, depth + 1
    local totalPoints = nx * nz
    local heights_buf = ffi.new("double[?]", totalPoints) 

    local function h_index(x, z) return x * nz + z end
    local function set_h(x, z, v) heights_buf[h_index(x, z)] = v end
    local function get_h(x, z) return heights_buf[h_index(x, z)] end

    if formatType == "flat" then
        for z = 0, depth do for x = 0, width do set_h(x, z, 2) end end
    else
        local islands = {}
        for i = 1, 3 do islands[i] = {
            cx = random(6, width - 6), cz = random(6, depth - 6), 
            radius = random(3, 8), height = random(2, 7)
        } end
        for z = 0, depth do
            local z_scaled = z * C_SCALE
            local z_volcano = z * C_VOLCANO_H_NOISE
            local z_mask = z * C_CAVE_MASK_NOISE
            local z_river = z * C_RIVER_FACTOR
            local cos_z_river = cos(z_river)

            for x = 0, width do
                local h = perlin(x * C_SCALE, z_scaled) * 7
                local river = sin(x * C_RIVER_FACTOR) * cos_z_river
                if river > -0.08 and river < 0.08 then h = h - 2.8 end

                for i = 1, #islands do
                    local isl = islands[i]
                    local dx, dz = x - isl.cx, z - isl.cz
                    local distSq = dx * dx + dz * dz
                    local rad = isl.radius
                    if distSq < rad * rad then
                        h = h + isl.height * (1 - sqrt(distSq) / rad)
                    end
                end
                
                local volcanoNoise = perlin(x * C_VOLCANO_H_NOISE, z_volcano)
                if volcanoNoise > 0.95 then h = h + 6 + (volcanoNoise - 0.95) * 10 end
                
                local caveMask = perlin(x * C_CAVE_MASK_NOISE, z_mask, 0)
                if caveMask > 0.7 and h > 3 then h = h - caveMask * 2.5 end

                set_h(x, z, h)
            end
        end
    end

    baseplateTiles = {}
    tileGrid = {}
    local idx = 1
    local tileChunks = {}
    local function chunkKey(cx, cz) return cx..":"..cz end

    for z = 0, depth - 1 do
        tileGrid[z] = tileGrid[z] or {}
        for x = 0, width - 1 do
            local h1, h2 = get_h(x, z), get_h(x + 1, z)
            local h3, h4 = get_h(x + 1, z + 1), get_h(x, z + 1)
            local avgH = (h1 + h2 + h3 + h4) * 0.25 

            local biomeNoise = perlin(x * C_BIOME_SCALE, z * C_BIOME_SCALE)
            local tempNoise = perlin(x * C_BIOME_SCALE * 0.6, z * C_BIOME_SCALE * 0.6 + 200)
            local humidNoise = perlin(x * C_BIOME_SCALE * 1.2 + 400, z * C_BIOME_SCALE * 1.2 + 400)
            local volcanicInfluence = perlin(x * C_VOLCANO_NOISE_SCALE + 1000, z * C_VOLCANO_NOISE_SCALE + 1000)
            local tileTexture = materials.grassNormal
            if avgH < 0.6 then tileTexture = materials.waterDeep
            elseif avgH < 1.8 then tileTexture = materials.waterMedium
            elseif avgH < 3.6 then
                if tempNoise < -0.2 then tileTexture = materials.sandGypsum
                elseif biomeNoise < -0.2 then tileTexture = materials.sandGarnet
                elseif biomeNoise > 0.45 then tileTexture = materials.sandOlivine
                else tileTexture = materials.sandNormal end
            elseif avgH < 6 then
                if tempNoise < -0.25 then tileTexture = materials.grassCold
                elseif tempNoise > 0.4 then tileTexture = materials.grassHot end
            elseif avgH < 9.5 then
                local rockSel = perlin(x * 0.2, z * 0.2)
                tileTexture = rockSel < -0.25 and materials.stone_dark or rockSel > 0.45 and materials.rhyolite or materials.stone
            elseif avgH < 11 then tileTexture = materials.granite
            else tileTexture = materials.snow end

            if volcanicInfluence > 0.93 and avgH > 6 then
                tileTexture = avgH > 10 and (perlin(x * 0.2, z * 0.2) > 0.5 and materials.lava or materials.basalt) or materials.basalt
            end
            
            local subsurface = {}
            local anyCave = false
            for depthY = 1, C_MAX_SUB_DEPTH do
                local worldY = avgH - depthY
                local caveVal = caveNoise3D(x * C_CAVE_3D_SCALE + 500, worldY * C_CAVE_DEPTH_SCALE + 900, z * C_CAVE_3D_SCALE + 700, C_CAVE_3D_SCALE)
                local isCave = (caveVal > C_CAVE_THRESHOLD and worldY < avgH - 1)
                
                if isCave then
                    subsurface[depthY] = "air_cave"
                    anyCave = true
                elseif depthY <= C_TOPSOIL_DEPTH then
                    subsurface[depthY] = (avgH < 3.6 and "sandNormal" or "dirt")
                elseif volcanicInfluence > 0.92 then
                    subsurface[depthY] = "basalt"
                else
                    subsurface[depthY] = "stone"
                end
            end

            if subsurface[1] == "dirt" and subsurface[2] == "air_cave" then subsurface[1] = "air_cave" end
            local chunkX, chunkZ = getChunkCoord(x), getChunkCoord(z)

            local tile = {
                {x, h1, z}, {x + 1, h2, z}, {x + 1, h3, z + 1}, {x, h4, z + 1},
                x = x, z = z, y = avgH, height = avgH, curHeight = avgH,
                biome = determineBiome(avgH, tempNoise, humidNoise, volcanicInfluence),
                texture = tileTexture, subsurface = subsurface,
                containsCave = anyCave,
                isVolcano = (volcanicInfluence > 0.92 and avgH > 6),
                heights = {h1, h2, h3, h4},
                chunkX = chunkX,
                chunkZ = chunkZ,
                mesh = nil,
                needsMesh = true
            }

            baseplateTiles[idx] = tile
            tileGrid[x] = tileGrid[x] or {}
            tileGrid[x][z] = tile

            local ck = chunkKey(chunkX, chunkZ)
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

local dirtTimers = {}
local DIRT_TO_GRASS_TIME = 30

Blocks.baseTiles = baseplateTiles
local function regenerateMap(w, d, seed)
    m.randomseed(seed or os.time())
    createBaseplate(w, d)
end

local preloadedTiles = {}
local lastCamChunkX, lastCamChunkZ = nil, nil
function updateTileMeshes(force)
    local camChunkX, camChunkZ = getChunkCoord(camera.x), getChunkCoord(camera.z)
    if not force and camChunkX == lastCamChunkX and camChunkZ == lastCamChunkZ then
        return
    end
    lastCamChunkX, lastCamChunkZ = camChunkX, camChunkZ

    local visibleTiles = {}
    local r = chunkCfg.radius
    for cz = camChunkZ - r, camChunkZ + r do
        for cx = camChunkX - r, camChunkX + r do
            local list = baseplateTiles._tileChunks[tostring(cx)..":"..tostring(cz)]
            if list then
                for i = 1, #list do visibleTiles[#visibleTiles+1] = baseplateTiles[list[i]] end
            end
        end
    end

    preloadedTiles = verts.generate(visibleTiles, camera, renderDistanceSq, tileGrid, materials)
    verts.ensureAllMeshes(preloadedTiles, materials)
end
local fadeMargin, baseScale = 5, 3.0

local function drawWithStencil(objX, objY, objZ, img, flip, rotation, alpha)
    if not img then return end
    local objChunkX, objChunkZ = getChunkCoord(objX), getChunkCoord(objZ)
    local camChunkX, camChunkZ = getChunkCoord(camera.x), getChunkCoord(camera.z)
    local chunkDistSq = (objChunkX - camChunkX)^2 + (objChunkZ - camChunkZ)^2
    if chunkDistSq > chunkCfg.radius^2 then return end

    local sx, sy, z = camera:project3D(objX, objY, objZ)
    if not sx or z <= 0 then return end
    if sx < fadeMargin or sx > base_width - fadeMargin or sy < fadeMargin or sy > base_height - fadeMargin then return end
    local scale = (camera.hw / z) * (camera.zoom * 0.0025) * baseScale
    local w, h = img:getWidth(), img:getHeight()
    local objDistSq = (objX - camera.x)^2 + (objZ - camera.z)^2

    local sunAngle = (nightCycle.time / (nightCycle.dayLength)) * (2 * math.pi)
    local sunDirX = math.cos(sunAngle)
    local sunDirY = math.sin(sunAngle) * 0.65 + 0.35
    local sunDirZ = math.sin(sunAngle + 0.7)
    sunDirX, sunDirY, sunDirZ = utils.normalize(sunDirX, sunDirY, sunDirZ)
    local textureMul = nightCycle.getTextureMultiplier() or {1,1,1}

    love.graphics.stencil(function()
        for _, t in ipairs(preloadedTiles) do
            if t.mesh and t.dist <= renderDistanceSq and t.dist <= objDistSq + 1 then
                lg.draw(t.mesh)
            end
        end
    end, "replace", 1)
    
    love.graphics.setStencilTest("equal", 0)
    lg.setColor(textureMul[1], textureMul[2], textureMul[3], alpha)
    lg.draw(img, sx, sy, rotation, flip and -scale or scale, scale, w/2, h)
    love.graphics.setStencilTest()
    lg.setColor(1,1,1,1)
end

function getMouseWorldPos(mx, my, maxDistance)
    maxDistance = maxDistance or 100
    local width, height = base_width, base_height
    local nx = (mx / width - 0.5) * 2
    local ny = (my / height - 0.5) * -2
    local yaw, pitch = camera.yaw, camera.pitch
    local cy, sy = cos(yaw), sin(yaw)
    local cp, sp = cos(pitch), sin(pitch)

    local forward = { x = sy * cp, y = sp, z = cy * cp }
    local right = { x = cy, y = 0, z = -sy }
    local up = { x = -sy * sp, y = cp, z = -cy * sp }

    local rayDir = {
        x = forward.x + right.x * nx + up.x * ny,
        y = forward.y + right.y * nx + up.y * ny,
        z = forward.z + right.z * nx + up.z * ny
    }

    local len = sqrt(rayDir.x^2 + rayDir.y^2 + rayDir.z^2)
    rayDir.x, rayDir.y, rayDir.z = rayDir.x / len, rayDir.y / len, rayDir.z / len

    local step = 0.25
    local px, py, pz = camera.x, camera.y, camera.z
    for t = 0, maxDistance, step do
        local wx = px + rayDir.x * t
        local wy = py + rayDir.y * t
        local wz = pz + rayDir.z * t

        local tile = getTileAt(wx, wz)
        local groundY = tile and tile.y or 0
        if wy <= groundY + 0.5 then
            return wx, groundY, wz
        end
    end

    return px + rayDir.x * maxDistance,py + rayDir.y * maxDistance,pz + rayDir.z * maxDistance
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
    if isCursorOverInteractive() then return end
    if not tile or not tile.subsurface then return end
    for i,mat in ipairs(tile.subsurface) do
        if mat ~= "air_cave" then
            tile.texture = materials[mat] or materials.stone
            table.remove(tile.subsurface, i)
            return true
        end
    end
end

function breakTileAt(tileX, tileZ)
    if isCursorOverInteractive() then return end
    local col = tileGrid[tileX]
    if not col then return end
    local tile = col[tileZ]
    if not tile then return end
    tile.height = tile.height - 1
    for i=1,4 do
        tile[i][2] = tile[i][2] - 1
    end
    table.remove(tile.subsurface, 1)
    if tile.height <= 0 then
        tile.isAir = true
        tile.texture = nil
        for i=1,4 do tile[i][2] = 0 end
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
    if not tile or tile.isAir then return end
    local matName
    for k,v in pairs(materials) do
        if v == tile.texture then matName = k break end
    end
    if matName == "dirt" then
        if not dirtTimers[tile] then
            dirtTimers[tile] = math.random() * DIRT_TO_GRASS_TIME
        end
    end
end

local function updateDirtToGrass(dt)
    for _, tile in ipairs(baseplateTiles) do
        if tile.texture == materials.dirt and (tile.height == tile.curHeight or tile.subsurface[1] == "dirt") then
            scheduleDirt(tile)
        end
    end

    for tile, timeLeft in pairs(dirtTimers) do
        timeLeft = timeLeft - dt
        if timeLeft <= 0 then
            tile.texture = materials.grassNormal
            dirtTimers[tile] = nil
            updateTileMeshes(true)
        else
            dirtTimers[tile] = timeLeft
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
            Crafting:mousepressed(mx, my, button, Inventory, itemTypes)
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
        end
        for i = #itemsOnGround, 1, -1 do
            local item = itemsOnGround[i]
            local sx, sy2, z2 = camera:project3D(item.x, item.y, item.z)
            if sx and z2 > 0 then
                local scale = (1 / z2) * 6
                local img = ItemsModule.getItemImage(item.type)
                if img and isMouseOnItem(mx, my, item, img, scale, sx, sy2) then
                    if Inventory:hasFreeSlot() or Inventory:canAddEvenIfFull(item.type, itemTypes) then
                        Inventory:add(item.type, 1, itemTypes)
                        ItemsModule.removeItem(i)
                        return
                    end
                end
            end
        end
            local tile, cx, cy, cz = getTileUnderCursor(mx, my)
            if tile then
                local selected = Inventory:getSelected()
                local multiplier = selected and ItemsModule.getToolMultiplier(selected.type) or 0.5
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
                        revealUnderground(tile)
                        ItemsModule.dropItem(cx, cy+1, cz, matName)
                        breakTileAt(floor(tile[1][1]), floor(tile[1][3]))
                        br.tile = nil
                        br.progress = 0
                        updateTileMeshes(true)
                        damageSelectedItem(1)
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

function love.update(dt)
    love.timer.sleep(0.001)
    Cursor.update(dt)
    updateTileMeshes(true)
    if visible_idk.cursor then love.mouse.setVisible(false) else love.mouse.setVisible(true) end
    if gamestate == "menu" or gamestate == "options"or gamestate == "skins" then
        local mx, my = love.mouse.getPosition()
        local dx = (mx / base_width - 0.5) * 5
        local dz = (my / base_height - 0.5) * 5

        menuTargetCamX, menuTargetCamZ = 11 + dx, -0.1 + dz
        menuCamX = menuCamX + (menuTargetCamX - menuCamX) * bgSmooth
        menuCamZ = menuCamZ + (menuTargetCamZ - menuCamZ) * bgSmooth

        camera.x, camera.z = menuCamX, menuCamZ
        titleX = titleX + (titleTargetX - titleX) * (1 - math.exp(-titleSlideSpeed * dt))
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
            if love.keyboard.isDown("w") then camera.pitch = camera.pitch + sp end
            if love.keyboard.isDown("s") then camera.pitch = camera.pitch - sp end
            camera.pitch = clamp(camera.pitch, -1.2, 1.2)
            countryball.update(dt, love.keyboard, heights, materials, getTileAt, Blocks, camera)
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
            Knapping:update(dt)
            Collision.updateEntity(countryball, dt, tileGrid, Blocks.placed)
            for _, t in ipairs(itemsOnGround) do
                Collision.updateEntity(t, dt, tileGrid, Blocks.placed)
            end
            for _, p in ipairs(Props.props) do
                Collision.updateEntity(p, dt, tileGrid, Blocks.placed)
            end
            Inventory:update(dt)
            Crafting:update(dt)
            Props.updateProps(dt)
            Particles.updateSmoke(dt)
        end
    end
end

local function drawItemsOnGround()
    for _, item in ipairs(itemsOnGround) do
        local img = ItemsModule.getItemImage(item.type)
        drawWithStencil(item.x, item.y, item.z, img, false)
    end
end
local rayStep = 0.25
function getTileUnderCursor(mx, my, maxDistance)
    maxDistance = maxDistance or 100
    local nx = (mx / base_width - 0.5) * 2
    local ny = (my / base_height - 0.5) * -2
    
    local aspect = base_width / base_height
    local tanFOV = math.tan(math.rad(camera.fov / 2))
    local yaw, pitch = camera.yaw, camera.pitch
    local cy, sy = math.cos(yaw), math.sin(yaw)
    local cp, sp = math.cos(pitch), math.sin(pitch)

    local forward = {x=sy*cp, y=sp, z=cy*cp}
    local right = {x=cy, y=0, z=-sy}
    local up = {x=-sy*sp, y=cp, z=-cy*sp}
    local rayDir = {
        x = forward.x + (right.x * nx * aspect * tanFOV) + (up.x * ny * tanFOV),
        y = forward.y + (right.y * nx * aspect * tanFOV) + (up.y * ny * tanFOV),
        z = forward.z + (right.z * nx * aspect * tanFOV) + (up.z * ny * tanFOV)
    }

    local len = math.sqrt(rayDir.x^2 + rayDir.y^2 + rayDir.z^2)
    rayDir.x, rayDir.y, rayDir.z = rayDir.x/len, rayDir.y/len, rayDir.z/len
    
    local px, py, pz = camera.x, camera.y, camera.z
    local closestDist = math.huge
    local hitTile, hitX, hitY, hitZ

    for t = 0, maxDistance, rayStep do
        local wx, wy, wz = px + rayDir.x*t, py + rayDir.y*t, pz + rayDir.z*t
        for _, block in ipairs(Blocks.placed) do
            if math.abs(wx - block.x) <= 0.5 and math.abs(wy - block.y) <= 0.5 and math.abs(wz - block.z) <= 0.5 then
                local dist = t
                if dist < closestDist then
                    closestDist = dist
                    hitTile, hitX, hitY, hitZ = block, block.x, block.y, block.z
                    return hitTile, hitX, hitY, hitZ 
                end
            end
        end
        local tile = getTileAt(wx, wz)
        if tile and not tile.isAir then
            local avgY = (tile[1][2]+tile[2][2]+tile[3][2]+tile[4][2])*0.25
            if wy <= avgY + 0.5 then
                local cx = (tile[1][1]+tile[2][1]+tile[3][1]+tile[4][1])*0.25
                local cz = (tile[1][3]+tile[2][3]+tile[3][3]+tile[4][3])*0.25
                return tile, cx, avgY, cz
            end
        end
    end
end

skyBox.load()

function drawTiles()
    camera:updateProjectionConstants()
    if visible_idk.skyBox then
        local lightFactor = (nightCycle.getLight and nightCycle.getLight() or 1.0)
        lg.setColor(lightFactor,lightFactor,lightFactor,1)
        skyBox.draw()
        lg.setColor(1,1,1,1)
    end
    for i=1,#preloadedTiles do
        local t = preloadedTiles[i]
        if t.mesh then
            lg.draw(t.mesh)
        end
    end
end

function mainGame()
    lg.setDepthMode("lequal", true)
    drawTiles()
    local blockEntries = Blocks.generate(camera, renderDistanceSq)
    Blocks.ensureAllMeshes(blockEntries)
    Blocks.draw(blockEntries)
    Props.drawProps(drawWithStencil)
    drawItemsOnGround()
    countryball.draw(drawWithStencil, Inventory, ItemsModule)
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
    Crafting:draw(Inventory, itemTypes, items)
    Knapping:draw(Inventory, itemTypes)
    Inventory:draw(itemTypes)

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
        local x = menuX
        local y = 131.5 + (i-1) * menuSpacing
        local isSelected = i == selectedIndex
        local borderColor = {0,0,0}
        local textColor = isSelected and {1,1,0} or {1,1,1}
        utils.drawTextWithBorder(text, x, y, base_width, "left", borderColor, textColor)
        love.graphics.setColor(1,1,1)
    end

    local text = "2025 REVIVAL"
    utils.drawTextWithBorder(text, base_width - font:getWidth(text) - 10, base_height - 30, base_width)
    lg.draw(titleImage, titleX, 30)
end

function love.draw()
    local r, g, b = unpack(nightCycle.getSkyColor())
    lg.clear(r, g, b, 1, true, true)
    if gamestate == "game" then
        mainGame()
    elseif gamestate == "menu" then
        menuScreen()
    elseif gamestate == "options" then
        drawTiles()
        OptMenu:draw()
    elseif gamestate == "mods" then
        drawTiles()
    elseif gamestate == "skins" then
        drawTiles()
        SkinsMenu:draw()
    end
    lg.print(string.format("nightCycle: %.2f | Pitch: %.2f | FPS: %d X: %.2f Z: %.2f | WIP GAME",nightCycle.getLight(), camera.pitch, love.timer.getFPS(), camera.x, camera.z),10, 10)
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
        createBaseplate(100,100)
    end
    Cursor.load()
    font = lg.newFont("font/font.ttf", 26)
    lg.setFont(font)
    OptMenu:load(camera, chunkCfg, visible_idk)

    SkinsMenu.load()
    SkinsMenu.applySkin("countryball")

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
                gamestate = "game"
            elseif menuItems[selectedIndex] == "Skins" then
                gamestate = "skins"
            elseif menuItems[selectedIndex] == "Options" then
                gamestate = "options"
            elseif menuItems[selectedIndex] == "Quit" then
                love.event.quit()
            end
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
            Mapsave.save(baseplateTiles, materials)
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
    end
end

function love.run()
    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

    local dt = 0
    local frameCap = 1/80

    return function()
        love.event.pump()
        for name, a,b,c,d,e,f in love.event.poll() do
            if name == "quit" then return a or 0 end
            love.handlers[name](a,b,c,d,e,f)
        end

        love.timer.sleep(frameCap)
        dt = love.timer.step()

        if love.update then love.update(dt) end
        if love.graphics.isActive() then
            love.graphics.origin()
            if love.draw then love.draw() end
            love.graphics.present()
        end
    end
end

function love.quit()
end