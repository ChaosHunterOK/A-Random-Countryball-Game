local love = require "love"
local lg = love.graphics
local sqrt, max, random, floor, cos, sin, pi = math.sqrt, math.max, math.random, math.floor, math.cos, math.sin, math.pi

local camera = require("source.projectile.camera")
local countryball = require("source.countryball")
local ItemsModule = require("source.items")
local utils = require("source.utils.utils")
local Inventory = require("source.hud.inv")
local nightCycle = require("source.projectile.night_cycle")
local Particles = require("source.projectile.particles")
local hitParticleOpts = {
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
local destroyParticleOpts = {
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

local im = "image/"
local props = {}
local shakingProps = {}
local treeCutImg = lg.newImage(im.."plants/tree_cut.png")
local occupiedTiles = {}
local nextPropId = 1

local treeStages = {
    { name = "planted", img = lg.newImage(im.."plants/tree/planted.png"), growTime = 20 },
    { name = "sprout",  img = lg.newImage(im.."plants/tree/sprout.png"),  growTime = 30 },
    { name = "sapling", img = lg.newImage(im.."plants/tree/sapling.png"), growTime = 40 }
}

local propTypes = {
    {
        img = lg.newImage(im.."plants/tree/tree.png"), 
        maxHealth = 10, name = "Tree", bestTool = "axe", 
        rewards = { {item = "oak", count = {3, 7}} },
        isTree = true, spawnOn = {"grassNormal", "grassCold"}, scale = {1.5, 1.6},
    },
    {
        img = lg.newImage(im.."plants/acacia.png"), 
        maxHealth = 10, name = "Acacia Tree", bestTool = "axe", 
        rewards = { {item = "oak", count = {3, 7}} },
        isTree = true, spawnOn = {"grassHot"}, scale = {1.7, 1.8},
    },
    {
        img = lg.newImage(im.."rocks/rock.png"), 
        maxHealth = 25, name = "Rock", bestTool = "pickaxe", 
        rewards = { {item = "stone", count = {2, 4}} },
        spawnOn = {"stone", "granite", "grassNormal"}
    },
    {
        img = lg.newImage(im.."rocks/mini_rock.png"), 
        maxHealth = 5, name = "Mini Rock", bestTool = "pickaxe", 
        rewards = { {item = "stone", count = {1, 1}} },
        spawnOn = {"grassCold", "grassHot", "grassNormal", "grassRainforest", "stone"}
    },
    {
        img = lg.newImage(im.."ore_type/iron.png"),
        maxHealth = 32, name = "Iron Ore", bestTool = "pickaxe",
        rewards = { {item = "stone", count = {2, 4}}, {item = "iron_raw", count = {1, 3}} },
        spawnOn = {"stone", "stone_dark", "granite"}
    },
    {
        img = lg.newImage(im.."plants/bush.png"), 
        maxHealth = 2, name = "Bush", bestTool = "knife", 
        rewards = { {item = "leaf", count = {3, 6}} },
        spawnOn = {"grassNormal"}
    },
    {
        img = lg.newImage(im.."plants/bush_hot.png"), 
        maxHealth = 2, name = "Hot Bush", bestTool = "knife", 
        rewards = { {item = "leaf", count = {3, 6}} },
        spawnOn = {"grassHot", "sandNormal", "sandGypsum"}
    },
    {
        img = lg.newImage(im.."plants/buttonbush.png"), 
        maxHealth = 2, name = "Buttonbush", bestTool = "knife", 
        rewards = { {item = "leaf", count = {3, 6}} },
        spawnOn = {"grassRainforest"}
    },
    {
        img = lg.newImage(im.."plants/cactus/barrel.png"), 
        maxHealth = 8, name = "Barrel Cactus", bestTool = "axe", 
        --rewards = { {item = "leaf", count = {3, 6}} },
        spawnOn = {"sandNormal"}
    },
    {
        img = lg.newImage(im.."plants/bush_cold.png"), 
        maxHealth = 2, name = "Bush Cold", bestTool = "knife", 
        rewards = { {item = "leaf", count = {3, 6}} },
        spawnOn = {"grassCold"}
    },
    {
        img = lg.newImage(im.."rocks/porphyry_rock.png"), 
        maxHealth = 25, name = "Porphyry Rock", bestTool = "pickaxe", 
        rewards = { {item = "porphyry", count = {2, 4}} },
        spawnOn = {"stone", "porphyry"}
    },
    {
        img = lg.newImage(im.."rocks/mini_porphyry_rock.png"), 
        maxHealth = 5, name = "Mini Porphyry Rock", bestTool = "pickaxe", 
        rewards = { {item = "porphyry", count = {1, 1}} },
        spawnOn = {"grassNormal", "porphyry"}
    },
    {
        img = lg.newImage(im.."rocks/dark_rock.png"), 
        maxHealth = 25, name = "Dark Rock", bestTool = "pickaxe", 
        rewards = { {item = "dark_stone", count = {2, 4}} },
        spawnOn = {"stone_dark"}
    },
    {
        img = lg.newImage(im.."rocks/pumice_rock.png"), 
        maxHealth = 25, name = "Pumice Rock", bestTool = "pickaxe", 
        rewards = { {item = "pumice", count = {2, 4}} },
        spawnOn = {"pumice", "granite"}
    },
    {
        img = lg.newImage(im.."ore_type/flint.png"), 
        maxHealth = 32, name = "Flint Ore", bestTool = "pickaxe",
        rewards = { {item = "stone", count = {2, 4}}, {item = "flint", count = {2, 3}} },
        spawnOn = {"stone", "grassNormal"}
    },
    {
        img = lg.newImage(im.."ore_type/amorphous.png"), 
        maxHealth = 34, name = "Amorphous Ore", bestTool = "pickaxe",
        spawnOn = {"stone", "stone_dark"}
    },
    {
        img = lg.newImage(im.."plants/dead_sapling.png"), 
        maxHealth = 5, name = "Dead Sapling", bestTool = "axe",
        rewards = { {item = "stick", count = {2, 5}}, {item = "oak", count = {0, 2}} },
        spawnOn = {"sandNormal", "sandGypsum"}
    },
    {
        img = lg.newImage(im.."ore_type/anthracite_coal.png"), 
        rewards = { {item = "anthracite_coal", count = {2, 6}} },
        maxHealth = 30, name = "Anthracite Ore", bestTool = "pickaxe",
        spawnOn = {"stone", "stone_dark"}
    },
    {
        img = lg.newImage(im.."ore_type/bituminous_coal.png"), 
        rewards = { {item = "bituminous_coal", count = {2, 6}} },
        maxHealth = 30, name = "Bituminous Ore", bestTool = "pickaxe",
        spawnOn = {"stone"}
    },
    {
        img = lg.newImage(im.."ore_type/lignite_coal.png"), 
        maxHealth = 30, name = "Lignite Ore", bestTool = "pickaxe", 
        rewards = { {item = "lignite_coal", count = {2, 6}} },
        spawnOn = {"stone", "dirt"}
    },
    {
        img = lg.newImage(im.."ore_type/ruby.png"), 
        maxHealth = 35, name = "Ruby Ore", bestTool = "pickaxe",
        rewards = { {item = "stone", count = {2, 4}}, {item = "ruby", count = {1, 3}} },
        spawnOn = {"granite", "stone"}
    },
    {
        name = "Cycad", bestTool = "axe", maxHealth = 15, isTall = true,
        rewards = { {item = "stick", count = {2, 5}}, {item = "cycad_leaf", count = {2, 4}} },
        spawnOn = {"grassNormal", "grassHot", "sandNormal"},
        imgBottom = lg.newImage(im.."plants/cycad/bottom.png"),
        imgMiddle = lg.newImage(im.."plants/cycad/middle.png"),
        imgTop = lg.newImage(im.."plants/cycad/top.png"),
    },
    {
        name = "Arundo", bestTool = "knife", maxHealth = 5, isTall = true,
        rewards = { {item = "leaf", count = {2, 4}} }, spawnOn = { "grassNormal" },
        imgBottom = lg.newImage(im.."plants/arundo/bottom.png"),
        imgMiddle = lg.newImage(im.."plants/arundo/middle.png"),
        imgTop = lg.newImage(im.."plants/arundo/top.png"),
    },
    {
        img = lg.newImage(im.."plants/tulpin.png"), 
        maxHealth = 2, name = "Tulpin", bestTool = "knife",
        spawnOn = {"grassNormal"}
    },
    {
        img = lg.newImage(im.."plants/porcini_mushroom.png"), 
        maxHealth = 2, name = "Porcini Mushroom", bestTool = "knife",
        spawnOn = {"grassNormal"}
    },
    {
        img = lg.newImage(im.."plants/lily_pad.png"),
        maxHealth = 3, weight = 2, name = "Lily Pad", bestTool = "knife",
        spawnOn = {"waterSmall", "waterMedium", "waterDeep"},
        surface = true, isWaterSurface = true, scale = {0.8, 1.1}, radius = 0.7,
        surfaceOffset = 0.08, bobAmount = 0.03,
    },
}

local cactusIndex = 9
local cactusDamageCool = 1
local damageCactusOnContact

for _, t in ipairs(propTypes) do
    if t.isTall then
        t.w = max(t.imgBottom:getWidth(), t.imgMiddle:getWidth(), t.imgTop:getWidth())
        t.h = t.imgBottom:getHeight() + t.imgMiddle:getHeight() + t.imgTop:getHeight()
    else
        t.w, t.h = t.img:getDimensions()
    end
    local lookup = {}
    for _, name in ipairs(t.spawnOn) do lookup[name] = true end
    t.spawnOnSet = lookup
end
local appleSeedTiles = {grassNormal = true, grassHot = true, grassCold = true, dirt = true, farmland = true}

local CHUNK_SIZE = 5
local CHUNK_RADIUS_SQ = 4 * 4

local function makeSurfaceMesh()
    return lg.newMesh({
        {"VertexPosition", "float", 2},
        {"VertexTexCoord", "float", 2},
        {"VertexColor", "float", 4},
    }, 4, "fan", "dynamic")
end

local function drawSurProp(prop, img)
    if not img then return end

    local scale = prop.scale or 1
    local halfW = 0.38 * scale
    local halfD = 0.28 * scale
    local topY = prop.y + (prop.surfaceOffset or 0.08)
    local bottomY = topY - 0.03

    local px, pz = prop.x, prop.z
    local x1, y1 = camera:project3D(px - halfW, bottomY, pz - halfD)
    if not x1 then return end
    local x2, y2 = camera:project3D(px + halfW, bottomY, pz - halfD)
    if not x2 then return end
    local x3, y3 = camera:project3D(px + halfW, topY, pz + halfD)
    if not x3 then return end
    local x4, y4 = camera:project3D(px - halfW, topY, pz + halfD)
    if not x4 then return end

    local textureMul = nightCycle.getTextureMultiplier() or {1, 1, 1}
    local r, g, b = textureMul[1], textureMul[2], textureMul[3]

    prop.mesh = prop.mesh or makeSurfaceMesh()
    local vertices = prop.surfaceVertices
    if not vertices then
        vertices = {
            {0, 0, 0, 0, 1, 1, 1, 1},
            {0, 0, 1, 0, 1, 1, 1, 1},
            {0, 0, 1, 1, 1, 1, 1, 1},
            {0, 0, 0, 1, 1, 1, 1, 1},
        }
        prop.surfaceVertices = vertices
    end
    vertices[1][1], vertices[1][2] = x1, y1
    vertices[2][1], vertices[2][2] = x2, y2
    vertices[3][1], vertices[3][2] = x3, y3
    vertices[4][1], vertices[4][2] = x4, y4
    for i = 1, 4 do
        vertices[i][5], vertices[i][6], vertices[i][7] = r, g, b
    end
    prop.mesh:setVertices(vertices)
    prop.mesh:setTexture(img)
    lg.setColor(r, g, b, 1)
    lg.draw(prop.mesh)
    lg.setColor(1, 1, 1, 1)
end

local MIN_CLUSTER_DISTANCE = 1.5
local MAX_CLUSTER_DISTANCE = 4.5
local MIN_PROP_DIST_SQ = 1.25 * 1.25

local function spawnProps(num, mapWidth, mapDepth, getTileAt)
    local spawned, attempts = 0, 0
    local maxAttempts = num * 100
    local totalWeight = 0
    for _, t in ipairs(propTypes) do
        totalWeight = totalWeight + (t.weight or 10)
    end
    local grid = {}
    local function gridInsert(x, z)
        local gx, gz = floor(x / 2), floor(z / 2)
        grid[gx] = grid[gx] or {}
        grid[gx][gz] = grid[gx][gz] or {}
        table.insert(grid[gx][gz], {x = x, z = z})
    end
    
    local function isTooCloseFast(x, z)
        local gx, gz = floor(x / 2), floor(z / 2)
        for dx = -1, 1 do
            local col = grid[gx + dx]
            if col then
                for dz = -1, 1 do
                    local cell = col[gz + dz]
                    if cell then
                        for i = 1, #cell do
                            local p = cell[i]
                            local rx, rz = p.x - x, p.z - z
                            if rx * rx + rz * rz < MIN_PROP_DIST_SQ then return true end
                        end
                    end
                end
            end
        end
        return false
    end

    while spawned < num and attempts < maxAttempts do
        attempts = attempts + 1

        local x = random() * (mapWidth - 1)
        local z = random() * (mapDepth - 1)

        local tile = getTileAt(x, z)
        if not tile or not tile.textureName then goto continue end
        
        local roll = random() * totalWeight
        local currentSum = 0
        local idx = 1
        local t = propTypes[1]

        for i, prop in ipairs(propTypes) do
            currentSum = currentSum + (prop.weight or 10)
            if roll <= currentSum then
                idx = i
                t = prop
                break
            end
        end

        if not t.spawnOnSet[tile.textureName] then goto continue end
        local clusterSize = (random() < 0.5) and random(3, 8) or 1

        for i = 1, clusterSize do
            if spawned >= num then break end
            local px, pz

            if i == 1 then
                px, pz = x, z
            else
                local angle = random() * pi * 2
                local dist = MIN_CLUSTER_DISTANCE + random() * (MAX_CLUSTER_DISTANCE - MIN_CLUSTER_DISTANCE)
                px = x + cos(angle) * dist
                pz = z + sin(angle) * dist
            end

            if px >= 0 and pz >= 0 and px < mapWidth and pz < mapDepth then
                local ptile = getTileAt(px, pz)

                if ptile and ptile.textureName and t.spawnOnSet[ptile.textureName] and not isTooCloseFast(px, pz) then
                    local propScale = 1
                    if t.scale then
                        propScale = t.scale[1] + random() * (t.scale[2] - t.scale[1])
                    end

                    local baseY = ptile.height + (t.isWaterSurface and 0.04 or 0)
                    props[#props + 1] = {
                        id = nextPropId,
                        typeIndex = idx,
                        x = px, z = pz, y = baseY, baseY = baseY,
                        health = t.maxHealth, maxHealth = t.maxHealth,
                        shakeTimer = 0, shakeOffsetX = 0, shakeOffsetY = 0,
                        length = t.isTall and random(5, 15) or nil,
                        scale = propScale,
                        bobTimer = random() * pi * 2,
                        bobAmount = t.bobAmount or 0,
                        radius = t.radius or 0.75,
                        surfaceOffset = t.surfaceOffset or 0,
                        isWaterSurface = t.isWaterSurface,
                    }
                    nextPropId = nextPropId + 1
                    gridInsert(px, pz)
                    spawned = spawned + 1
                end
            end
        end
        ::continue::
    end
end

local function plantAppleSeed(tile, x, z)
    if not tile or not tile.textureName or not appleSeedTiles[tile.textureName] then return false end

    local key = utils.tileKey(x, z)
    if occupiedTiles[key] then return false end
    occupiedTiles[key] = true

    props[#props + 1] = {
        id = nextPropId, type = "growingTree", stage = 1, growTimer = treeStages[1].growTime,
        x = floor(x) + 0.5, z = floor(z) + 0.5, y = tile.height,
        img = treeStages[1].img
    }
    nextPropId = nextPropId + 1
    return true
end

local function clearProps()
    for i = #props, 1, -1 do props[i] = nil end
    occupiedTiles = {}
    nextPropId = 1
end

local function loadSavedProps(savedProps)
    clearProps()
    if type(savedProps) ~= "table" then return end

    for i = 1, #savedProps do
        local p = savedProps[i]
        if p.type == "growingTree" then
            local stage = p.stage or 1
            local prop = {
                id = p.id or nextPropId, type = "growingTree", stage = stage,
                growTimer = p.growTimer or (treeStages[stage] and treeStages[stage].growTime or 0),
                x = p.x, y = p.y, z = p.z,
                img = treeStages[stage] and treeStages[stage].img,
                scale = p.scale or 1,
            }
            nextPropId = max(nextPropId, prop.id + 1)
            props[#props + 1] = prop
            if prop.x and prop.z then occupiedTiles[utils.tileKey(prop.x, prop.z)] = true end
        else
            local prop = {
                id = p.id or nextPropId,
                typeIndex = p.typeIndex, x = p.x, y = p.y, z = p.z,
                health = p.health, maxHealth = p.maxHealth,
                shakeTimer = p.shakeTimer or 0, shakeOffsetX = p.shakeOffsetX or 0, shakeOffsetY = p.shakeOffsetY or 0,
                length = p.length, isCut = p.isCut, scale = p.scale or 1, baseY = p.baseY or p.y,
                bobTimer = p.bobTimer or 0, bobAmount = p.bobAmount or 0, radius = p.radius or 0.75,
                surfaceOffset = p.surfaceOffset or 0, isWaterSurface = p.isWaterSurface,
            }
            nextPropId = max(nextPropId, prop.id + 1)
            local t = propTypes[prop.typeIndex]
            if t then prop.img = (t.isTree and prop.isCut) and treeCutImg or t.img end
            props[#props + 1] = prop
            if prop.x and prop.z then occupiedTiles[utils.tileKey(prop.x, prop.z)] = true end
        end
    end
end

local function updateProps(dt)
    for i = #props, 1, -1 do
        local p = props[i]
        if p.isWaterSurface then
            p.bobTimer = (p.bobTimer or 0) + dt * 1.4
            p.y = (p.baseY or p.y) + sin(p.bobTimer) * (p.bobAmount or 0.03)
        elseif p.type == "growingTree" then
            p.growTimer = p.growTimer - dt
            if p.growTimer <= 0 then
                local nextStage = p.stage + 1
                local stageData = treeStages[nextStage]
                if stageData then
                    p.stage = nextStage
                    p.img = stageData.img
                    p.growTimer = stageData.growTime
                else
                    local treeType = propTypes[1]
                    props[i] = {
                        typeIndex = 1, x = p.x, z = p.z, y = p.y,
                        health = treeType.maxHealth, maxHealth = treeType.maxHealth,
                        shakeTimer = 0, shakeOffsetX = 0, shakeOffsetY = 0,
                    }
                end
            end
        end
    end
    for i = #shakingProps, 1, -1 do
        local prop = shakingProps[i]
        local timer = prop.shakeTimer - dt
        prop.shakeTimer = timer

        if timer <= 0 then
            prop.shakeOffsetX, prop.shakeOffsetY = 0, 0
            table.remove(shakingProps, i)
        else
            local intensity = 6
            prop.shakeOffsetX = (random() - 0.5) * intensity
            prop.shakeOffsetY = (random() - 0.5) * intensity
        end
    end
end

local MAX_RENDER_DIST_SQ = 35 * 35

local function drawProps(propList, drawWithStencil)
    local cx, cz = countryball.x, countryball.z
    local pixelToWorldY = 0.0075
    local camChunkX = floor(camera.x / CHUNK_SIZE)
    local camChunkZ = floor(camera.z / CHUNK_SIZE)

    for i = 1, #propList do
        local prop = propList[i]
        local dx, dz = prop.x - cx, prop.z - cz
        local distSq = dx * dx + dz * dz
        local propChunkX = floor(prop.x / CHUNK_SIZE)
        local propChunkZ = floor(prop.z / CHUNK_SIZE)

        if distSq <= MAX_RENDER_DIST_SQ and
            (propChunkX - camChunkX) ^ 2 + (propChunkZ - camChunkZ) ^ 2 <= CHUNK_RADIUS_SQ then
            local t = propTypes[prop.typeIndex]
            local totalPixelHeight = t and t.h or 0
            local pScale = prop.scale or 1

            if prop.type == "growingTree" then
                drawWithStencil(prop.x, prop.y - 0.04, prop.z, prop.img, false, pScale, pScale)
            elseif t and t.surface then
                drawSurProp(prop, prop.img or t.img)
            elseif t then
                if t.isTall then
                    drawWithStencil(prop.x, prop.y - 0.04, prop.z, t.imgBottom, false, pScale, pScale)
                    local currentYOffset = 0.04
                    local bottomH = t.imgBottom:getHeight()
                    local middleH = t.imgMiddle:getHeight()
                    local topH = t.imgTop:getHeight()

                    totalPixelHeight = bottomH + (middleH * prop.length) + topH
                    for layer = 1, prop.length do
                        local yShift = (bottomH + (layer - 1) * middleH) * pixelToWorldY
                        drawWithStencil(prop.x, prop.y - currentYOffset + yShift, prop.z, t.imgMiddle, false, pScale, pScale)
                    end
                    local topShift = (bottomH + prop.length * middleH) * pixelToWorldY
                    drawWithStencil(prop.x, prop.y - currentYOffset + topShift, prop.z, t.imgTop, false, pScale, pScale)
                else
                    drawWithStencil(prop.x, prop.y - 0.04, prop.z, prop.img or t.img, false, pScale, pScale)
                end
            end
            
            if distSq < 9 then
                local pScale = prop.scale or 1
                local topY
                if t and t.isTall then
                    local bottomH = t.imgBottom:getHeight()
                    local middleH = t.imgMiddle:getHeight()
                    local topH = t.imgTop:getHeight()
                    local totalHeight = bottomH + (middleH * (prop.length or 0)) + topH
                    topY = prop.y + totalHeight * pixelToWorldY * pScale
                elseif t then
                    topY = prop.y + (t.h or 0) * pixelToWorldY * pScale
                end

                if topY and prop.type ~= "growingTree" then
                    local sx, sy, z = camera:project3D(prop.x, topY, prop.z)
                    if sx and sy and z > 0 then
                        local barScale = (1 / z) * 6
                        local barW = 40 * barScale
                        local barH = 6 * barScale
                        local healthRatio = (prop.health / (prop.maxHealth or t.maxHealth)) or 1
                        local shakeX = (prop.shakeOffsetX or 0) * barScale
                        local shakeY = (prop.shakeOffsetY or 0) * barScale

                        local bx = sx - barW * 0.5 + shakeX
                        local by = sy - 4 * barScale + shakeY
                        lg.setColor(0, 0, 0, 1)
                        lg.rectangle("fill", bx, by, barW, barH)
                        lg.setColor(1 - healthRatio, healthRatio, 0)
                        lg.rectangle("fill", bx + barScale, by + barScale, (barW - 2 * barScale) * healthRatio, barH - 2 * barScale)
                        lg.setColor(1, 1, 1, 1)
                    end
                end
            end
        end
    end
    lg.setColor(1, 1, 1)
end

local function handleMousePressed(mx, my)
    local cx, cz = countryball.x, countryball.z
    local selected = Inventory:getSelected()

    for i = #props, 1, -1 do
        local prop = props[i]
        if prop.typeIndex then
            local dx, dz = prop.x - cx, prop.z - cz

            if dx * dx + dz * dz < 9 then
                local sx, sy, z = camera:project3D(prop.x, prop.y, prop.z)
                if sx and z > 0 then
                    local t = propTypes[prop.typeIndex]
                    if t then
                        local propHeight = t.h
                        if t.isTall and prop.length then
                            propHeight = t.imgBottom:getHeight() + (t.imgMiddle:getHeight() * prop.length) + t.imgTop:getHeight()
                        end
                        local objectScale = prop.scale or 1
                        local scale = (1 / z) * 6 * objectScale
                        local w = (t.w or 1) * scale
                        local h = propHeight * scale

                        if mx >= sx - w / 2 and mx <= sx + w / 2 and my >= sy - h and my <= sy then
                            if prop.typeIndex == cactusIndex and not selected then
                                damageCactusOnContact(countryball, prop, 0)
                            end
                            local multiplier = selected and ItemsModule.getToolMultiplier(selected.type, t.bestTool) or 1
                            prop.health = prop.health - multiplier

                            local debrisImg = prop.img or t.img or t.imgBottom
                            Particles.spawnBurst(debrisImg, prop.x, prop.y + 0.5, prop.z, 3, hitParticleOpts)

                            if prop.shakeTimer <= 0 then
                                prop.shakeTimer = 0.07
                                shakingProps[#shakingProps + 1] = prop
                            end
                            if t.isTree then
                                if random() < 0.5 then ItemsModule.dropItem(prop.x, prop.y + 0.75, prop.z, "stick") end
                                if random() < 0.1 then ItemsModule.dropItem(prop.x, prop.y + 0.75, prop.z, "apple") end
                                if random() < 0.1 then ItemsModule.dropItem(prop.x, prop.y + 0.75, prop.z, "green_apple") end
                            end
                            local wasRemoved = false
                            if prop.health <= 0 then
                                if t.isTree and not prop.img then
                                    prop.img = treeCutImg
                                    prop.health = 5
                                    prop.maxHealth = 5
                                else
                                    if t.rewards then
                                        for r = 1, #t.rewards do
                                            local rewardData = t.rewards[r]
                                            local amt = random(rewardData.count[1], rewardData.count[2])
                                            for j = 1, amt do
                                                ItemsModule.dropItem(prop.x + (random() - 0.5) * 0.5, prop.y + 0.8,
                                                    prop.z + (random() - 0.5) * 0.5, rewardData.item)
                                            end
                                        end
                                    end
                                    Particles.spawnBurst(debrisImg, prop.x, prop.y + 0.5, prop.z, 10, destroyParticleOpts)

                                    table.remove(props, i)
                                    wasRemoved = true
                                end
                            end

                            if prop.id and MultiplayerMenu and MultiplayerMenu.isActive and MultiplayerMenu:isActive() then
                                if wasRemoved then
                                    MultiplayerMenu:send({sys = "prop_remove", id = prop.id})
                                else
                                    MultiplayerMenu:send({
                                        sys = "prop_hit", id = prop.id,
                                        health = prop.health,
                                        cut = (prop.img == treeCutImg) and 1 or 0,
                                    })
                                end
                            end
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

function damageCactusOnContact(entity, cactus, dt)
    if not entity or not cactus or cactus.typeIndex ~= cactusIndex then return false end

    entity.cactusDamageCooldown = math.max(0, (entity.cactusDamageCooldown or 0) - (dt or 0))
    if entity.cactusDamageCooldown > 0 then return false end

    local entityHalfWidth = (entity.w or 1) * 0.5
    local entityHalfDepth = (entity.d or 1) * 0.5
    local cactusRadius = cactus.radius or 0.75
    local dx, dz = entity.x - cactus.x, entity.z - cactus.z
    local horizontalRange = cactusRadius + math.max(entityHalfWidth, entityHalfDepth)
    if dx * dx + dz * dz > horizontalRange * horizontalRange then return false end

    local cactusHeight = math.max(1, (propTypes[cactusIndex].h or 0) * 0.0075)
    local entityBottom, entityTop = entity.y or 0, (entity.y or 0) + (entity.h or 1)
    if entityTop <= cactus.y or entityBottom >= cactus.y + cactusHeight then return false end

    local directionLength = math.sqrt(dx * dx + dz * dz)
    local directionX, directionZ = 1, 0
    if directionLength > 0 then
        directionX, directionZ = dx / directionLength, dz / directionLength
    end
    entity:takeDamage(1, directionX, directionZ)
    entity.cactusDamageCooldown = cactusDamageCool
    return true
end

local function updateCactusContact(entity, dt)
    if not entity then return false end
    entity.cactusDamageCooldown = math.max(0, (entity.cactusDamageCooldown or 0) - (dt or 0))
    for i = 1, #props do
        if damageCactusOnContact(entity, props[i], 0) then return true end
    end
    return false
end

local function findPropById(id)
    for i = 1, #props do
        if props[i].id == id then return props[i], i end
    end
    return nil
end

local function applyNetworkHit(id, health, cut)
    local prop = findPropById(id)
    if not prop then return end
    prop.health = health
    if cut then prop.img = treeCutImg end
    if prop.shakeTimer <= 0 then
        prop.shakeTimer = 0.07
        shakingProps[#shakingProps + 1] = prop
    end

    local t = propTypes[prop.typeIndex]
    local debrisImg = prop.img or (t and (t.img or t.imgBottom))
    Particles.spawnBurst(debrisImg, prop.x, prop.y + 0.5, prop.z, 3, hitParticleOpts)
end

local function applyNetworkRemove(id)
    local prop, i = findPropById(id)
    if not prop then return end

    local t = propTypes[prop.typeIndex]
    local debrisImg = prop.img or (t and (t.img or t.imgBottom))
    Particles.spawnBurst(debrisImg, prop.x, prop.y + 0.5, prop.z, 10, destroyParticleOpts)

    table.remove(props, i)
end

return {
    spawnProps = spawnProps,
    updateProps = updateProps,
    drawProps = drawProps,
    handleMousePressed = handleMousePressed,
    updateCactusContact = updateCactusContact,
    plantAppleSeed = plantAppleSeed,
    loadSavedProps = loadSavedProps,
    clearProps = clearProps,
    applyNetworkHit = applyNetworkHit,
    applyNetworkRemove = applyNetworkRemove,
    props = props
}