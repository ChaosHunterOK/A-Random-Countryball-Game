local love = require "love"
local lg = love.graphics
local sqrt, max, random, floor = math.sqrt, math.max, math.random, math.floor

local camera = require("source.projectile.camera")
local countryball = require("source.countryball")
local ItemsModule = require("source.items")
local utils = require("source.utils")
local Inventory = require("source.hud.inv")

local props = {}
local shakingProps = {}
local treeCutImg = lg.newImage("image/tree_cut.png")
local occupiedTiles = {}

local im = "image/"
local treeStages = {
    {
        name = "planted",
        img = lg.newImage(im.."tree/planted.png"),
        growTime = 20
    },
    {
        name = "sprout",
        img = lg.newImage(im.."tree/sprout.png"),
        growTime = 30
    },
    {
        name = "sapling",
        img = lg.newImage(im.."tree/sapling.png"),
        growTime = 40
    }
}

local propTypes = {
    {
        img = lg.newImage(im.."tree.png"), 
        maxHealth = 10, 
        name = "Tree", 
        bestTool = "axe", 
        rewards = {
            {item = "oak", count = {3, 7}}
        },
        isTree = true,
        spawnOn = {"grassNormal", "grassCold"},
        scale = {1.5, 1.6},
    },
    {
        img = lg.newImage(im.."plants/acacia.png"), 
        maxHealth = 10, 
        name = "Acacia Tree", 
        bestTool = "axe", 
        rewards = {
            {item = "oak", count = {3, 7}}
        },
        isTree = true,
        spawnOn = {"grassHot"},
        scale = {1.7, 1.8},
    },
    {
        img = lg.newImage(im.."rock.png"), 
        maxHealth = 25, 
        name = "Rock", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "stone", count = {2, 4}}
        },
        spawnOn = {"stone", "granite", "grassNormal"}
    },
    {
        img = lg.newImage(im.."mini_rock.png"), 
        maxHealth = 5, 
        name = "Mini Rock", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "stone", count = {1, 1}}
        },
        spawnOn = {"grassCold", "grassHot", "grassNormal"}
    },
    {
        img = lg.newImage(im.."ore_type/iron.png"),
        maxHealth = 32, 
        name = "Iron Ore", 
        bestTool = "pickaxe",
        rewards = {
            {item = "stone", count = {2, 4}},
            {item = "iron_raw", count = {1, 3}}
        },
        spawnOn = {"stone", "stone_dark", "granite"}
    },
    {
        img = lg.newImage(im.."bush.png"), 
        maxHealth = 2, 
        name = "Bush", 
        bestTool = "knife", 
        rewards = {
            {item = "leaf", count = {3, 6}}
        },
        spawnOn = {"grassNormal"}
    },
    {
        img = lg.newImage(im.."bush_hot.png"), 
        maxHealth = 2, 
        name = "Hot Bush", 
        bestTool = "knife", 
        rewards = {
            {item = "leaf", count = {3, 6}}
        },
        spawnOn = {"grassHot", "sandNormal", "sandGypsum"}
    },
    {
        img = lg.newImage(im.."bush_cold.png"), 
        maxHealth = 2, 
        name = "Bush Cold", 
        bestTool = "knife", 
        rewards = {
            {item = "leaf", count = {3, 6}}
        },
        spawnOn = {"grassCold"}
    },
    {
        img = lg.newImage(im.."porphyry_rock.png"), 
        maxHealth = 25, 
        name = "Porphyry Rock", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "porphyry", count = {2, 4}}
        },
        spawnOn = {"stone", "porphyry"}
    },
    {
        img = lg.newImage(im.."dark_rock.png"), 
        maxHealth = 25, 
        name = "Dark Rock", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "dark_stone", count = {2, 4}}
        },
        spawnOn = {"stone_dark"}
    },
    {
        img = lg.newImage(im.."pumice_rock.png"), 
        maxHealth = 25, 
        name = "Pumice Rock", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "pumice", count = {2, 4}}
        },
        spawnOn = {"pumice", "granite"}
    },
    {
        img = lg.newImage(im.."ore_type/flint.png"), 
        maxHealth = 32, 
        name = "Flint Ore", 
        bestTool = "pickaxe",
        rewards = {
            {item = "stone", count = {2, 4}},
            {item = "flint", count = {2, 3}}
        },
        spawnOn = {"stone", "grassNormal"}
    },
    {
        img = lg.newImage(im.."ore_type/amorphous.png"), 
        maxHealth = 34, 
        name = "Amorphous Ore", 
        bestTool = "pickaxe",
        spawnOn = {"stone", "stone_dark"}
    },
    {
        img = lg.newImage(im.."dead_sapling.png"), 
        maxHealth = 5, 
        name = "Dead Sapling", 
        bestTool = "axe",
        rewards = {
            {item = "stick", count = {2, 10}},
            {item = "oak", count = {0, 2}}
        },
        spawnOn = {"sandNormal", "sandGypsum"}
    },
    {
        img = lg.newImage(im.."ore_type/anthracite_coal.png"), 
        maxHealth = 30,
        name = "Anthracite Ore", 
        bestTool = "pickaxe",
        spawnOn = {"stone", "stone_dark"}
    },
    {
        img = lg.newImage(im.."ore_type/bituminous_coal.png"), 
        maxHealth = 30, 
        name = "Bituminous Ore", 
        bestTool = "pickaxe",
        spawnOn = {"stone"}
    },
    {
        img = lg.newImage(im.."ore_type/lignite_coal.png"), 
        maxHealth = 30, 
        name = "Lignite Ore", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "lignite_coal", count = {2, 6}}
        },
        spawnOn = {"stone", "dirt"}
    },
    {
        img = lg.newImage(im.."ore_type/ruby.png"), 
        maxHealth = 35, 
        name = "Ruby Ore", 
        bestTool = "pickaxe",
        rewards = {
            {item = "stone", count = {2, 4}},
            {item = "ruby", count = {1, 3}}
        },
        spawnOn = {"granite", "stone"}
    },
    {
        name = "Cycad",
        bestTool = "axe",
        maxHealth = 15,
        isTall = true,
        rewards = {
            {item = "stick", count = {2, 5}},
            {item = "leaf",  count = {2, 4}}
        },
        spawnOn = {"grassNormal", "grassHot", "sandNormal"},
        imgBottom = lg.newImage(im.."plants/cycad/bottom.png"),
        imgMiddle = lg.newImage(im.."plants/cycad/middle.png"),
        imgTop = lg.newImage(im.."plants/cycad/top.png"),
    },
    {
        name = "Arundo",
        bestTool = "knife",
        maxHealth = 5,
        isTall = true,
        rewards = {
            {item = "leaf", count = {2, 4}}
        },
        spawnOn = { "grassNormal" },
        imgBottom = lg.newImage(im.."plants/arundo/bottom.png"),
        imgMiddle = lg.newImage(im.."plants/arundo/middle.png"),
        imgTop = lg.newImage(im.."plants/arundo/top.png"),
    },
    {
        img = lg.newImage(im.."plants/tulpin.png"), 
        maxHealth = 2, 
        name = "Tulpin", 
        bestTool = "knife", 
        spawnOn = {"grassNormal"}
    },
}

