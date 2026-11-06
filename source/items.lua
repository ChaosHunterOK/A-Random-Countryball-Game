local love = require "love"
local lg = love.graphics
local ModAPI = require("source.api.mod")

local PATH = "image/items/"

local function item(img, stack, eatable, opts)
    opts = opts or {}
    if type(eatable) == "table" then opts, eatable = eatable, false end
    return {
        img = PATH .. img,
        stack = stack or 10,
        eatable = eatable or false,
        durability = opts.durability,
        toolType = opts.toolType,
        material = opts.material,
    }
end

local function itemAbs(img, stack, eatable, opts)
    opts = opts or {}
    if type(eatable) == "table" then opts, eatable = eatable, false end
    return {
        img = img,
        stack = stack or 10,
        eatable = eatable or false,
        durability = opts.durability,
        toolType = opts.toolType,
        material = opts.material,
    }
end

local baseItems = {
    apple = item("food/apple.png", 10, true),
    green_apple = item("food/green_apple.png", 10, true),
    yellow_apple = item("food/yellow_apple.png", 10, true),
    barrel_cactus_fruit = item("food/barrel_cactus_fruit.png", 20, true),

    amorphous = item("amorphous.png", 1),
    bituminous_coal = item("bituminous_coal.png", 20, false, {material = "coal"}),
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

    anthracite_coal = item("anthracite_coal.png", 20, false, {material = "coal"}),
    lignite_coal = item("lignite_coal.png", 20, false, {material = "coal"}),
    dirt = item("dirt.png", 40),
    leaf = item("leaf.png", 50, false, {material = "leaf"}),
    cycad_leaf = item("cycad_leaf.png", 50, false, {material = "leaf"}),
    gravel = item("gravel.png", 50),
    apple_seed = item("seeds/apple.png", 50),
    barrel_cactus_seed = item("seeds/barrel_cactus.png", 50),
    nail = item("nail.png", 50),
    porcini_mushroom = item("porcini_mushroom.png", 30),
    lily_pad = item("lily_pad.png", 40),
    cactus_slice = item("cactus_slice.png", 15),

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
    iron_shovel_head = item("heads/iron/shovel.png", 5),
    iron_hoe_head = item("heads/iron/hoe.png", 5),
    iron_knife_head = item("heads/iron/knife.png", 5),
    iron_hammer_head = item("heads/iron/hammer.png", 5),
    iron_pick_head = item("heads/iron/pick.png", 5),

    iron_shovel = item("shovel_type/iron.png", 2, false, {durability = 60, toolType = "shovel", material = "iron"}),
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
    stone_axe_head = item("heads/stone/axe.png", 5),
    stone_axe = item("axe_type/stone.png", 2, false, {durability = 50, toolType = "axe", material = "stone"}),

    copper_axe_head = item("heads/copper/axe.png", 5),
    copper_axe = item("axe_type/copper.png", 2, false, {durability = 75, toolType = "axe", material = "copper"}),

    iron_axe_head = item("heads/iron/axe.png", 5),
    iron_axe = item("axe_type/iron.png", 2, false, {durability = 60, toolType = "axe", material = "iron"}),

    --lumber
    log_pile = item("log_pile.png", 20, false, {material = "wood"}),
    clay_bowl_unfired = item("pottery/bowl.png", 4, false, {material = "clay"}),
    clay_pot_unfired = item("pottery/pot.png", 2, false, {material = "clay"}),
    clay_brick_unfired = item("pottery/brick.png", 50, false, {material = "clay"}),
    clay_furnace_brick_unfired = item("pottery/furnace_brick.png", 20, false, {material = "clay"}),
    clay_plate_unfired = item("pottery/plate.png", 10, false, {material = "clay"}),
    clay_cup_unfired = item("pottery/cup.png", 8, false, {material = "clay"}),
    clay_jar_unfired = item("pottery/jar.png", 2, false, {material = "clay"}),
    --fire
    fire_pit = itemAbs("image/structures/fire_pit.png", 5),
    pit_kiln = itemAbs("image/structures/pit_kiln.png", 5),
}

local baseToolTypes = {
    axe = 1.75, pickaxe = 2.05, shovel = 2, knife = 2.5, hammer = 1.5,
}
local baseToolMaterials = {
    stone = 1.1, flint = 1.15, pumice = 1.05, iron = 1.3, ruby = 1.5,
    copper = 1.4, ceramic = 0.5, stick = 0.2, wood = 0.8, coal = 1.1,
}

local FALLBACK_IMG_PATH = "image/placeholder.png"
local fallbackImg, fallbackTried = nil, false

local function getFallback()
    if fallbackTried then return fallbackImg end
    fallbackTried = true

    local ok, fb = pcall(lg.newImage, FALLBACK_IMG_PATH)
    if ok and fb then
        fallbackImg = fb
        return fallbackImg
    end

    local ok2, generated = pcall(function()
        local data = love.image.newImageData(16, 16)
        data:mapPixel(function(x, y)
            local on = ((math.floor(x / 8) + math.floor(y / 8)) % 2) == 0
            if on then return 1, 0, 1, 1 end
            return 0, 0, 0, 1
        end)
        return lg.newImage(data)
    end)

    fallbackImg = ok2 and generated or nil
    return fallbackImg
end

local imgCache = {}

