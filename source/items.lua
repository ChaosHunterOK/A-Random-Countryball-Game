local love = require "love"
local lg = love.graphics

local itemDefinitions = {
    apple = { "image/items/apple.png", 10, true },
    green_apple = { "image/items/green_apple.png", 10, true },
    amorphous = { "image/items/amorphous.png", 1, false },
    bituminous_coal = { "image/items/bituminous_coal.png", 20, false },
    flint = { "image/items/flint.png", 20, false },
    iron_raw = { "image/items/iron_raw.png", 20, false },
    map = { "image/items/map.png", 1, false },
    oak = { "image/items/oak.png", 50, false },
    paper = { "image/items/paper.png", 50, false },
    phenocrysts = { "image/items/phenocrysts.png", 10, false },
    porphyry = { "image/items/porphyry.png", 20, false },
    ruby = { "image/items/ruby.png", 5, false },
    snowball = { "image/items/snowball.png", 20, false },
    stick = { "image/items/stick.png", 50, false, nil, nil, material = "stick" },
    firestarter = { "image/items/firestarter.png", 25, false, nil, nil, material = "stick" },
    stone = { "image/items/stone.png", 50, false },
    dark_stone = { "image/items/dark_stone.png", 50, false },
    pumice = { "image/items/pumice.png", 35, false },
    wood = { "image/items/wood.png", 50, false },
    anthracite_coal = { "image/items/anthracite_coal.png", 20, false },
    dirt = { "image/items/dirt.png", 40, false },
    leaf = { "image/items/leaf.png", 50, false },

    stone_shovel_head = { "image/items/heads/stone/shovel.png", 5, false },
    stone_hoe_head = { "image/items/heads/stone/hoe.png", 5, false },
    stone_hammer_head = { "image/items/heads/stone/hammer.png", 5, false },
    stone_pick_head = { "image/items/heads/stone/pick.png", 5, false },

    stone_shovel = { "image/items/shovel_type/stone.png", 2, false, durability = 50, toolType = "shovel", material = "stone" },
    stone_hoe = { "image/items/hoe_type/stone.png", 2, false, durability = 50, toolType = "hoe", material = "stone" },
    stone_hammer = { "image/items/hammer_type/stone.png", 2, false, durability = 50, toolType = "hammer", material = "stone" },
    stone_tool = { "image/items/thing.png", 2, false, 2, durability = 35, toolType = "pickaxe", material = "stone" },
    stone_pickaxe = { "image/items/pickaxe_type/stone.png", 2, false, 2, durability = 50, toolType = "pickaxe", material = "stone" },

    iron_shovel = { "image/items/shovel_type/iron.png", 2, false, durability = 60, toolType = "shovel", material = "iron" },
    iron_pickaxe = { "image/items/pickaxe_type/iron.png", 2, false, durability = 60, toolType = "shovel", material = "iron" },
}

local items = {}
local itemTypes = {}

for name, def in pairs(itemDefinitions) do
    local img = lg.newImage(def[1])
    items[name] = img

    itemTypes[name] = {
        img = img,
        stack = def[2] or 10,
        eatable = def[3] or false,
        durability = def.durability or nil,
        toolType = def.toolType,
        material = def.material
    }
end


local toolTypeBonus = {
    axe = 1.75,
    pickaxe = 2.05,
    shovel = 2,
    knife = 2.5,
    hammer = 1.5,
}

local materialMultiplier = {
    stone = 1.1,
    flint = 1.15,
    pumice = 1.05,
    iron = 1.3,
    ruby = 1.5,
    stick = 0.2,
    wood = 0.8,
}

local itemsOnGround = {}

local function dropItem(x, y, z, itemType, velocityY)
    itemsOnGround[#itemsOnGround + 1] = {
        x = x,
        y = y,
        z = z,
        type = itemType,
        velocityY = velocityY or 0,
    }
end

local function removeItem(index)
    table.remove(itemsOnGround, index)
end

local function getItemImage(itemType)
    return itemTypes[itemType] and itemTypes[itemType].img
end

local function getToolMultiplier(itemType, propBestTool)
    local item = itemTypes[itemType]
    if not item then return 1 end

    local material = item.material
    local toolType = item.toolType

    local materialMul = (material and materialMultiplier[material]) or 1.0
    if not toolType or toolType ~= propBestTool then
        return materialMul * 0.35
    end
    local typeBonus = toolTypeBonus[toolType] or 1.0

    return materialMul * typeBonus
end

return {
    items = items,
    itemTypes = itemTypes,
    itemsOnGround = itemsOnGround,
    dropItem = dropItem,
    removeItem = removeItem,
    getItemImage = getItemImage,
    getToolMultiplier = getToolMultiplier,
}
