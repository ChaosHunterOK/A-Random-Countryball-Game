local love = require "love"
local lg = love.graphics

local itemDefinitions = {
    apple = {"image/items/apple.png", 10, true},
    amorphous = {"image/items/amorphous.png", 1, false},
    bituminous_coal = {"image/items/bituminous_coal.png", 20, false},
    flint = {"image/items/flint.png", 20, false},
    iron_raw = {"image/items/iron_raw.png", 20, false},
    map = {"image/items/map.png", 1, false},
    oak = {"image/items/oak.png", 50, false},
    paper = {"image/items/paper.png", 50, false},
    phenocrysts = {"image/items/phenocrysts.png", 10, false},
    porphyry = {"image/items/porphyry.png", 20, false},
    ruby = {"image/items/ruby.png", 5, false},
    snowball = {"image/items/snowball.png", 20, false},
    stick = {"image/items/stick.png", 50, false},
    stone = {"image/items/stone.png", 50, false},
    wood = {"image/items/wood.png", 50, false},
    anthracite_coal = {"image/items/anthracite_coal.png", 20, false},
    dirt = {"image/items/dirt.png", 40, false},
    leaf = {"image/items/leaf.png", 50, false},

    stone_shovel_head = {"image/items/heads/stone/shovel.png", 5, false},
    stone_hoe_head = {"image/items/heads/stone/hoe.png", 5, false},
    stone_hammer_head = {"image/items/heads/stone/hammer.png", 5, false},

    stone_shovel = {"image/items/shovel_type/stone.png", 2, false},
    stone_hoe = {"image/items/hoe_type/stone.png", 2, false},
    stone_hammer = {"image/items/hammer_type/stone.png", 2, false},
    stone_tool = {"image/items/thing.png", 2, false, 50},
}

local items = {}
local itemTypes = {}

for name, def in pairs(itemDefinitions) do
    local img = lg.newImage(def[1])
    items[name] = img

    itemTypes[name] = {
        img = img,
        stack = def[2],
        eatable = def[3],
        durability = def[4] or nil,
    }
end

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

local toolMultipliers = {
    stone = 1.1,
    iron_raw = 1.2,
    stick = 0.8,
    tool = 1.2,
}

local function getToolMultiplier(itemType)
    return toolMultipliers[itemType] or 1.0
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