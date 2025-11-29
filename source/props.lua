local love = require "love"
local lg = love.graphics
local sqrt = math.sqrt
local max = math.max
local random = math.random
local floor = math.floor

local camera_3d = require("source.projectile.camera")
local countryball = require("source.countryball")
local ItemsModule = require("source.items")
local utils = require("source.utils")

local props = {}
local propTypes = {
    {img = lg.newImage("image/tree.png"), maxHealth = 10, canBreak = true, name = "Tree"},
    {img = lg.newImage("image/rock.png"), maxHealth = 25, canBreak = true, name = "Rock"},
    {img = lg.newImage("image/ore_type/iron.png"), maxHealth = 32, canBreak = true, name = "Iron Ore"},
    {img = lg.newImage("image/bush.png"), maxHealth = 2, canBreak = true, name = "Bush"},
    {img = lg.newImage("image/porphyry_rock.png"), maxHealth = 25, canBreak = true, name = "Porphyry Rock"},
    {img = lg.newImage("image/dark_rock.png"), maxHealth = 25, canBreak = true, name = "Dark Rock"},
    {img = lg.newImage("image/pumice_rock.png"), maxHealth = 25, canBreak = true, name = "Pumice Rock"},
}
for i=1, #propTypes do
    local t = propTypes[i]
    t.w, t.h = t.img:getWidth(), t.img:getHeight()
end
local function spawnProps(num, mapWidth, mapDepth)
    for i = 1, num do
        local index = random(#propTypes)
        local pType = propTypes[index]
        props[#props+1] = {
            typeIndex = index,
            x = random() * mapWidth,
            z = random() * mapDepth,
            y = 0,
            img = pType.img,
            w = pType.w,
            h = pType.h,
            health = pType.maxHealth,
            maxHealth = pType.maxHealth,
            canBreak = pType.canBreak,
            shakeTimer = 0,
            shakeDuration = 0.07,
            shakeOffsetX = 0,
            shakeOffsetY = 0,
        }
    end
end

local function updateProps(dt, heights)
    for _, prop in ipairs(props) do
        --[[prop.velocityY = (prop.velocityY or 0) + gravity * dt
        prop.y = prop.y + prop.velocityY * dt

        local groundY = getHeightAt(prop.x, prop.z, heights)
        if prop.y < groundY then
            prop.y = groundY
            prop.velocityY = 0
        end]]
        if prop.shakeTimer > 0 then
            prop.shakeTimer = max(0, prop.shakeTimer - dt)
            local intensity = 3
            prop.shakeOffsetX = (random() - 0.5) * 2 * intensity
            prop.shakeOffsetY = (random() - 0.5) * 2 * intensity
        else
            prop.shakeOffsetX = 0
            prop.shakeOffsetY = 0
        end
    end
end

local function drawProps(drawWithStencil)
    local cx, cz = countryball.x, countryball.z
    for i = 1, #props do
        local prop = props[i]
        drawWithStencil(prop.x, prop.y, prop.z, prop.img, false)
        local dx = prop.x - cx
        local dz = prop.z - cz
        local distSq = dx*dx + dz*dz
        if distSq < 9 then
            local sx, sy2, z2 = camera_3d:project3D(prop.x, prop.y, prop.z)
            if sx then
                local scale = (1 / z2) * 6
                local w, h = prop.w, prop.h

                local shakeX = prop.shakeOffsetX * scale
                local shakeY = prop.shakeOffsetY * scale

                if prop.canBreak then
                    local healthRatio = prop.health / prop.maxHealth
                    local barW = 40 * scale
                    local barH = 6 * scale
                    local offsetY = h * scale + 4

                    local bx = sx - barW/2 + shakeX
                    local by = sy2 - offsetY + shakeY

                    lg.setColor(0, 0, 0)
                    lg.rectangle("fill", bx, by, barW, barH)

                    lg.setColor(1 - healthRatio, healthRatio, 0)
                    lg.rectangle("fill",
                        bx + 1*scale, by + 1*scale,
                        (barW - 2*scale) * healthRatio, barH - 2*scale
                    )
                    lg.setColor(1, 1, 1)
                end
            end
        end
    end
end

local function handleMousePressed(mx, my)
    local cx, cz = countryball.x, countryball.z

    for i = #props, 1, -1 do
        local prop = props[i]
        local dx = prop.x - cx
        local dz = prop.z - cz
        if dx*dx + dz*dz > 9 then goto continue end

        local sx, sy2, z2 = camera_3d:project3D(prop.x, prop.y, prop.z)
        if not sx or z2 <= 0 then goto continue end

        local scale = (1 / z2) * 6
        local w, h = prop.w * scale, prop.h * scale

        local left = sx - w/2
        local top = sy2 - h
        local right = left + w
        local bottom = top + h

        if mx >= left and mx <= right and my >= top and my <= bottom then
            if prop.canBreak then
                prop.health = max(0, prop.health - 1)
                prop.shakeTimer = prop.shakeDuration
            end
            local tIndex = prop.typeIndex

            if tIndex == 1 then
                if random() < 0.65 then
                    ItemsModule.dropItem(
                        prop.x + (random() - 0.5) * 0.6,
                        prop.y + 0.75,
                        prop.z + (random() - 0.5) * 0.6,
                        "stick"
                    )
                end
                if random() < 0.15 then
                    ItemsModule.dropItem(prop.x, prop.y + 0.75, prop.z, "apple")
                end
            end
            if prop.health <= 0 then
                if tIndex == 1 then
                    for j = 1, random(2, 5) do
                        ItemsModule.dropItem(prop.x + (random() - 0.5) * 0.5,prop.y + 0.75 + random()*0.3,prop.z + (random() - 0.5) * 0.5,"oak")
                    end
                elseif tIndex == 2 then
                    for j = 1, random(2, 4) do
                        ItemsModule.dropItem(prop.x + (random() - 0.5) * 0.5,prop.y + 0.75 + random()*0.2,prop.z + (random() - 0.5) * 0.5,"stone")
                    end
                end

                table.remove(props, i)
            end
        end

        ::continue::
    end
end

return {
    spawnProps = spawnProps,
    updateProps = updateProps,
    drawProps = drawProps,
    handleMousePressed = handleMousePressed,
    props = props
}