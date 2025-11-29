local love, lg = require("love"), love.graphics
local ffi, glreq, glcompat = require("ffi"), require("ffi/opengl"), require("ffi/opengles2")
local gl, GL = glreq.gl, glreq.GL
glreq.init()

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

local camera_3d = require(proj.."camera")
local countryball = require(src.."countryball")
local ItemsModule = require(src.."items")
local Inventory = require(hud.."inv")
local Crafting = require(hud.."craft")
local Knapping = require(hud.."knap")
local verts = require(proj.."verts")
local Props = require(src.."props")
local utils = require(src.."utils")
local Collision = require(src.."collision")
local OptionsMenu = require(menu.."options")
local Cursor = require(hud.."cursor")
local healthBar = require(hud.."health_bar")
local hungerBar = require(hud.."hunger_bar")
local Mapsave = require(proj.."mapsave")

local clamp, perlin = utils.clamp, utils.perlin

local itemsOnGround = ItemsModule.itemsOnGround
local itemTypes = ItemsModule.itemTypes
local items = ItemsModule.items

local chunk_thing = {chunk_size = 4, render_chunk_radius = 4}
local base_width, base_height = 1000, 525
local renderDistance = chunk_thing.chunk_size * chunk_thing.render_chunk_radius
local renderDistanceSq = renderDistance * renderDistance

function loadMaterials(tbl)
    local result = {}
    for k, path in pairs(tbl) do
        local info = love.filesystem.getInfo(path)
        result[k] = info and lg.newImage(path) or nil
    end
    return result
end

local menuItems = {"Play", "Mods", "Skins", "Options", "Quit"}
local selectedIndex = 1
local menuX = 50
local menuSpacing = 81.25
local menuCamX, menuCamZ = 50, 50
local menuTargetCamX, menuTargetCamZ = 50, 50
local bgSmooth = 0.02

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
})

local Blocks = require(proj.."blocks")
Blocks.load(materials)

local tileGrid, baseplateTiles, heights = {}, {}, {}
local mapSeed = os.time()

local function getTileAt(x, z)
    local col = tileGrid[floor(x)]
    return col and col[floor(z)]
end
Props.spawnProps(25, 20, 20)

local function setSeed(seed)
    mapSeed = seed
    m.randomseed(mapSeed)
end

local function getChunkCoord(v) return floor(v / chunk_thing.chunk_size) end

function determineBiome(h, t, h2, volc)
    if h < 0.6  then return "OceanDeep" end
    if h < 1.8  then return "OceanShallow" end
    if h < 3.6  then
        return t > 0.45 and "HotDesert" or t < -0.2 and "ColdDesert" or "Desert"
    end
    if volc > 0.92 and h > 6 then
        return h > 10 and "VolcanicPeak" or "Volcanic"
    end
    if h < 6.0 then
        return t < -0.25 and "Tundra" or t > 0.4 and "Savanna" or "Grassland"
    end
    if h < 9.5 then
        return h2 < -0.2 and "DryHighlands" or h2 > 0.4 and "WetHighlands" or "Highlands"
    end
    return h < 11 and "Alpine" or "SnowPeak"
end

function caveNoise3D(x, y, z, scale)
    return perlin(x * scale, y * scale, z * scale)
end