local function loadItemImage(path)
    if not path then return getFallback() end
    if type(path) ~= "string" then return path end
    
    local cached = imgCache[path]
    if cached ~= nil then return cached or getFallback() end

    local ok, imgOrErr = pcall(lg.newImage, path)
    if ok then
        imgCache[path] = imgOrErr
        return imgOrErr
    end

    imgCache[path] = false
    print("[items] missing image '" .. tostring(path) .. "', using placeholder")
    return getFallback()
end

local items = {}
local itemTypes = {}

local placeholders = {}

local function placeholderFor(id)
    if type(id) ~= "string" then id = tostring(id) end
    local ph = placeholders[id]
    if ph then return ph end

    ph = {
        id = id,
        missing  = true,
        img = getFallback(),
        stack = 1,
        eatable = false,
        name = (id:gsub("_", " ")),
    }
    placeholders[id] = ph
    print("[items] unknown item '" .. id .. "', using placeholder definition")
    return ph
end

local toolTypeBonus = {}
local materialMultiplier = {}

local lastItemRev, lastToolRev, lastMatRev = -1, -1, -1

local function clear(t) for k in pairs(t) do t[k] = nil end end

local function registerBaseContent()
    local reg = ModAPI.registry("item")
    for id, def in pairs(baseItems) do
        local copy = {}
        for k, v in pairs(def) do copy[k] = v end
        reg:register(id, copy, nil)
    end

    local tt = ModAPI.registry("toolType")
    for id, power in pairs(baseToolTypes) do
        local p = type(power) == "table" and power.power or power
        tt:register(id, { power = p }, nil)
    end

    local tm = ModAPI.registry("toolMaterial")
    for id, power in pairs(baseToolMaterials) do
        local p = type(power) == "table" and power.power or power
        tm:register(id, { power = p }, nil)
    end
end

local function rebuild()
    clear(items)
    clear(itemTypes)
    clear(placeholders)

    local reg = ModAPI.registry("item")
    if not reg or not reg:get("apple") then
        registerBaseContent()
    end

    for id, def in pairs(ModAPI.getAll("item")) do
        local copy = {}
        for k, v in pairs(def) do copy[k] = v end
        copy.img = loadItemImage(def.img)
        itemTypes[id] = copy
        items[id] = copy.img
    end

    clear(toolTypeBonus)
    for id, def in pairs(ModAPI.getAll("toolType")) do
        toolTypeBonus[id] = type(def) == "number" and def or (def.power or 1)
    end

    clear(materialMultiplier)
    for id, def in pairs(ModAPI.getAll("toolMaterial")) do
        materialMultiplier[id] = type(def) == "number" and def or (def.power or 1)
    end

    lastItemRev = ModAPI.revision("item")
    lastToolRev = ModAPI.revision("toolType")
    lastMatRev  = ModAPI.revision("toolMaterial")
end

local function sync()
    if lastItemRev ~= ModAPI.revision("item")
    or lastToolRev ~= ModAPI.revision("toolType")
    or lastMatRev  ~= ModAPI.revision("toolMaterial") then
        rebuild()
    end
end

setmetatable(itemTypes, {
    __index = function(t, id)
        if id == nil then return nil end
        sync()
        local found = rawget(t, id)
        if found ~= nil then return found end
        return placeholderFor(id)
    end,
})

setmetatable(items, {
    __index = function(t, id)
        if id == nil then return nil end
        sync()
        local found = rawget(t, id)
        if found ~= nil then
            if type(found) == "string" then
                return loadItemImage(found)
            end
            return found
        end
        local def = itemTypes[id]
        if def and def.img then
            return loadItemImage(def.img)
        end
        return placeholderFor(id).img
    end,
})

local function isKnownItem(id)
    sync()
    return id ~= nil and rawget(itemTypes, id) ~= nil
end

registerBaseContent()
rebuild()

local itemsOnGround = {}

local function dropItem(x, y, z, itemType, count, durability, velocityY)
    itemsOnGround[#itemsOnGround + 1] = {
        x = x, y = y, z = z,
        type = itemType,
        count = count or 1,
        durability = durability,
        velocityY = velocityY or 0,
    }
    ModAPI.emit("onItemDrop", itemsOnGround[#itemsOnGround])
end

local function removeItem(index)
    table.remove(itemsOnGround, index)
end

local function getItemImage(itemType)
    sync()
    local def = itemTypes[itemType]
    if def and def.img then
        return loadItemImage(def.img)
    end
    return getFallback()
end

local function getItemDef(itemType)
    sync()
    return itemTypes[itemType]
end

local function getStackLimit(itemType)
    sync()
    local def = itemTypes[itemType]
    local n = def and def.stack
    if type(n) ~= "number" or n < 1 then return 1 end
    return n
end

local function getToolMultiplier(itemType, bestTool)
    sync()
    local def = itemTypes[itemType]
    if not def then return 1 end

    local materialMul = materialMultiplier[def.material] or 1

    local result
    if not def.toolType then
        result = 0.4 * (def.material and materialMul or 1)
    elseif bestTool and def.toolType ~= bestTool then
        result = 0.6 * materialMul
    else
        result = (toolTypeBonus[def.toolType] or 1) * materialMul
    end

    return ModAPI.runFilter("onCalculateToolPower", result, def, bestTool)
end

return {
    items = items,
    itemTypes = itemTypes,
    itemsOnGround = itemsOnGround,
    dropItem = dropItem,
    removeItem = removeItem,
    getItemImage = getItemImage,
    getItemDef = getItemDef,
    getStackLimit = getStackLimit,
    isKnownItem = isKnownItem,
    getToolMultiplier = getToolMultiplier,
    refresh = rebuild,
    sync = sync,
}