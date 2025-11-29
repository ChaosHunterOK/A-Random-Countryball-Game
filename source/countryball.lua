local love = require "love"
local lg = love.graphics
local utils = require("source.utils")
local floor, sqrt, abs, sin, cos, max, min = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.max, math.min

local countryball = {
    x = 10, y = 0, z = 10,
    health = 10,
    maxHealth = 3,
    speed = 4,
    flip = false,
    scale = 1,
    onGround = false,
    jumpPower = 12,
    velocityY = 0,
    gravity = -18,
    frameDuration = 0.12,
    frameTimer = 0,
    frameIndex = 1,
    animation = "idle",
    inWater = false,
    bobTimer = 0,
    hunger = 5,
    maxHunger = 5,
    damageVelocityX = 0,
    damageVelocityZ = 0,
    isDamaged = false,
    damageTimer = 0,
    damageDuration = 1,
    shakeTime = 0,
    shakeDuration = 0.25,
    shakeStrength = 0.25,
}

function countryball:takeDamage(amount, dirX, dirZ)
    self.health = math.max(0, self.health - amount)
    self.animation = "damage"
    self.isDamaged = true
    self.damageTimer = 0
    self.damageVelocityX = 0.2 * (dirX or 1)
    self.damageVelocityZ = 0.2 * (dirZ or 1)
    self.velocityY = 7
    self.onGround = false
    self.shakeTime = self.shakeDuration
end

local function getFrames(animImages, animName, dt, state)
    local frames = animImages[animName]
    if not frames then return nil end
    if type(frames) ~= "table" then
        return frames
    end

    state.frameTimer = state.frameTimer or 0
    state.frameIndex = state.frameIndex or 1
    local duration = state.frameDuration or 0.12

    state.frameTimer = state.frameTimer + dt
    if state.frameTimer >= duration then
        state.frameTimer = state.frameTimer - duration
        state.frameIndex = (state.frameIndex % #frames) + 1
    end

    return frames[state.frameIndex]
end

local images = {
    idle = {
        lg.newImage("image/countryball/senegal/idle1.png"),
        lg.newImage("image/countryball/senegal/idle2.png"),
    },
    walk = {
        lg.newImage("image/countryball/senegal/walk1.png"),
        lg.newImage("image/countryball/senegal/walk2.png"),
        lg.newImage("image/countryball/senegal/walk3.png"),
        lg.newImage("image/countryball/senegal/walk4.png"),
        lg.newImage("image/countryball/senegal/walk5.png"),
    },
    damage = lg.newImage("image/countryball/senegal/damage.png"),
}

function countryball.update(dt, keyboard, heights, materials, getTileAt, Blocks, camera)
    local dx, dz = 0, 0
    local moveX, moveZ = 0, 0

    local forward = camera:getForward()
    local right = camera:getRight()

    forward.y = 0
    local flen = sqrt(forward.x*forward.x + forward.z*forward.z)
    if flen > 0 then
        forward.x, forward.z = forward.x / flen, forward.z / flen
    end
    right.y = 0
    local rlen = sqrt(right.x*right.x + right.z*right.z)
    if rlen > 0 then
        right.x, right.z = right.x / rlen, right.z / rlen
    end

    if not countryball.isDamaged then
        if keyboard.isDown("up") then
            moveX = moveX + forward.x
            moveZ = moveZ + forward.z
        end
        if keyboard.isDown("down") then
            moveX = moveX - forward.x
            moveZ = moveZ - forward.z
        end
        if keyboard.isDown("left") then
            moveX = moveX + right.x
            moveZ = moveZ + right.z
            countryball.flip = true
        end
        if keyboard.isDown("right") then
            moveX = moveX - right.x
            moveZ = moveZ - right.z
            countryball.flip = false
        end
        if keyboard.isDown("space") then
            if not countryball.inWater then
                if countryball.onGround then
                    countryball.velocityY = countryball.jumpPower
                    countryball.onGround = false
                end
            end
        end
    end
    local len = sqrt(moveX*moveX + moveZ*moveZ)
    local moving = len > 0

    local tile = nil
    if getTileAt then
        tile = getTileAt(countryball.x, countryball.z)
    end

    local isWater = false
    if tile and materials then
        if tile.texture == materials.waterDeep or tile.texture == materials.waterMedium or tile.texture == materials.waterSmall then
            isWater = true
        end
    end

    if isWater and not countryball.inWater then
        countryball.inWater = true
        countryball.velocityY = countryball.velocityY * 0.35
    elseif (not isWater) and countryball.inWater then
        countryball.inWater = false
    end

    if countryball.inWater then
        countryball.gravity = -6
    else
        countryball.gravity = -18
    end

    local moveSpeed = countryball.speed
    if countryball.inWater then
        moveSpeed = moveSpeed * 0.45
        dx = dx * 0.9
        dz = dz * 0.9
    end

    if moving then
        countryball.animation = "walk"
    elseif countryball.isDamaged then
        countryball.animation = "damage"
        countryball.x = countryball.x + countryball.damageVelocityX
        countryball.z = countryball.z + countryball.damageVelocityZ
        countryball.damageVelocityX = countryball.damageVelocityX * (1 - dt * 6)
        countryball.damageVelocityZ = countryball.damageVelocityZ * (1 - dt * 6)
        countryball.damageTimer = countryball.damageTimer + dt
        if countryball.damageTimer >= countryball.damageDuration and countryball.onGround then
            countryball.isDamaged = false
            countryball.damageVelocityX = 0
            countryball.damageVelocityZ = 0
            countryball.animation = "idle"
        end
    else
        countryball.animation = "idle"
    end
    countryball.x = countryball.x + dx
    countryball.z = countryball.z + dz

    if moving then
        moveX, moveZ = moveX / len, moveZ / len
        countryball.x = countryball.x + moveX * moveSpeed * dt
        countryball.z = countryball.z + moveZ * moveSpeed * dt
    end

    if countryball.inWater and tile then
        local surfaceY = tile.height + 0.5
        countryball.bobTimer = (countryball.bobTimer or 0) + dt
        local bob = math.sin(countryball.bobTimer * 2.0) * 0.08
        local targetY = surfaceY + bob
        local pullStrength = 3.0
        local diff = targetY - countryball.y
        countryball.y = countryball.y + diff * math.min(1, pullStrength * dt)
        countryball.velocityY = countryball.velocityY * (1 - math.min(0.9, 3.0 * dt))
    else
        countryball.bobTimer = 0
    end

    if countryball.shakeTime > 0 then
        countryball.shakeTime = countryball.shakeTime - dt
    end
    countryball.currentFrame = getFrames(images, countryball.animation, dt, countryball)
end

function countryball.draw(drawWithStencil, Inventory, itemModule)
    local img = countryball.currentFrame or images.idle[1]
    if not img then return end

    local shakeX, shakeZ = 0, 0
    if countryball.shakeTime > 0 then
        local s = countryball.shakeStrength * (countryball.shakeTime / countryball.shakeDuration)
        shakeX = (math.random() * 2 - 1) * s
        shakeZ = (math.random() * 2 - 1) * s
    end

    drawWithStencil(countryball.x + shakeX, countryball.y, countryball.z + shakeZ, img, countryball.flip)

    local selected = Inventory:getSelected()
    if not selected or not selected.type then return end

    local itemImg = itemModule.getItemImage(selected.type)
    if not itemImg then return end

    local offsetX = countryball.flip and -0.5 or 0.5
    drawWithStencil(
        countryball.x + offsetX,
        countryball.y + 0.2,
        countryball.z + 0.1,
        itemImg,
        countryball.flip,
        0.35
    )
end

return countryball