local function createBaseplate(width, depth)
    local scale = 0.08
    local biomeScale = 0.05
    local topsoilDepth = 3
    local maxSubDepth = 25
    local cave3dScale = 0.12
    local caveDepthScale = 0.4
    local caveThreshold = 0.62

    heights = {}
    for x = 0, width do heights[x] = {} end
    local islands = {}
    for i = 1, 3 do
        islands[i] = {
            cx = random(6, width - 6),
            cz = random(6, depth - 6),
            radius = random(3, 8),
            height = random(2, 7)
        }
    end

    local volcanoCenters = {}
    local volcanoNoiseScale = 0.04
    for z = 0, depth do
        for x = 0, width do
            local v = perlin(x * volcanoNoiseScale, z * volcanoNoiseScale)
            if v > 0.94 then
                volcanoCenters[#volcanoCenters + 1] = {x=x, z=z, strength=(v-0.94)*8}
            end
        end
    end

    for z = 0, depth do
        local nz = z * scale
        for x = 0, width do
            local nx = x * scale
            local h = perlin(nx, nz) * 7
            local river = sin(x * 0.25) * cos(z * 0.25)
            if river > -0.08 and river < 0.08 then h = h - 2.8 end
            for _, isl in ipairs(islands) do
                local dx, dz = x - isl.cx, z - isl.cz
                local dist = sqrt(dx*dx + dz*dz)
                if dist < isl.radius then
                    h = h + isl.height * (1 - dist / isl.radius)
                end
            end
            local volcanoNoise = perlin(x * 0.05, z * 0.05)
            if volcanoNoise > 0.95 then
                h = h + 6 + (volcanoNoise - 0.95) * 10
            end
            local caveMask = perlin(x * 0.09, z * 0.09, 0)
            if caveMask > 0.7 and h > 3 then
                h = h - caveMask * 2.5
            end

            heights[x][z] = h
        end
    end

    baseplateTiles, tileGrid = {}, {}
    local idx = 1

    for z = 0, depth-1 do
        for x = 0, width-1 do
            local h1, h2 = heights[x][z], heights[x+1][z]
            local h3, h4 = heights[x+1][z+1], heights[x][z+1]
            local avgH = (h1 + h2 + h3 + h4) * 0.25
            local biomeNoise = perlin(x * biomeScale, z * biomeScale)
            local tempNoise  = perlin(x * (biomeScale * 0.6), z * (biomeScale * 0.6) + 200)
            local humidNoise = perlin(x * (biomeScale * 1.2) + 400, z * (biomeScale * 1.2) + 400)
            local volcanicInfluence = perlin(x * 0.04 + 1000, z * 0.04 + 1000)
            local tileTexture
            if avgH < 0.6 then
                tileTexture = materials.waterDeep
            elseif avgH < 1.8 then
                tileTexture = materials.waterMedium
            elseif avgH < 3.6 then
                if tempNoise < -0.2 then tileTexture = materials.sandGypsum
                elseif biomeNoise < -0.2 then tileTexture = materials.sandGarnet
                elseif biomeNoise > 0.45 then tileTexture = materials.sandOlivine
                else tileTexture = materials.sandNormal end
            elseif avgH < 6 then
                if avgH > 5.5 and tempNoise < -0.35 then
                    tileTexture = materials.grassCold
                else
                    tileTexture = tempNoise < -0.25 and materials.grassCold or (tempNoise > 0.4 and materials.grassHot or materials.grassNormal)
                end
            elseif avgH < 9.5 then
                local rockSelector = perlin(x * 0.2, z * 0.2)
                tileTexture = rockSelector < -0.25 and materials.stone_dark or (rockSelector > 0.45 and materials.rhyolite or materials.stone)
            elseif avgH < 11 then
                tileTexture = materials.granite
            else
                tileTexture = materials.snow
            end

            if volcanicInfluence > 0.93 and avgH > 6 then
                tileTexture = avgH > 10 and perlin(x*0.2,z*0.2)>0.5 and materials.lava or materials.basalt
            end

            local subsurface = {}
            local caveSeedX, caveSeedZ = x * cave3dScale + 500, z * cave3dScale + 700
            for depth = 1, maxSubDepth do
                local worldY = avgH - depth
                local caveVal = caveNoise3D(caveSeedX, worldY * caveDepthScale + 900, caveSeedZ, cave3dScale)
                if caveVal > caveThreshold and worldY < avgH - 1 then
                    subsurface[depth] = "air_cave"
                else
                    subsurface[depth] = depth <= topsoilDepth and (avgH < 3.6 and "sandNormal" or "dirt") or (
                        volcanicInfluence > 0.92 and "basalt" or
                        (function()
                            local n = perlin(x*0.18, z*0.18, worldY*0.12)
                            if n < -0.45 then return "gabbro"
                            elseif n < -0.15 then return "granite"
                            elseif n < 0.25 then return "porphyry"
                            else
                                local special = perlin(x*0.4+300, z*0.4+300, worldY*0.18)
                                return special > 0.55 and "pumice" or (special > 0.25 and "rhyolite" or "stone")
                            end
                        end)()
                    )
                end
            end

            if subsurface[1] == "dirt" and subsurface[2] == "air_cave" then
                subsurface[1] = "air_cave"
            end

            local biome = determineBiome(avgH, tempNoise, humidNoise, volcanicInfluence)

            local tile = {
                {x, h1, z}, {x+1, h2, z}, {x+1, h3, z+1}, {x, h4, z+1},
                x = x, z = z, y = avgH, w = 1, d = 1, h = 1, height = avgH, curHeight = avgH,
                biome = biome, texture = tileTexture, subsurface = subsurface,
                containsCave = utils.any(subsurface, function(v) return v == "air_cave" end),
                isVolcano = (volcanicInfluence > 0.92 and avgH > 6),
                heights = {h1, h2, h3, h4},
            }

            baseplateTiles[idx] = tile
            tileGrid[x] = tileGrid[x] or {}
            tileGrid[x][z] = tile
            idx = idx + 1
        end
    end
end

Blocks.baseTiles = baseplateTiles
local function regenerateMap(w, d, seed)
    m.randomseed(seed or os.time())
    createBaseplate(w, d)
end

local preloadedTiles = {}
local lastChunkX, lastChunkZ = -1e6, -1e6
local function updateTileMeshes(force)
    local camChunkX, camChunkZ = getChunkCoord(camera_3d.x), getChunkCoord(camera_3d.z)
    if force or camChunkX ~= lastChunkX or camChunkZ ~= lastChunkZ then
        preloadedTiles = verts.generate(baseplateTiles, camera_3d, renderDistanceSq, tileGrid, materials)
        verts.ensureAllMeshes(preloadedTiles, materials)
        lastChunkX, lastChunkZ = camChunkX, camChunkZ
    end
end
local fadeMargin, baseScale = 5, 3.0

local function drawWithStencil(objX, objY, objZ, img, flip)
    if not img then return end
    local objChunkX, objChunkZ = getChunkCoord(objX), getChunkCoord(objZ)
    local camChunkX, camChunkZ = getChunkCoord(camera_3d.x), getChunkCoord(camera_3d.z)
    local chunkDistSq = (objChunkX - camChunkX)^2 + (objChunkZ - camChunkZ)^2
    if chunkDistSq > chunk_thing.render_chunk_radius^2 then return end
    local sx, sy, z = camera_3d:project3D(objX, objY, objZ)
    if not sx or z <= 0 then return end

    if sx < fadeMargin or sx > base_width - fadeMargin or sy < fadeMargin or sy > base_height - fadeMargin then return end
    local scale = (camera_3d.hw / z) * (camera_3d.zoom * 0.0025) * baseScale
    local w, h = img:getWidth(), img:getHeight()
    local objDistSq = (objX - camera_3d.x)^2 + (objZ - camera_3d.z)^2

    love.graphics.stencil(function()
        for _, t in ipairs(preloadedTiles) do
            if t.mesh and t.dist <= renderDistanceSq and t.dist <= objDistSq + 1 then
                lg.draw(t.mesh)
            end
        end
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 0)
    lg.setColor(1,1,1,1)
    lg.draw(img, sx, sy, 0, flip and -scale or scale, scale, w/2, h)
    love.graphics.setStencilTest()
end

function getMouseWorldPos(mx, my, maxDistance)
    maxDistance = maxDistance or 100
    local width, height = base_width, base_height
    local nx = (mx / width - 0.5) * 2
    local ny = (my / height - 0.5) * -2
    local yaw, pitch = camera_3d.yaw, camera_3d.pitch
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
    local px, py, pz = camera_3d.x, camera_3d.y, camera_3d.z
    for t = 0, maxDistance, step do
        local wx = px + rayDir.x * t
        local wy = py + rayDir.y * t
        local wz = pz + rayDir.z * t

        local groundY = utils.getHeightAt(wx, wz, heights)
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
        local sx, sy2, z2 = camera_3d:project3D(item.x, item.y, item.z)
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
                local sx, sy2, z2 = camera_3d:project3D(px, py, pz)
                if sx and z2 > 0 then
                    local w, h = img:getWidth(), img:getHeight()
                    local scale = (camera_3d.hw / z2) * camera_3d.zoom * 0.0025 * 3.0
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

function love.mousepressed(mx, my, button)
    if Props and Props.handleMousePressed and Props.handleMousePressed(mx, my) then
        return
    end

    if Crafting.open then
        Crafting:mousepressed(mx, my, button, Inventory, itemTypes)
        return
    end

    Inventory:mousepressed(mx, my, button, itemTypes)
    local slot = Inventory:getSelected()
    if button == 1 and slot and slot.type == "stone" and slot.count >= 2 and not isCursorOverInteractive(mx, my) then
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

    if Knapping.open then
        Knapping.timer = (Knapping.timer or 0) + love.timer.getDelta()
        if Knapping.timer >= 0.3 then
            Knapping:mousepressed(mx, my, button, Inventory, itemTypes, ItemsModule, countryball)
        end
        return
    end
    for i = #itemsOnGround, 1, -1 do
        local item = itemsOnGround[i]
        local sx, sy2, z2 = camera_3d:project3D(item.x, item.y, item.z)
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
    if gamestate == "game" then
        local tile, cx, cy, cz = getTileUnderCursor(mx, my)
        if tile then
            local selected = Inventory:getSelected()
            local multiplier = selected and ItemsModule.getToolMultiplier(selected.type) or 1
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

function love.mousereleased(mx, my, button)
    if not Crafting.open then
        Inventory:mousereleased(mx, my, button, ItemsModule, countryball)
    end
end

local titleX = 2000
local titleTargetX = base_width - titleImage:getWidth() - 30
local titleSlideSpeed = 8

function love.update(dt)
    verts.setTime(love.timer.getTime())
    Cursor.update(dt)
    updateTileMeshes(true)
    if gamestate == "menu" then
        local mx, my = love.mouse.getPosition()
        local dx = (mx / base_width - 0.5) * 5
        local dz = (my / base_height - 0.5) * 5
        menuTargetCamX = 11 + dx
        menuTargetCamZ = -0.1 + dz
        menuCamX = menuCamX + (menuTargetCamX - menuCamX) * bgSmooth
        menuCamZ = menuCamZ + (menuTargetCamZ - menuCamZ) * bgSmooth
        camera_3d.x = menuCamX
        camera_3d.z = menuCamZ
        local diff = titleTargetX - titleX
        titleX = titleX + diff * (1 - math.exp(-titleSlideSpeed * dt))
    elseif gamestate == "game" then
        local camSpeedYaw, camSpeedPitch = 1.5 * dt, 1.2 * dt
        if love.keyboard.isDown("a") then camera_3d.yaw = camera_3d.yaw + camSpeedYaw end
        if love.keyboard.isDown("d") then camera_3d.yaw = camera_3d.yaw - camSpeedYaw end
        if love.keyboard.isDown("w") then camera_3d.pitch = camera_3d.pitch + camSpeedPitch end
        if love.keyboard.isDown("s") then camera_3d.pitch = camera_3d.pitch - camSpeedPitch end
        camera_3d.pitch = clamp(camera_3d.pitch, -1.2, 1.2)

        countryball.update(dt, love.keyboard, heights, materials, getTileAt, Blocks, camera_3d)
        local followDist, followHeight = 12 / camera_3d.zoom, 15 / camera_3d.zoom
        local targetX = countryball.x - sin(camera_3d.yaw) * followDist
        local targetZ = countryball.z - cos(camera_3d.yaw) * followDist
        local targetY = countryball.y - sin(camera_3d.pitch) * followHeight
        local smooth = clamp(camera_3d.smoothness * dt, 0, 1)
        camera_3d.x = camera_3d.x + (targetX - camera_3d.x) * smooth
        camera_3d.y = camera_3d.y + (targetY - camera_3d.y) * smooth
        camera_3d.z = camera_3d.z + (targetZ - camera_3d.z) * smooth

        if countryball.y <= -10 then
            healthBar:setHealth(0)
        end
        music:play()
        healthBar:update(dt)
        Knapping:update(dt)
        Collision.updateEntity(countryball, dt, heights, Blocks.placed,tileGrid, materials)
        for _, item in ipairs(itemsOnGround) do
            Collision.updateEntity(item, dt, heights, Blocks.placed,tileGrid, materials)
        end
        for _, prop in ipairs(Props.props) do
            Collision.updateEntity(prop, dt, heights, Blocks.placed,tileGrid, materials)
        end
        Inventory:update(dt)
        Crafting:update(dt)
        Props.updateProps(dt, heights)
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
    local nx, ny = (mx / base_width - 0.5) * 2, (my / base_height - 0.5) * -2
    local yaw, pitch = camera_3d.yaw, camera_3d.pitch
    local cy, sy, cp, sp = cos(yaw), sin(yaw), cos(pitch), sin(pitch)

    local forward = {x=sy*cp, y=sp, z=cy*cp}
    local right = {x=cy, y=0, z=-sy}
    local up = {x=-sy*sp, y=cp, z=-cy*sp}
    local rayDir = {
        x = forward.x + right.x*nx + up.x*ny,
        y = forward.y + right.y*nx + up.y*ny,
        z = forward.z + right.z*nx + up.z*ny
    }

    local len = sqrt(rayDir.x^2 + rayDir.y^2 + rayDir.z^2)
    rayDir.x, rayDir.y, rayDir.z = rayDir.x/len, rayDir.y/len, rayDir.z/len
    local px, py, pz = camera_3d.x, camera_3d.y, camera_3d.z

    for t = 0, maxDistance, rayStep do
        local wx, wy, wz = px + rayDir.x*t, py + rayDir.y*t, pz + rayDir.z*t
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
function drawTiles()
    camera_3d:updateProjectionConstants(base_width, base_height)
    for i=1,#preloadedTiles do
        local t = preloadedTiles[i]
        if t and t.mesh then
            lg.draw(t.mesh)
        end
    end
end

function mainGame()
    lg.setDepthMode("lequal", true)
    drawTiles()
    local blockEntries = Blocks.generate(camera_3d, renderDistanceSq)
    Blocks.ensureAllMeshes(blockEntries)
    Blocks.draw(blockEntries)
    Props.drawProps(drawWithStencil)
    drawItemsOnGround()
    countryball.draw(drawWithStencil, Inventory, ItemsModule)
    lg.setDepthMode()
    local tile, cx, cy, cz = getTileUnderCursor(love.mouse.getX(), love.mouse.getY())
    if tile then
        local sx, sy, sz = camera_3d:project3D(cx, cy + 0.05, cz)
        if sx then
            local scale = (camera_3d.hw / sz) * camera_3d.zoom * 0.05
            lg.setColor(1, 0, 0, 0.6)
            lg.circle("line", sx, sy, scale)
            lg.setColor(1, 1, 1, 1)
        end
    end

    healthBar:draw()
    Crafting:draw(Inventory, itemTypes, items)
    Knapping:draw(Inventory, itemTypes)
    Inventory:draw(itemTypes)
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
        utils.drawTextWithBorder(text, x, y, love.graphics.getWidth(), "left", borderColor, textColor)
        love.graphics.setColor(1,1,1)
    end

    local text = "2025 REVIVAL"
    utils.drawTextWithBorder(text, base_width - font:getWidth(text) - 10, base_height - 30, love.graphics.getWidth())
    lg.draw(titleImage, titleX, 30)
end

function love.draw()
    lg.clear(0.4, 0.6, 0.9, 1, true, true)
    if gamestate == "game" then
        mainGame()
    elseif gamestate == "menu" then
        menuScreen()
    elseif gamestate == "options" then
        drawTiles()
        OptionsMenu:draw()
    elseif gamestate == "mods" then
    elseif gamestate == "skins" then
    end
    lg.print(string.format("Yaw: %.2f | Pitch: %.2f | FPS: %d X: %.2f Z: %.2f | WIP GAME",camera_3d.yaw, camera_3d.pitch, love.timer.getFPS(), camera_3d.x, camera_3d.z),10, 10)
    Cursor.draw()
end

function love.load()
    love.window.setMode(base_width, base_height, {resizable=false, vsync=true})
    love.window.setTitle("A Random Countryball Game")
    love.window.setIcon(love.image.newImageData("icon/icon.png"))
    local loadedTiles, loadedGrid, loadedPlacedBlocks = Mapsave.load(materials)
    if loadedTiles then
        baseplateTiles = loadedTiles
        tileGrid = loadedGrid
        Blocks.placed = loadedPlacedBlocks
    else
        createBaseplate(20, 20)
    end
    love.mouse.setVisible(false)
    Cursor.load()
    font = lg.newFont("font/font.ttf", 26)
    lg.setFont(font)

    music = love.audio.newSource("music/music.mp3", "stream")
    music:setLooping(true)

    updateTileMeshes(true)
    lg.setDepthMode("lequal", true)
end

function love.mousemoved(x, y, dx, dy)
    if camera_3d.freeLook then
        camera_3d.yaw = camera_3d.yaw - dx * 0.5 * camera_3d.sensitivity
        camera_3d.pitch = camera_3d.pitch - dy * 0.3 * camera_3d.sensitivity
        if camera_3d.pitch < -1.2 then camera_3d.pitch = -1.2 end
        if camera_3d.pitch > 1.2 then camera_3d.pitch = 1.2 end
    end
end

function love.wheelmoved(x, y)
    camera_3d.zoom = camera_3d.zoom - y * 0.1
    if camera_3d.zoom < 0.5 then camera_3d.zoom = 0.5 end
    if camera_3d.zoom > 2.5 then camera_3d.zoom = 2.5 end
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
            elseif menuItems[selectedIndex] == "Options" then
                gamestate = "options"
            elseif menuItems[selectedIndex] == "Quit" then
                love.event.quit()
            end
        end
    elseif gamestate == "game" then
        if key == "tab" then
            camera_3d.freeLook = not camera_3d.freeLook
        end
        if key == "e" and not Knapping.open then Crafting:toggle() end
        Inventory:keypressed(key)

        if key == "q" then healthBar:damageHealth(1) end

        if key == "escape" then Knapping.open = false end

        if key == "f5" then
            Mapsave.save(baseplateTiles, materials)
        end
    elseif gamestate == "options" then
        OptionsMenu:keypressed(key, camera_3d, chunk_thing)
        if key == "escape" then gamestate = "menu" end
    end
end

function love.quit()
end