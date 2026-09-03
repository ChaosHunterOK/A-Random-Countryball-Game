local love = require "love"
local lg = love.graphics
local camera = require("source.projectile.camera")
local Particles = require("source.projectile.particles")

local Structures = {}
Structures.placed = {}
local nextId = 1

local FUEL_VALUES = {
    stick = 8,
    oak = 20,
    wood_planks = 15,
    bituminous_coal = 45,
    lignite_coal = 35,
    anthracite_coal = 60,
}
Structures.FUEL_VALUES = FUEL_VALUES
local SMELT_RECIPES = {
    copper_ore = {output = "copper_ingot", time = 12},
}
Structures.SMELT_RECIPES = SMELT_RECIPES
local FIRING_RESULTS = {
    clay_bowl_unfired = "clay_bowl",
    clay_pot_unfired = "clay_pot",
    clay_brick_unfired = "clay_brick",
    clay_furnace_brick_unfired = "clay_furnace_brick",
    clay_plate_unfired = "clay_plate",
    clay_cup_unfired = "clay_cup",
    clay_jar_unfired = "clay_jar",
}

local function getFiringResult(itemType)
    if not itemType then return nil end

    local direct = FIRING_RESULTS[itemType]
    if direct then return direct end

    if itemType:sub(-8) == "_unfired" then
        local base = itemType:sub(1, -9)
        if base and base ~= "" then return base end
    end

    return nil
end
Structures.FIRING_RESULTS = FIRING_RESULTS
Structures.getFiringResult = getFiringResult

local PIT_KILN_FIRE_TIME = 25
local PIT_KILN_FAIL_CHANCE = 0.1

local im = "image/"
local function tryImage(path, fallback)
    local ok, img = pcall(lg.newImage, path)
    if ok then return img end
    if fallback then
        local ok2, img2 = pcall(lg.newImage, fallback)
        if ok2 then return img2 end
    end
    return nil
end

local FIRE_PIT_IMG = tryImage(im.."structures/fire_pit.png", im.."placeholder.png")
local FIRE_PIT_LIT_IMG = tryImage(im.."structures/fire_pit_lit.png", im.."structures/fire_pit.png") or FIRE_PIT_IMG
local PIT_KILN_IMG = tryImage(im.."structures/pit_kiln.png", im .."placeholder.png")
local PIT_KILN_LIT_IMG = tryImage(im.."structures/pit_kiln_lit.png", im.."structures/pit_kiln.png") or PIT_KILN_IMG

local FIRE_ANIMATION = {
    tryImage(im.."particles/fire/1.png"),
    tryImage(im.."particles/fire/2.png"),
    tryImage(im.."particles/fire/3.png"),
}

Structures.DEFS = {
    fire_pit = {
        item = "fire_pit", name = "Fire Pit",
        img = FIRE_PIT_IMG, litImg = FIRE_PIT_LIT_IMG,
        inputSlots = 1, outputSlots = 1, batch = false,
    },
    pit_kiln = {
        item = "pit_kiln", name = "Pit Kiln",
        img = PIT_KILN_IMG, litImg = PIT_KILN_LIT_IMG,
        inputSlots = 4, outputSlots = 4, batch = true,
    },
}

function Structures.place(structType, x, y, z, id)
    local def = Structures.DEFS[structType]
    if not def then return nil end
    local s = {
        id = id or nextId,
        type = structType,
        x = x, y = y, z = z,
        lit = false,
        fuel = nil,
        fuelRemaining = 0,
        inputs = {},
        outputs = {},
        cookProgress = 0,
        kilnProgress = 0,
        smokeTimer = 0,
    }
    if not id or id >= nextId then nextId = s.id + 1 end
    table.insert(Structures.placed, s)
    return s
end

function Structures.clear()
    Structures.placed = {}
    nextId = 1
end

function Structures.findById(id)
    for i = 1, #Structures.placed do
        if Structures.placed[i].id == id then return Structures.placed[i], i end
    end
    return nil
end

function Structures.findNear(x, y, z, radius)
    radius = radius or 1.2
    local best, bestDistSq = nil, radius * radius
    for i = 1, #Structures.placed do
        local s = Structures.placed[i]
        local dx, dy, dz = s.x - x, s.y - y, s.z - z
        local distSq = dx * dx + dy * dy + dz * dz
        if distSq <= bestDistSq then
            best, bestDistSq = s, distSq
        end
    end
    return best
end

function Structures.getAtScreen(mx, my)
    for i = #Structures.placed, 1, -1 do
        local s = Structures.placed[i]
        local def = Structures.DEFS[s.type]
        local img = (s.lit and def.litImg) or def.img
        if img then
            local sx, sy, z = camera:project3D(s.x, s.y, s.z)
            if sx and z > 0 then
                local scale = (1 / z) * 6
                local w, h = img:getWidth() * scale, img:getHeight() * scale
                local left, top = sx - w / 2, sy - h
                if mx >= left and mx <= left + w and my >= top and my <= sy then
                    return s
                end
            end
        end
    end
    return nil
end

local function fuelValue(itemType)
    return FUEL_VALUES[itemType]
end
Structures.fuelValue = fuelValue

function Structures.addFuel(s, itemType, count)
    if not fuelValue(itemType) then return 0 end
    if s.fuel and s.fuel.type ~= itemType then return 0 end

    s.fuel = s.fuel or {type = itemType, count = 0}
    local added = count or 1
    s.fuel.count = s.fuel.count + added
    return added
