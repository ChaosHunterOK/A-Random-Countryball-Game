local love = require "love"
local ffi = require("ffi")
local glrequire = require("ffi/opengl")
local glcompat = require("ffi/opengles2")
local gl = glrequire.gl
local GL = glrequire.GL
glrequire.init()

local lg = love.graphics
lg.setDefaultFilter("nearest", "nearest")
lg.setDepthMode("lequal", true)
lg.setFrontFaceWinding("ccw")

local sqrt = math.sqrt
local floor = math.floor
local sin = math.sin
local cos = math.cos
local tan = math.tan
local pow = math.pow
local max = math.max
local min = math.min
local random = math.random
local rad = math.rad

local camera_3d = {
    x = 8, y = 5, z = -12,
    yaw = 0.0, pitch = 0.5,
    zoom = 1.6, sensitivity = 1.2,
    smoothness = 5.0, freeLook = false
}

local base_width, base_height = 1000, 525
local hw, hh = base_width * 0.5, base_height * 0.5
local fovRad, fovHalfTan, aspect

local function updateProjectionConstants()
    local w, h = base_width, base_height
    hw, hh = w * 0.5, h * 0.5
    aspect = (h ~= 0) and (w / h) or 1
    fovRad = rad(70) / (camera_3d and camera_3d.zoom or 1)
    fovHalfTan = tan(fovRad * 0.5)
end

local countryball = {
    x = 10, y = 0, z = 10,
    health = 3,
    speed = 4,
    flip = false,
    scale = 1,
    Idleimage1 = lg.newImage("image/countryball/senegal/idle1.png"),
    Idleimage2 = lg.newImage("image/countryball/senegal/idle2.png"),
    Walkimage1 = lg.newImage("image/countryball/senegal/walk1.png"),
    Walkimage2 = lg.newImage("image/countryball/senegal/walk2.png"),
    Walkimage3 = lg.newImage("image/countryball/senegal/walk3.png"),
    Walkimage4 = lg.newImage("image/countryball/senegal/walk4.png"),
    Walkimage5 = lg.newImage("image/countryball/senegal/walk5.png"),
}

local inv_bar = lg.newImage("image/bar/inv.png")
local heart = lg.newImage("image/bar/heart.png")
local heart_damage = lg.newImage("image/bar/heart_damage.png")

local items = {
    apple = lg.newImage("image/items/apple.png"),
    amorphous = lg.newImage("image/items/amorphous.png"),
    bituminous_coal = lg.newImage("image/items/bituminous_coal.png"),
    flint = lg.newImage("image/items/flint.png"),
    iron_raw = lg.newImage("image/items/iron_raw.png"),
    map = lg.newImage("image/items/map.png"),
    oak = lg.newImage("image/items/oak.png"),
    paper = lg.newImage("image/items/paper.png"),
    phenocrysts = lg.newImage("image/items/phenocrysts.png"),
    porphyry = lg.newImage("image/items/porphyry.png"),
    ruby = lg.newImage("image/items/ruby.png"),
    snowball = lg.newImage("image/items/snowball.png"),
    stick = lg.newImage("image/items/stick.png"),
    stone = lg.newImage("image/items/stone.png"),
    wood = lg.newImage("image/items/wood.png"),
    anthracite_coal = lg.newImage("image/items/anthracite_coal.png"),
}

local itemTypes = { apple = { img = items.apple } }

local itemsOnGround = {}
local inventory = {}

local currentAnimation = "idle"
local currentFrame = 1
local frameDuration = 0.12
local timeSinceLastFrame = 0

local chunk_size = 15
local render_chunk_radius = 15
local renderDistance = chunk_size * render_chunk_radius
local renderDistanceSq = renderDistance * renderDistance

local animationTimings = {
    idle = { countryball.Idleimage1, countryball.Idleimage2 },
    walk = {
        countryball.Walkimage1, countryball.Walkimage2,
        countryball.Walkimage3, countryball.Walkimage4, countryball.Walkimage5
    },
}

