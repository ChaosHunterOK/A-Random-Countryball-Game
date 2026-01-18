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

local treeStages = {
    {
        name = "planted",
        img = lg.newImage("image/tree/planted.png"),
        growTime = 20
    },
    {
        name = "sprout",
        img = lg.newImage("image/tree/sprout.png"),
        growTime = 30
    },
    {
        name = "sapling",
        img = lg.newImage("image/tree/sapling.png"),
        growTime = 40
    }
}

local propTypes = {
    {
        img = lg.newImage("image/tree.png"), 
        maxHealth = 10, 
        name = "Tree", 
        bestTool = "axe", 
        rewards = {
            {item = "oak", count = {3, 7}}
        },
        isTree = true,
        spawnOn = {"grassNormal", "grassHot", "grassCold"}
    },
    {
        img = lg.newImage("image/rock.png"), 
        maxHealth = 25, 
        name = "Rock", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "stone", count = {2, 4}}
        },
        spawnOn = {"stone", "granite", "grassNormal"}
    },
    {
        img = lg.newImage("image/ore_type/iron.png"),
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
        img = lg.newImage("image/bush.png"), 
        maxHealth = 2, 
        name = "Bush", 
        bestTool = "hoe", 
        rewards = {
            {item = "leaf", count = {3, 6}}
        },
        spawnOn = {"grassNormal", "grassHot", "grassCold"}
    },
    {
        img = lg.newImage("image/porphyry_rock.png"), 
        maxHealth = 25, 
        name = "Porphyry Rock", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "porphyry", count = {2, 4}}
        },
        spawnOn = {"stone", "porphyry"}
    },
    {
        img = lg.newImage("image/dark_rock.png"), 
        maxHealth = 25, 
        name = "Dark Rock", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "dark_stone", count = {2, 4}}
        },
        spawnOn = {"stone_dark"}
    },
    {
        img = lg.newImage("image/pumice_rock.png"), 
        maxHealth = 25, 
        name = "Pumice Rock", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "pumice", count = {2, 4}}
        },
        spawnOn = {"pumice", "granite"}
    },
    {
        img = lg.newImage("image/ore_type/flint.png"), 
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
        img = lg.newImage("image/ore_type/amorphous.png"), 
        maxHealth = 34, 
        name = "Amorphous Ore", 
        bestTool = "pickaxe",
        spawnOn = {"stone", "stone_dark"}
    },
    {
        img = lg.newImage("image/ore_type/anthracite_coal.png"), 
        maxHealth = 30,
        name = "Anthracite Ore", 
        bestTool = "pickaxe",
        spawnOn = {"stone", "stone_dark"}
    },
    {
        img = lg.newImage("image/ore_type/bituminous_coal.png"), 
        maxHealth = 30, 
        name = "Bituminous Ore", 
        bestTool = "pickaxe",
        spawnOn = {"stone"}
    },
    {
        img = lg.newImage("image/ore_type/lignite_coal.png"), 
        maxHealth = 30, 
        name = "Lignite Ore", 
        bestTool = "pickaxe", 
        rewards = {
            {item = "lignite_coal", count = {2, 6}}
        },
        spawnOn = {"stone", "dirt"}
    },
    {
        img = lg.newImage("image/ore_type/ruby.png"), 
        maxHealth = 35, 
        name = "Ruby Ore", 
        bestTool = "pickaxe",
        rewards = {
            {item = "stone", count = {2, 4}},
            {item = "ruby", count = {1, 3}}
        },
        spawnOn = {"granite", "stone"}
    },
}

for _, t in ipairs(propTypes) do
    t.w, t.h = t.img:getDimensions()
end

local function tableContains(t, val)
    if not t then return false end
    for _, v in ipairs(t) do
        if v == val then return true end
    end
    return false
end

local function spawnProps(num, mapWidth, mapDepth, getTileAt)
    local spawned = 0
    local attempts = 0
    local maxAttempts = num * 50

    while spawned < num and attempts < maxAttempts do
        attempts = attempts + 1
        
        local x = random() * (mapWidth - 1)
        local z = random() * (mapDepth - 1)
        local tile = getTileAt(x, z)
        
        if tile and tile.textureName then
            local idx = random(#propTypes)
            local t = propTypes[idx]
            if tableContains(t.spawnOn, tile.textureName) then
                props[#props+1] = {
                    typeIndex = idx,
                    x = x,
                    z = z,
                    y = tile.height,
                    health = t.maxHealth,
                    shakeTimer = 0,
                    shakeOffsetX = 0,
                    shakeOffsetY = 0,
                }
                spawned = spawned + 1
            end
        end
    end
end

local function plantAppleSeed(tile, x, z)
    if not tile or not tile.textureName then return false end

    if not tableContains(
        {"grassNormal", "grassHot", "grassCold", "dirt", "farmland"},
        tile.textureName
    ) then
        return false
    end

    local key = utils.tileKey(x, z)
    if occupiedTiles[key] then return false end

    occupiedTiles[key] = true

    props[#props+1] = {
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

local function updateProps(dt)
    for i = #shakingProps, 1, -1 do
        local prop = shakingProps[i]
        prop.shakeTimer = prop.shakeTimer - dt
        if prop.shakeTimer <= 0 then
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
                p.stage = p.stage + 1
                if treeStages[p.stage] then
                    p.img = treeStages[p.stage].img
                    p.growTimer = treeStages[p.stage].growTime
                else
                    props[i] = {
                        typeIndex = 1,
                        x = p.x,
                        z = p.z,
                        y = p.y,
                        health = propTypes[1].maxHealth,
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
        if prop.type == "growingTree" then
            drawWithStencil(prop.x, prop.y - 0.04, prop.z, prop.img, false)
        elseif t then
            local img = prop.img or t.img
            drawWithStencil(prop.x, prop.y - 0.04, prop.z, img, false)
        end
        local dx, dz = prop.x - cx, prop.z - cz
        if dx*dx + dz*dz < 9 then
            local sx, sy, z = camera:project3D(prop.x, prop.y, prop.z)
            if sx and z > 0 and t then
                local scale = (1 / z) * 6
                local barW = 40 * scale
                local barH = 6 * scale
                local healthRatio = prop.health / (prop.maxHealth or t.maxHealth)
                
                local bx = sx - barW/2 + (prop.shakeOffsetX * scale)
                local by = sy - (t.h * scale + 4) + (prop.shakeOffsetY * scale)

                lg.setColor(0, 0, 0)
                lg.rectangle("fill", bx, by, barW, barH)
                lg.setColor(1 - healthRatio, healthRatio, 0)
                lg.rectangle("fill", bx + scale, by + scale, (barW - 2*scale) * healthRatio, barH - 2*scale)
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
        
        if dx*dx + dz*dz < 9 then
            local sx, sy, z = camera:project3D(prop.x, prop.y, prop.z)
            if sx and z > 0 then
                local t = propTypes[prop.typeIndex]
                if not t then
                    goto continue
                end
                local scale = (1 / z) * 6
                local w, h = (t.w or 1) * scale, (t.h or 1) * scale

                if mx >= sx - w/2 and mx <= sx + w/2 and my >= sy - h and my <= sy and t then
                    local multiplier = selected and ItemsModule.getToolMultiplier(selected.type, t.bestTool) or 1
                    prop.health = prop.health - multiplier
                    if prop.shakeTimer <= 0 then
                        prop.shakeTimer = 0.07
                        shakingProps[#shakingProps+1] = prop
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
                                        ItemsModule.dropItem(prop.x + (random()-0.5)*0.5, prop.y + 0.8, prop.z + (random()-0.5)*0.5, itemName)
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
    props = props
}