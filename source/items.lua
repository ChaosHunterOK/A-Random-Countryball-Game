local love = require "love"
local lg = love.graphics

local PATH = "image/items/"
local function item(img, stack, eatable, opts)
    opts = opts or {}
    return {
        img = PATH .. img,
        stack = stack or 10,
        eatable = eatable or false,
        durability = opts.durability,
        toolType = opts.toolType,
        material = opts.material
    }
end

local itemDefinitions = {
    apple = item("apple.png", 10, true),
    green_apple = item("green_apple.png", 10, true),

    amorphous = item("amorphous.png", 1),
    bituminous_coal = item("bituminous_coal.png", 20),
    flint = item("flint.png", 20),
    iron_raw = item("iron_raw.png", 20),
    map = item("map.png", 1),
    oak = item("oak.png", 50),
    paper = item("paper.png", 50),
    phenocrysts = item("phenocrysts.png", 10),
    porphyry = item("porphyry.png", 20),
    ruby = item("ruby.png", 5),
    snowball = item("snowball.png", 20),
    clay = item("clay.png", 20),

    stick = item("stick.png", 50, false, {material = "stick"}),
    firestarter = item("firestarter.png", 25, false, {material = "stick"}),

    stone = item("stone.png", 50, false, {material = "stone"}),
    dark_stone = item("dark_stone.png", 50, false, {material = "stone"}),
    pumice = item("pumice.png", 35, false, {material = "stone"}),
    wood_planks = item("wood.png", 50, false, {material = "wood"}),

    anthracite_coal = item("anthracite_coal.png", 20),
    lignite_coal = item("lignite_coal.png", 20),
    dirt = item("dirt.png", 40),
    leaf = item("leaf.png", 50),
    gravel = item("gravel.png", 50),
    apple_seed = item("seeds/apple.png", 50),
    nail = item("nail.png", 50),

    --tool heads
    stone_shovel_head = item("heads/stone/shovel.png", 5),
    stone_hoe_head = item("heads/stone/hoe.png", 5),
    stone_hammer_head = item("heads/stone/hammer.png", 5),
    stone_pick_head = item("heads/stone/pick.png", 5),
    stone_knife_head = item("heads/stone/knife.png", 5),
    stone_javeline_head = item("heads/stone/javeline.png", 5),

    --stone tools
    stone_shovel = item("shovel_type/stone.png", 2, false, {durability = 50, toolType = "shovel", material = "stone"}),
    stone_hoe = item("hoe_type/stone.png", 2, false, {durability = 50, toolType = "hoe", material = "stone"}),
    stone_knife = item("knife_type/stone.png", 2, false, {durability = 50, toolType = "knife", material = "stone"}),
    stone_hammer = item("hammer_type/stone.png", 2, false, {durability = 50, toolType = "hammer", material = "stone"}),
    stone_pickaxe = item("pickaxe_type/stone.png", 2, false, {durability = 50, toolType = "pickaxe", material = "stone"}),
    stone_tool = item("thing.png", 2, false, {durability = 50, toolType = "pickaxe", material = "stone"}),

    --iron tools
    iron_shovel = item("shovel_type/iron.png", 2, false, { durability = 60, toolType = "shovel", material = "iron"}),
    iron_hoe = item("hoe_type/iron.png", 2, false, {durability = 50, toolType = "hoe", material = "iron"}),
    iron_pickaxe = item("pickaxe_type/iron.png", 2, false, {durability = 60, toolType = "pickaxe", material = "iron"}),

    ruby_pickaxe = item("pickaxe_type/iron.png", 2, false, {durability = 60, toolType = "pickaxe", material = "ruby"}),

    clay_bowl = item("pottery/bowl.png", 4, false, {material = "ceramic"}),
    clay_pot = item("pottery/pot.png", 2, false, {material = "ceramic"}),
    clay_brick = item("pottery/brick.png", 50, false, {material = "ceramic"}),
    clay_furnace_brick = item("pottery/furnace_brick.png", 20, false, {material = "ceramic"}),
    clay_plate = item("pottery/plate.png", 10, false, {material = "ceramic"}),
    clay_cup = item("pottery/cup.png", 8, true, {material = "ceramic"}),
    clay_jar = item("pottery/jar.png", 2, false, {material = "ceramic"}),

    copper_ore = item("copper.png", 20),
    copper_ingot = item("copper_ingot.png", 20, false, {material = "copper"}),
    copper_shovel_head = item("heads/copper/shovel.png", 5),
    copper_hoe_head = item("heads/copper/hoe.png", 5),
    copper_hammer_head = item("heads/copper/hammer.png", 5),
    copper_pick_head = item("heads/copper/pick.png", 5),
    copper_knife_head = item("heads/copper/knife.png", 5),
    
    copper_shovel = item("shovel_type/copper.png", 2, false, {durability = 75, toolType = "shovel", material = "copper"}),
    copper_hoe = item("hoe_type/copper.png", 2, false, {durability = 75, toolType = "hoe", material = "copper"}),
    copper_knife = item("knife_type/copper.png", 2, false, {durability = 75, toolType = "knife", material = "copper"}),
    copper_hammer = item("hammer_type/copper.png", 2, false, {durability = 75, toolType = "hammer", material = "copper"}),
    copper_pickaxe = item("pickaxe_type/copper.png", 2, false, {durability = 75, toolType = "pickaxe", material = "copper"}),
}

local items = {}
local itemTypes = {}

for name, def in pairs(itemDefinitions) do
    local img = lg.newImage(def.img)
    def.img = img

    items[name] = img
    itemTypes[name] = def
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
    copper = 1.4,
    ceramic = 0.5,
    stick = 0.2,
    wood = 0.8,
}
local itemsOnGround = {}

local function dropItem(x, y, z, itemType, count, durability, velocityY)
    itemsOnGround[#itemsOnGround + 1] = {
        x = x,
        y = y,
        z = z,
        type = itemType,
        count = count or 1,
        durability = durability,
        velocityY = velocityY or 0
    }
end

local function removeItem(index)
    table.remove(itemsOnGround, index)
end

local function getItemImage(itemType)
    return itemTypes[itemType] and itemTypes[itemType].img
end

local function getToolMultiplier(itemType, bestTool)
    local item = itemTypes[itemType]
    if not item then return 1 end

    if not item.toolType then
        return 0.4
    end

    local materialMul = materialMultiplier[item.material] or 1
    local typeBonus = toolTypeBonus[item.toolType] or 1

    if item.toolType ~= bestTool then
        return 0.6 * materialMul
    end

    return typeBonus * materialMul
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