local clamp = function(v, a, b) return v < a and a or (v > b and b or v) end
local function createGLTexture(image)
    if not gl then return nil end
    local texID = ffi.new("GLuint[1]")
    gl.glGenTextures(1, texID)
    gl.glBindTexture(GL.TEXTURE_2D, texID[0])

    local w, h = image:getWidth(), image:getHeight()
    local data = image:getData()
    gl.glTexImage2D(GL.TEXTURE_2D, 0, GL.RGBA, w, h, 0,
                    GL.RGBA, GL.UNSIGNED_BYTE, data:getFFIPointer())

    gl.glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST)
    gl.glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST)
    gl.glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.REPEAT)
    gl.glTexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.REPEAT)
    return texID[0]
end

local function easeInOutQuad(t)
    if t < 0.5 then return 2 * t * t end
    return -1 + (4 - 2 * t) * t
end
local function easeInOutExpo(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    if t < 0.5 then return pow(2, 20 * t - 10) / 2 end
    return (2 - pow(2, -20 * t + 10)) / 2
end
local function easeInOutBack(t)
    local c1 = 1.70158
    local c2 = c1 * 1.525
    if t < 0.5 then
        return (pow(2*t, 2) * ((c2 + 1) * 2*t - c2)) / 2
    end
    return (pow(2*t - 2, 2) * ((c2 + 1) * (t*2 - 2) + c2) + 2) / 2
end
local function lerp(a, b, t) return a + (b - a) * t end
local craftingOpen = false
local craftingAnim = 0
local craftingDuration = 0.525
local craftingTimer = 0
local bgAlpha = 0
local craftingSlots = {nil, nil, nil, nil}
local craftedItem = nil

local function loadMaterials(tbl)
    local mats = {}
    for k, path in pairs(tbl) do mats[k] = lg.newImage(path) end
    return mats
end

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
})

local function loadPropImages()
    return {
        {img = lg.newImage("image/tree.png"), maxHealth = 10, canBreak = true},
        {img = lg.newImage("image/rock.png"), maxHealth = 10, canBreak = true},
        {img = lg.newImage("image/ore_type/iron.png"), maxHealth = 10, canBreak = true}
    }
end
local propTypes = loadPropImages()
local props = {}