for _, t in ipairs(propTypes) do
    if t.isTall then
        t.w = max(t.imgBottom:getWidth(), t.imgMiddle:getWidth(), t.imgTop:getWidth())
        t.h = t.imgBottom:getHeight() + t.imgMiddle:getHeight() + t.imgTop:getHeight()
    else
        t.w, t.h = t.img:getDimensions()
    end
end

local function tableContains(t, val)
    if not t then return false end
    for _, v in ipairs(t) do
        if v == val then return true end
    end
    return false
end

local MIN_CLUSTER_DISTANCE = 1.5
local MAX_CLUSTER_DISTANCE = 4.5
local MIN_PROP_DISTANCE = 1.25

local function isTooClose(x, z)
    for _, p in ipairs(props) do
        local dx = p.x - x
        local dz = p.z - z
        if dx * dx + dz * dz < MIN_PROP_DISTANCE * MIN_PROP_DISTANCE then
            return true
        end
    end
    return false
end

local function spawnProps(num, mapWidth, mapDepth, getTileAt)
    local spawned, attempts = 0, 0
    local maxAttempts = num * 100

    while spawned < num and attempts < maxAttempts do
        attempts = attempts + 1

        local x = random() * (mapWidth - 1)
        local z = random() * (mapDepth - 1)

        local tile = getTileAt(x, z)
        if not tile or not tile.textureName then
            goto continue
        end

        local idx = random(#propTypes)
        local t = propTypes[idx]

        if not tableContains(t.spawnOn, tile.textureName) then
            goto continue
        end
        local clusterSize = (random() < 0.5) and random(3, 8) or 1

        for i = 1, clusterSize do
            if spawned >= num then break end

            local px, pz

            if i == 1 then
                px, pz = x, z
            else
                local angle = random() * math.pi * 2
                local dist = MIN_CLUSTER_DISTANCE + random() * (MAX_CLUSTER_DISTANCE - MIN_CLUSTER_DISTANCE)

                px = x + math.cos(angle) * dist
                pz = z + math.sin(angle) * dist
            end

            if px >= 0 and pz >= 0 and px < mapWidth and pz < mapDepth then
                local ptile = getTileAt(px, pz)

                if ptile
                and ptile.textureName
                and tableContains(t.spawnOn, ptile.textureName)
                and not isTooClose(px, pz) then
                    local propScale = 1
                    if t.scale then
                        propScale = t.scale[1] + random() * (t.scale[2] - t.scale[1])
                    end

                    props[#props + 1] = {
                        typeIndex = idx,
                        x = px,
                        z = pz,
                        y = ptile.height,
                        health = t.maxHealth,
                        maxHealth = t.maxHealth,
                        shakeTimer = 0,
                        shakeOffsetX = 0,
                        shakeOffsetY = 0,
                        length = t.isTall and random(5,15) or nil,
                        scale = propScale
                    }

                    spawned = spawned + 1
                end
            end
        end

        ::continue::
    end
end

local function plantAppleSeed(tile, x, z)
    if not tile or not tile.textureName then return false end

    if not tableContains(
            { "grassNormal", "grassHot", "grassCold", "dirt", "farmland" },
            tile.textureName
        ) then
        return false
    end

    local key = utils.tileKey(x, z)
    if occupiedTiles[key] then return false end

    occupiedTiles[key] = true

    props[#props + 1] = {
        type = "growingTree",
        stage = 1,
        growTimer = treeStages[1].growTime,
        x = floor(x) + 0.5,
        z = floor(z) + 0.5,
        y = tile.height,
        img = treeStages[1].img
    }

    return true
end

local function clearProps()
    for i = #props, 1, -1 do
        props[i] = nil
    end
    occupiedTiles = {}
end

local function loadSavedProps(savedProps)
    clearProps()
    if type(savedProps) ~= "table" then
        return
    end

    for _, p in ipairs(savedProps) do
        if p.type == "growingTree" then
            local stage = p.stage or 1
            local prop = {
                type = "growingTree",
                stage = stage,
                growTimer = p.growTimer or (treeStages[stage] and treeStages[stage].growTime or 0),
                x = p.x,
                y = p.y,
                z = p.z,
                img = treeStages[stage] and treeStages[stage].img,
                scale = p.scale or 1,
            }
            props[#props + 1] = prop
            if prop.x and prop.z then
                occupiedTiles[utils.tileKey(prop.x, prop.z)] = true
            end
        else
            local prop = {
                typeIndex = p.typeIndex,
                x = p.x,
                y = p.y,
                z = p.z,
                health = p.health,
                maxHealth = p.maxHealth,
                shakeTimer = p.shakeTimer or 0,
                shakeOffsetX = p.shakeOffsetX or 0,
                shakeOffsetY = p.shakeOffsetY or 0,
                length = p.length,
                isCut = p.isCut,
                scale = p.scale or 1,
            }
            local t = propTypes[prop.typeIndex]
            if t then
                if t.isTree and prop.isCut then
                    prop.img = treeCutImg
                else
                    prop.img = t.img
                end
            end
            props[#props + 1] = prop
            if prop.x and prop.z then
                occupiedTiles[utils.tileKey(prop.x, prop.z)] = true
            end
        end
    end
end

local function updateProps(dt)
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

    for i = #props, 1, -1 do
        local p = props[i]

        if p.type == "growingTree" then
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
                        typeIndex = 1,
                        x = p.x,
                        z = p.z,
                        y = p.y,
                        health = treeType.maxHealth,
                        maxHealth = treeType.maxHealth,
                        shakeTimer = 0,
                        shakeOffsetX = 0,
                        shakeOffsetY = 0,
                    }
                end
            end
        end
    end
end

local function drawProps(propList, drawWithStencil)
    local cx, cz = countryball.x, countryball.z

    for i = 1, #propList do
        local prop = propList[i]
        local t = propTypes[prop.typeIndex]

        local totalPixelHeight = t and t.h or 0

        if prop.type == "growingTree" then
            drawWithStencil(prop.x, prop.y - 0.04, prop.z, prop.img, false, prop.scale or 1, prop.scale or 1)
        elseif t then
            if t.isTall then
                drawWithStencil(prop.x, prop.y - 0.04, prop.z, t.imgBottom, false, prop.scale or 1, prop.scale or 1)
                local currentYOffset = 0.04
                local bottomH = t.imgBottom:getHeight()
                local middleH = t.imgMiddle:getHeight()
                local topH = t.imgTop:getHeight()

                totalPixelHeight = bottomH + (middleH * prop.length) + topH
                local pixelToWorldY = 0.0075
                for layer = 1, prop.length do
                    local yShift = (bottomH + (layer - 1) * middleH) * pixelToWorldY
                    drawWithStencil(prop.x, prop.y - currentYOffset + yShift, prop.z, t.imgMiddle, false, prop.scale or 1, prop.scale or 1)
                end
                local topShift = (bottomH + prop.length * middleH) * pixelToWorldY
                drawWithStencil(prop.x, prop.y - currentYOffset + topShift, prop.z, t.imgTop, false, prop.scale or 1, prop.scale or 1)
            else
                local img = prop.img or t.img
                drawWithStencil(prop.x, prop.y - 0.04, prop.z, img, false, prop.scale or 1, prop.scale or 1)
            end
        end
        local dx, dz = prop.x - cx, prop.z - cz
        if dx * dx + dz * dz < 9 then
            local sx, sy, z = camera:project3D(prop.x, prop.y, prop.z)
            if sx and z > 0 and t then
                local scale = (1 / z) * 6
                local barW = 40 * scale
                local barH = 6 * scale
                local healthRatio = prop.health / (prop.maxHealth or t.maxHealth)

                local bx = sx - barW / 2 + (prop.shakeOffsetX * scale)
                local by = sy - (totalPixelHeight * scale + 4) + (prop.shakeOffsetY * scale)
                lg.setColor(0, 0, 0)
                lg.rectangle("fill", bx, by, barW, barH)
                lg.setColor(1 - healthRatio, healthRatio, 0)
                lg.rectangle("fill", bx + scale, by + scale, (barW - 2 * scale) * healthRatio, barH - 2 * scale)
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
        if not prop.typeIndex then
            goto continue
        end
        local dx, dz = prop.x - cx, prop.z - cz

        if dx * dx + dz * dz < 9 then
            local sx, sy, z = camera:project3D(prop.x, prop.y, prop.z)
            if sx and z > 0 then
                local t = propTypes[prop.typeIndex]
                if not t then
                    goto continue
                end
                local scale = (1 / z) * 6 * (prop.scale or 1)
                local propHeight = t.h
                if t.isTall and prop.length then
                    propHeight = t.imgBottom:getHeight() + (t.imgMiddle:getHeight() * prop.length) + t.imgTop:getHeight()
                end
                local objectScale = prop.scale or 1
                local w = (t.w or 1) * scale * objectScale
                local h = propHeight * scale * objectScale

                if mx >= sx - w / 2 and mx <= sx + w / 2 and my >= sy - h and my <= sy and t then
                    local multiplier = selected and ItemsModule.getToolMultiplier(selected.type, t.bestTool) or 1
                    prop.health = prop.health - multiplier
                    if prop.shakeTimer <= 0 then
                        prop.shakeTimer = 0.07
                        shakingProps[#shakingProps + 1] = prop
                    end
                    if t.isTree then
                        if random() < 0.5 then ItemsModule.dropItem(prop.x, prop.y + 0.75, prop.z, "stick") end
                        if random() < 0.1 then ItemsModule.dropItem(prop.x, prop.y + 0.75, prop.z, "apple") end
                        if random() < 0.1 then ItemsModule.dropItem(prop.x, prop.y + 0.75, prop.z, "green_apple") end
                    end
                    if prop.health <= 0 then
                        if t.isTree and not prop.img then
                            prop.img = treeCutImg
                            prop.health = 5
                            prop.maxHealth = 5
                        else
                            if t.rewards then
                                for _, rewardData in ipairs(t.rewards) do
                                    local itemName = rewardData.item
                                    local minAmt = rewardData.count[1]
                                    local maxAmt = rewardData.count[2]

                                    local amt = random(minAmt, maxAmt)
                                    for j = 1, amt do
                                        ItemsModule.dropItem(prop.x + (random() - 0.5) * 0.5, prop.y + 0.8,
                                            prop.z + (random() - 0.5) * 0.5, itemName)
                                    end
                                end
                            end
                            table.remove(props, i)
                        end
                    end
                    return true
                end
            end
        end
        ::continue::
    end
    return false
end

return {
    spawnProps = spawnProps,
    updateProps = updateProps,
    drawProps = drawProps,
    handleMousePressed = handleMousePressed,
    plantAppleSeed = plantAppleSeed,
    loadSavedProps = loadSavedProps,
    clearProps = clearProps,
    props = props
}