end

function Structures.tryIgnite(s)
    if not s or s.lit then return false end
    if not s.fuel or s.fuel.count <= 0 then return false end

    local def = Structures.DEFS[s.type]
    if def.batch then
        local hasGreenware = false
        for i = 1, def.inputSlots do
            local slot = s.inputs[i]
            if slot and slot.type and getFiringResult(slot.type) then
                hasGreenware = true
                break
            end
        end
        if not hasGreenware then return false end
        s.kilnProgress = 0
    end

    s.lit = true
    return true
end

function Structures.extinguish(s)
    s.lit = false
    s.cookProgress = 0
    if Structures.DEFS[s.type].batch then
        s.kilnProgress = 0
    end
end

local function stackAdd(list, index, itemType, count)
    local slot = list[index]
    if slot and slot.type == itemType then
        slot.count = slot.count + count
    else
        list[index] = { type = itemType, count = count }
    end
end

local function consumeFuelTick(s, dt)
    if s.fuelRemaining <= 0 then
        if s.fuel and s.fuel.count > 0 then
            s.fuelRemaining = s.fuelRemaining + (fuelValue(s.fuel.type) or 10)
            s.fuel.count = s.fuel.count - 1
            if s.fuel.count <= 0 then s.fuel = nil end
        else
            Structures.extinguish(s)
            return
        end
    end
    s.fuelRemaining = math.max(0, s.fuelRemaining - dt)
end

local function updateFirePit(s, dt)
    if not s.lit then return end
    consumeFuelTick(s, dt)
    if not s.lit then return end

    local ore = s.inputs[1]
    if ore and ore.type and SMELT_RECIPES[ore.type] then
        local recipe = SMELT_RECIPES[ore.type]
        s.cookProgress = s.cookProgress + dt
        if s.cookProgress >= recipe.time then
            s.cookProgress = s.cookProgress - recipe.time
            ore.count = ore.count - 1
            if ore.count <= 0 then s.inputs[1] = nil end
            stackAdd(s.outputs, 1, recipe.output, 1)
        end
    else
        s.cookProgress = 0
    end
end

local function updatePitKiln(s, dt)
    if not s.lit then return end
    consumeFuelTick(s, dt)
    if not s.lit then return end

    s.kilnProgress = s.kilnProgress + dt
    if s.kilnProgress >= PIT_KILN_FIRE_TIME then
        local def = Structures.DEFS.pit_kiln
        for i = 1, def.inputSlots do
            local slot = s.inputs[i]
            local resultType = slot and slot.type and getFiringResult(slot.type)
            if resultType then
                if math.random() < PIT_KILN_FAIL_CHANCE then
                    --cug
                else
                    stackAdd(s.outputs, i, resultType, slot.count)
                end
                s.inputs[i] = nil
            end
        end
        Structures.extinguish(s)
    end
end

function Structures.update(dt)
    for i = 1, #Structures.placed do
        local s = Structures.placed[i]
        local def = Structures.DEFS[s.type]
        if def then
            if def.batch then
                updatePitKiln(s, dt)
            else
                updateFirePit(s, dt)
            end

            if s.lit then
                s.smokeTimer = s.smokeTimer - dt
                if s.smokeTimer <= 0 then
                    s.smokeTimer = 0.4
                    local smokeImg = FIRE_PIT_LIT_IMG
                    if smokeImg then
                        Particles.spawnSmoke(smokeImg, s.x, s.y + 0.6, s.z, 1.2, 0, 0.4, 0, 0.25, 0.5)
                    end
                    if FIRE_ANIMATION[1] then
                        Particles.spawnFire(FIRE_ANIMATION, s.x, s.y + 0.5, s.z, 5, 0.6, 0.8)
                    end
                end
            end
        end
    end
end

function Structures.draw(drawWithStencil)
    for i = 1, #Structures.placed do
        Structures.drawOne(Structures.placed[i], drawWithStencil)
    end
end

function Structures.drawOne(s, drawWithStencil)
    local def = Structures.DEFS[s.type]
    if not def then return end
    local img = (s.lit and def.litImg) or def.img
    drawWithStencil(s.x, s.y - 0.04, s.z, img, false)
end

function Structures.serialize()
    local data = {}
    for i = 1, #Structures.placed do
        local s = Structures.placed[i]
        data[i] = {
            id = s.id, type = s.type, x = s.x, y = s.y, z = s.z,
            lit = s.lit, fuel = s.fuel, fuelRemaining = s.fuelRemaining,
            inputs = s.inputs, outputs = s.outputs,
            cookProgress = s.cookProgress, kilnProgress = s.kilnProgress,
        }
    end
    return data
end

function Structures.deserialize(data)
    Structures.clear()
    if not data then return end
    for i = 1, #data do
        local d = data[i]
        local s = Structures.place(d.type, d.x, d.y, d.z, d.id)
        if s then
            s.lit = d.lit or false
            s.fuel = d.fuel
            s.fuelRemaining = d.fuelRemaining or 0
            s.inputs = d.inputs or {}
            s.outputs = d.outputs or {}
            s.cookProgress = d.cookProgress or 0
            s.kilnProgress = d.kilnProgress or 0
        end
    end
end

Structures.PIT_KILN_FIRE_TIME = PIT_KILN_FIRE_TIME

return Structures