local function spawnProps(num, mapWidth, mapDepth)
    for i = 1, num do
        local pType = propTypes[random(1, #propTypes)]
        local px, pz = random() * mapWidth, random() * mapDepth
        props[#props+1] = {
            x = px, y = 0, z = pz,
            img = pType.img,
            health = pType.maxHealth,
            maxHealth = pType.maxHealth,
            canBreak = pType.canBreak,
            shakeTimer = 0, shakeDuration = 0.07,
            shakeOffsetX = 0, shakeOffsetY = 0,
            velocityY = 0
        }
    end
end
spawnProps(12, 20, 20)

local bit = require("bit")
local bxor, band, lshift = bit.bxor, bit.band, bit.lshift

local function hashNoise(ix, iz)
    local n = ix * 374761393 + iz * 668265263
    n = band(bxor(n, lshift(n, 13)), 0xffffffff)
    n = band(n * (n * n * 15731 + 789221) + 1376312589, 0xffffffff)
    return (n % 10000) / 10000
end

local function smoothNoise(x, z)
    local ix, iz = floor(x), floor(z)
    local fx, fz = x - ix, z - iz
    local v00 = hashNoise(ix, iz)
    local v10 = hashNoise(ix + 1, iz)
    local v01 = hashNoise(ix, iz + 1)
    local v11 = hashNoise(ix + 1, iz + 1)
    local ux = fx * fx * (3 - 2 * fx)
    local uz = fz * fz * (3 - 2 * fz)
    local i1 = v00 + (v10 - v00) * ux
    local i2 = v01 + (v11 - v01) * ux
    return i1 + (i2 - i1) * uz
end

local function perlin(x, z, octaves, lacunarity, persistence)
    octaves = octaves or 4
    lacunarity = lacunarity or 2.0
    persistence = persistence or 0.5
    local amplitude, frequency = 1.0, 1.0
    local total, maxA = 0, 0
    for o = 1, octaves do
        total = total + smoothNoise(x * frequency, z * frequency) * amplitude
        maxA = maxA + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end
    return total / maxA
end

local tileGrid = {}
local baseplateTiles = {}
local heights = {}

local function createBaseplate(w, d)
    local scale = 0.1
    heights = {}
    for x = 0, w do heights[x] = {} end

    local numIslands = 3
    local islands = {}
    for i = 1, numIslands do
        islands[#islands+1] = {
            cx = random(4, w-4),
            cz = random(4, d-4),
            radius = random(3, 6),
            height = random(3, 6)
        }
    end

    for z = 0, d do
        for x = 0, w do
            local height = perlin(x*scale, z*scale) * 8
            local river = sin(x*0.25) * cos(z*0.25)
            if river > -0.08 and river < 0.08 then height = height - 2.5 end
            local volcano = sin(x*0.05) * sin(z*0.05)
            if volcano > 0.95 then height = height + 6 end
            for _, isl in ipairs(islands) do
                local dx, dz = x - isl.cx, z - isl.cz
                local dist = sqrt(dx*dx + dz*dz)
                if dist < isl.radius then
                    local factor = (1 - dist/isl.radius)
                    height = height + isl.height * factor
                end
            end
            heights[x][z] = height
        end
    end

    baseplateTiles = {}
    tileGrid = {}
    local idx = 1
    for z = 0, d-1 do
        for x = 0, w-1 do
            local h1, h2 = heights[x][z], heights[x+1][z]
            local h3, h4 = heights[x+1][z+1], heights[x][z+1]
            local avgH = (h1 + h2 + h3 + h4) * 0.25
            local t
            if avgH < -1.5 then t = materials.waterDeep
            elseif avgH < 0 then t = materials.waterSmall
            elseif avgH < 1 then t = materials.sandNormal
            elseif avgH < 3 then t = materials.grassNormal
            elseif avgH < 5 then t = materials.stone
            elseif avgH < 6 then t = materials.granite
            else t = materials.snow end

            local tile = {
                {x, h1, z},
                {x+1, h2, z},
                {x+1, h3, z+1},
                {x, h4, z+1},
                texture = t,
                height = avgH
            }
            baseplateTiles[idx] = tile
            tileGrid[x] = tileGrid[x] or {}
            tileGrid[x][z] = tile
            idx = idx + 1
        end
    end
end

local preloadedTiles = {}

local function project3D(x, y, z, cy, sy, cp, sp)
    local dx, dy, dz = x - camera_3d.x, y - camera_3d.y, z - camera_3d.z
    local x1 = dx * cy - dz * sy
    local z1 = dx * sy + dz * cy
    local y1 = dy * cp - z1 * sp
    local z2 = dy * sp + z1 * cp
    if z2 <= 0.1 then return nil end
    local invZ = 1 / (z2 * fovHalfTan)
    return x1 * invZ / aspect * hw + hw, -y1 * invZ * hh + hh, z2
end

local function updateTileMeshes()
    updateProjectionConstants()
    local yaw, pitch = -camera_3d.yaw, -camera_3d.pitch
    local cy, sy = cos(yaw), sin(yaw)
    local cp, sp = cos(pitch), sin(pitch)
    local n = 0
    for t = 1, #baseplateTiles do
        local tile = baseplateTiles[t]
        if not tile then goto continue end
        local verts = {}
        local visible = true
        for i = 1, 4 do
            local v = tile[i]
            local sx, sy2, z2 = project3D(v[1], v[2], v[3], cy, sy, cp, sp)
            if not sx then visible = false; break end
            verts[i * 2 - 1], verts[i * 2] = sx, sy2
        end

        if visible then
            local v1, v3 = tile[1], tile[3]
            local cx = (v1[1] + v3[1]) * 0.5 - camera_3d.x
            local cz = (v1[3] + v3[3]) * 0.5 - camera_3d.z
            local distSq = cx * cx + cz * cz
            if distSq <= renderDistanceSq then
                n = n + 1
                preloadedTiles[n] = {
                    verts = verts,
                    dist = distSq,
                    texture = tile.texture,
                    mesh = nil,
                    vertsMesh = nil
                }
            end
        end
        ::continue::
    end
    for i = n + 1, #preloadedTiles do preloadedTiles[i] = nil end
    table.sort(preloadedTiles, function(a, b) return a.dist > b.dist end)
end

local function drawWithStencil(objX, objY, objZ, img, flip)
    local function worldToChunkCoord(v) return floor(v / chunk_size) end
    local objChunkX, objChunkZ = worldToChunkCoord(objX), worldToChunkCoord(objZ)
    local camChunkX, camChunkZ = worldToChunkCoord(camera_3d.x), worldToChunkCoord(camera_3d.z)
    local dx, dz = objChunkX - camChunkX, objChunkZ - camChunkZ
    if dx*dx + dz*dz > render_chunk_radius*render_chunk_radius then return end
    local yaw, pitch = -camera_3d.yaw, -camera_3d.pitch
    local cy, sy = cos(yaw), sin(yaw)
    local cp, sp = cos(pitch), sin(pitch)
    local sx, sy2, z2 = project3D(objX, objY, objZ, cy, sy, cp, sp)
    if not sx or z2 <= 0 then return end

    local fadeMargin = 5
    if sx < -fadeMargin or sx > base_width + fadeMargin or sy2 < -fadeMargin or sy2 > base_height + fadeMargin then return end
    local alpha = 1
    if sx < fadeMargin then alpha = max(0, (sx + fadeMargin) / fadeMargin) end
    if sx > base_width - fadeMargin then alpha = max(0, (base_width + fadeMargin - sx) / fadeMargin) end
    if sy2 < fadeMargin then alpha = max(alpha, (sy2 + fadeMargin) / fadeMargin) end
    if sy2 > base_height - fadeMargin then alpha = max(alpha, (base_height + fadeMargin - sy2) / fadeMargin) end
    if alpha <= 0 then return end

    local scale = (1 / z2) * 6
    local w, h = img:getWidth(), img:getHeight()
    lg.stencil(function()
        local objDistSq = (objX - camera_3d.x)^2 + (objZ - camera_3d.z)^2
        for i = 1, #preloadedTiles do
            local t = preloadedTiles[i]
            if not t then break end
            if t.dist <= renderDistanceSq then
                if not t.vertsMesh and t.verts then
                    t.vertsMesh = {
                        {t.verts[1], t.verts[2], 0, 0},
                        {t.verts[3], t.verts[4], 1, 0},
                        {t.verts[5], t.verts[6], 1, 1},
                        {t.verts[7], t.verts[8], 0, 1},
                    }
                end
                if not t.mesh and t.vertsMesh then
                    t.mesh = lg.newMesh(t.vertsMesh, "fan", "static")
                    t.mesh:setTexture(t.texture or materials.grassNormal)
                end
                if t.dist <= objDistSq + 1 and t.mesh then
                    lg.draw(t.mesh)
                end
            end
        end
    end, "replace", 1)
    lg.setStencilTest("equal", 0)
    lg.setColor(1,1,1,alpha)
    lg.draw(img, sx, sy2, 0, (flip and -scale or scale), scale, w/2, h)
    lg.setColor(1,1,1,1)
    lg.setStencilTest()
end

local function drawCountryball()
    local anim = animationTimings[currentAnimation]
    local img = anim and anim[currentFrame] or countryball.Idleimage1
    drawWithStencil(countryball.x, countryball.y, countryball.z, img, countryball.flip)
end

local function getTileAt(x, z)
    local ix, iz = floor(x), floor(z)
    if tileGrid[ix] then return tileGrid[ix][iz] end
    return nil
end

local function getHeightAt(x, z, heightsTbl)
    local ix, iz = floor(x), floor(z)
    local fx, fz = x - ix, z - iz
    local h00 = (heightsTbl[ix] and heightsTbl[ix][iz]) or 0
    local h10 = (heightsTbl[ix+1] and heightsTbl[ix+1][iz]) or h00
    local h01 = (heightsTbl[ix] and heightsTbl[ix][iz+1]) or h00
    local h11 = (heightsTbl[ix+1] and heightsTbl[ix+1][iz+1]) or h00
    local hx1 = h00 + (h10 - h00) * fx
    local hx2 = h01 + (h11 - h01) * fx
    return hx1 + (hx2 - hx1) * fz
end

function love.mousepressed(mx, my, button)
    if button ~= 1 then return end

    local yaw, pitch = -camera_3d.yaw, -camera_3d.pitch
    local cy, sy = cos(yaw), sin(yaw)
    local cp, sp = cos(pitch), sin(pitch)
    for i = #props, 1, -1 do
        local prop = props[i]
        local sx, sy2, z2 = project3D(prop.x, prop.y, prop.z, cy, sy, cp, sp)
        if sx then
            local scale = (1 / z2) * 6
            local w, h = prop.img:getWidth(), prop.img:getHeight()
            local left, top = sx - w/2 * scale, sy2 - h * scale
            local right, bottom = left + w * scale, top + h * scale
            if mx >= left and mx <= right and my >= top and my <= bottom then
                prop.health = max(0, prop.health - 1)
                prop.shakeTimer = prop.shakeDuration
                if random() < 0.15 and prop.img == propTypes[1].img then
                    itemsOnGround[#itemsOnGround+1] = { x = prop.x, y = prop.y + 1, z = prop.z, type = "apple", velocityY = 0 }
                end
                if prop.health <= 0 and prop.canBreak then
                    table.remove(props, i)
                end
            end
        end
    end
    for i = #itemsOnGround, 1, -1 do
        local item = itemsOnGround[i]
        local sx, sy2, z2 = project3D(item.x, item.y, item.z, cy, sy, cp, sp)
        if sx then
            local scale = (1 / z2) * 6
            local img = itemTypes[item.type].img
            local w, h = img:getWidth(), img:getHeight()
            local left, top = sx - w/2 * scale, sy2 - h * scale
            local right, bottom = left + w * scale, top + h * scale
            if mx >= left and mx <= right and my >= top and my <= bottom then
                inventory[item.type] = (inventory[item.type] or 0) + 1
                table.remove(itemsOnGround, i)
            end
        end
    end
end

local gravity = -9.8
local velocityY = 0

local function updateCountryball(dt)
    local moving = false
    local dx, dz = 0, 0
    local kb = love.keyboard

    if kb.isDown("left") then dx = dx - 1; countryball.flip = true; moving = true end
    if kb.isDown("right") then dx = dx + 1; countryball.flip = false; moving = true end
    if kb.isDown("up") then dz = dz - 1; moving = true end
    if kb.isDown("down") then dz = dz + 1; moving = true end

    if moving then
        currentAnimation = "walk"
        local len = sqrt(dx*dx + dz*dz)
        if len > 0 then
            dx, dz = dx/len, dz/len
            countryball.x = countryball.x + dx * countryball.speed * dt
            countryball.z = countryball.z + dz * countryball.speed * dt
        end
    else
        currentAnimation = "idle"
    end

    local groundY = getHeightAt(countryball.x, countryball.z, heights)
    local currentTile = getTileAt(countryball.x, countryball.z)

    local isOnWater = false
    if currentTile then
        local tex = currentTile.texture
        if tex == materials.waterSmall or tex == materials.waterMedium or tex == materials.waterDeep then
            isOnWater = true
        end
    end

    if isOnWater then
        countryball.y = lerp(countryball.y, groundY + 0.3, dt * 4)
        velocityY = 0
    else
        velocityY = velocityY + gravity * dt
        countryball.y = countryball.y + velocityY * dt
        if countryball.y < groundY then countryball.y = groundY; velocityY = 0 end
    end

    timeSinceLastFrame = timeSinceLastFrame + dt
    if timeSinceLastFrame >= frameDuration then
        timeSinceLastFrame = timeSinceLastFrame - frameDuration
        currentFrame = (currentFrame % #animationTimings[currentAnimation]) + 1
    end
end

local selectedSlot = 1
local slotYOffsets = {0,0,0,0}
local slotTargets = {0,0,0,0}
local slotTimers = {0,0,0,0}
local animDuration = 0.4

local function updateCraftingUI(dt)
    if craftingOpen and craftingAnim < 1 then
        craftingTimer = min(craftingTimer + dt, craftingDuration)
        local t = craftingTimer / craftingDuration
        craftingAnim = easeInOutQuad(t)
        bgAlpha = 0.2 * craftingAnim
    elseif (not craftingOpen) and craftingAnim > 0 then
        craftingTimer = min(craftingTimer + dt, craftingDuration)
        local t = craftingTimer / craftingDuration
        craftingAnim = 1 - easeInOutQuad(t)
        bgAlpha = 0.2 * craftingAnim
    end
end

function love.update(dt)
    if love.keyboard.isDown("a") then camera_3d.yaw = camera_3d.yaw + dt * 1.5 end
    if love.keyboard.isDown("d") then camera_3d.yaw = camera_3d.yaw - dt * 1.5 end
    if love.keyboard.isDown("w") then camera_3d.pitch = camera_3d.pitch + dt * 1.2 end
    if love.keyboard.isDown("s") then camera_3d.pitch = camera_3d.pitch - dt * 1.2 end
    camera_3d.pitch = clamp(camera_3d.pitch, -1.2, 1.2)

    updateCountryball(dt)
    local followDistance = 12 / camera_3d.zoom
    local followHeight = 5 / camera_3d.zoom
    local targetX = countryball.x - sin(camera_3d.yaw) * followDistance
    local targetZ = countryball.z - cos(camera_3d.yaw) * followDistance
    local targetY = countryball.y + followHeight
    local smooth = clamp(camera_3d.smoothness * dt, 0, 1)
    camera_3d.x = camera_3d.x + (targetX - camera_3d.x) * smooth
    camera_3d.y = camera_3d.y + (targetY - camera_3d.y) * smooth
    camera_3d.z = camera_3d.z + (targetZ - camera_3d.z) * smooth
    updateTileMeshes()
    for i = #preloadedTiles, 1, -1 do if not preloadedTiles[i] then table.remove(preloadedTiles, i) end end
    for i = 1, 4 do
        if slotYOffsets[i] ~= slotTargets[i] then
            slotTimers[i] = min(slotTimers[i] + dt, animDuration)
            local t = slotTimers[i] / animDuration
            local eased = easeInOutBack(t)
            local startY = (slotTargets[i] == -10) and 0 or -10
            local endY = slotTargets[i]
            slotYOffsets[i] = startY + (endY - startY) * eased
        end
    end
    for _, prop in ipairs(props) do
        prop.velocityY = (prop.velocityY or 0) + gravity * dt
        prop.y = prop.y + prop.velocityY * dt
        local groundY = getHeightAt(prop.x, prop.z, heights)
        if prop.y < groundY then prop.y = groundY; prop.velocityY = 0 end
        if prop.shakeTimer > 0 then
            prop.shakeTimer = max(0, prop.shakeTimer - dt)
            local intensity = 3
            prop.shakeOffsetX = (random() - 0.5) * 2 * intensity
            prop.shakeOffsetY = (random() - 0.5) * 2 * intensity
        else
            prop.shakeOffsetX = 0; prop.shakeOffsetY = 0
        end
    end
    for _, item in ipairs(itemsOnGround) do
        item.velocityY = (item.velocityY or 0) + gravity * dt
        item.y = item.y + item.velocityY * dt
        local groundY = getHeightAt(item.x, item.z, heights)
        if item.y < groundY then item.y = groundY; item.velocityY = 0 end
    end

    updateCraftingUI(dt)
end

local depthStencilCanvas = lg.newCanvas(base_width, base_height, { format = "stencil8" })
local colorCanvas = lg.newCanvas(base_width, base_height)

local function drawProp(prop)
    drawWithStencil(prop.x, prop.y, prop.z, prop.img, false)
    local dx, dz = prop.x - countryball.x, prop.z - countryball.z
    local dist = sqrt(dx*dx + dz*dz)
    local yaw, pitch = -camera_3d.yaw, -camera_3d.pitch
    local cy, sy = cos(yaw), sin(yaw)
    local cp, sp = cos(pitch), sin(pitch)
    local sx, sy2, z2 = project3D(prop.x, prop.y, prop.z, cy, sy, cp, sp)
    if not sx then return end
    local scale = (1 / z2) * 6
    local w, h = prop.img:getWidth(), prop.img:getHeight()
    if dist < 3 then
        local healthBarWidth = 40 * scale
        local healthBarHeight = 6 * scale
        local offsetY = h * scale + 4
        local healthRatio = prop.health / prop.maxHealth
        lg.setColor(0,0,0)
        lg.rectangle("fill", sx - healthBarWidth/2 + prop.shakeOffsetX, sy2 - offsetY + prop.shakeOffsetY, healthBarWidth, healthBarHeight)
        lg.setColor(1 - healthRatio, healthRatio, 0)
        lg.rectangle("fill", sx - healthBarWidth/2 + 1 + prop.shakeOffsetX, sy2 - offsetY + 1 + prop.shakeOffsetY, (healthBarWidth - 2) * healthRatio, healthBarHeight - 2)
        lg.setColor(1,1,1)
    end
end

local function drawItemsOnGround()
    for _, item in ipairs(itemsOnGround) do
        local img = itemTypes[item.type].img
        drawWithStencil(item.x, item.y, item.z, img, false)
    end
end

local function drawInventoryBar()
    local scaleX = love.graphics.getWidth() / base_width
    local scaleY = love.graphics.getHeight() / base_height
    local scale = min(scaleX, scaleY)
    local barWidth = inv_bar:getWidth() * scale
    local barHeight = inv_bar:getHeight() * scale
    local spacing = 8 * scale
    local startX = 10 * scale
    local startY = love.graphics.getHeight() - barHeight - 10 * scale
    local slotItems = {"apple"}
    for i = 1, 4 do
        local x = startX + (i - 1) * (barWidth + spacing)
        local y = startY + slotYOffsets[i] * scale
        lg.setColor(1,1,1,1)
        lg.draw(inv_bar, x, y, 0, scale, scale)
        local itemType = slotItems[i]
        if inventory[itemType] and inventory[itemType] > 0 then
            local itemImg = itemTypes[itemType].img
            local iw, ih = itemImg:getWidth(), itemImg:getHeight()
            local itemX = x + (barWidth - iw * scale) / 2
            local itemY = y + (barHeight - ih * scale) / 2
            lg.draw(itemImg, itemX, itemY, 0, scale, scale)
            lg.setColor(1,1,1)
            lg.print(tostring(inventory[itemType]), x + 24*scale, y + 8*scale)
        end
    end
end

local function drawCraftingUI()
    if craftingAnim <= 0 then return end
    local scaleX = love.graphics.getWidth() / base_width
    local scaleY = love.graphics.getHeight() / base_height
    local scale = min(scaleX, scaleY)
    lg.setColor(0,0,0,bgAlpha)
    lg.rectangle("fill", 0,0, love.graphics.getWidth(), love.graphics.getHeight())
    lg.setColor(1,1,1)

    local barWidth, barHeight = inv_bar:getWidth() * scale, inv_bar:getHeight() * scale
    local spacing = 8 * scale
    local totalWidth = (barWidth + spacing) * 2
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local startY = love.graphics.getHeight()/2 + 355*(1-craftingAnim) - 100

    for i = 1, 4 do
        local col = (i-1)%2
        local row = floor((i-1)/2)
        local x = startX + col*(barWidth + spacing)
        local y = startY + row*(barHeight + spacing)
        lg.setColor(1,1,1,1)
        lg.draw(inv_bar, x, y, 0, scale, scale)
        local itemType = craftingSlots[i]
        if itemType and inventory[itemType] and inventory[itemType] > 0 then
            local itemImg = itemTypes[itemType].img
            local iw, ih = itemImg:getWidth(), itemImg:getHeight()
            local itemX = x + (barWidth - iw * scale) / 2
            local itemY = y + (barHeight - ih * scale) / 2
            lg.draw(itemImg, itemX, itemY, 0, scale, scale)
        end
    end

    local outputX = startX + totalWidth + spacing*2
    local outputY = startY + (barHeight + spacing) / 2
    if craftedItem then
        local itemImg = items[craftedItem]
        if itemImg then
            local iw, ih = itemImg:getWidth(), itemImg:getHeight()
            local t = easeInOutExpo(craftingAnim)
            lg.draw(itemImg, outputX, outputY, 0, scale*t, scale*t, iw/2, ih/2)
        end
    end
end

function love.draw()
    lg.setCanvas({colorCanvas, depthstencil = depthStencilCanvas})
    updateProjectionConstants()
    lg.clear(0.4, 0.6, 0.9)
    for i = 1, #preloadedTiles do
        local t = preloadedTiles[i]
        if t and t.verts and #t.verts >= 8 then
            if not t.mesh then
                local verts = {
                    {t.verts[1], t.verts[2], 0, 0},
                    {t.verts[3], t.verts[4], 1, 0},
                    {t.verts[5], t.verts[6], 1, 1},
                    {t.verts[7], t.verts[8], 0, 1},
                }
                t.mesh = lg.newMesh(verts, "fan", "static")
                t.mesh:setTexture(t.texture or materials.grassNormal)
            end
            lg.draw(t.mesh)
        end
    end
    for i = 1, #props do drawProp(props[i]) end
    drawItemsOnGround()
    drawCountryball()

    lg.setCanvas()
    lg.draw(colorCanvas, 0, 0)
    --lg.print("Yaw: " .. string.format("%.2f", camera_3d.yaw) .. " | Pitch: " .. string.format("%.2f", camera_3d.pitch).." | FPS: " .. love.timer.getFPS().. " | WIP GAME", 10, 10)

    drawCraftingUI()
    drawInventoryBar()
end

function love.load()
    love.window.setMode(base_width, base_height, {resizable=true, vsync=true})
    love.window.setTitle("A Random Countryball Game")
    local icon = love.image.newImageData("icon/icon.png")
    love.window.setIcon(icon)
    createBaseplate(12, 12)
    for i, prop in ipairs(props) do
        prop.y = getHeightAt(prop.x, prop.z, heights)
    end

    music = love.audio.newSource("music/music.mp3", "stream")
    music:setLooping(true)
    music:play()

    updateTileMeshes()
    lg.setDepthMode("lequal", true)

    glcompat.enable(glcompat.GL_DEPTH_TEST)
    glcompat.enable(glcompat.GL_BLEND)
    glcompat.blendFunc(glcompat.GL_SRC_ALPHA, glcompat.GL_ONE_MINUS_SRC_ALPHA)
end

function love.mousemoved(x, y, dx, dy)
    if camera_3d.freeLook then
        camera_3d.yaw = camera_3d.yaw - dx * 0.005 * camera_3d.sensitivity
        camera_3d.pitch = camera_3d.pitch - dy * 0.003 * camera_3d.sensitivity
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
    if key == "tab" then
        camera_3d.freeLook = not camera_3d.freeLook
        love.mouse.setRelativeMode(camera_3d.freeLook)
    end
    if key >= "1" and key <= "4" then
        local newSlot = tonumber(key)
        if newSlot and newSlot ~= selectedSlot then
            slotTimers[selectedSlot], slotTimers[newSlot] = 0, 0
            slotTargets[selectedSlot], slotTargets[newSlot] = 0, -10
            selectedSlot = newSlot
        end
    end
    if key == "e" then
        craftingOpen = not craftingOpen
        craftingTimer = 0
    end
end

function love.resize(w, h)
    base_width, base_height = w, h
    hw, hh = w/2, h/2
    aspect = w/h
    colorCanvas = lg.newCanvas(base_width, base_height)
    depthStencilCanvas = lg.newCanvas(base_width, base_height, { format = "stencil8" })
    updateTileMeshes()
end