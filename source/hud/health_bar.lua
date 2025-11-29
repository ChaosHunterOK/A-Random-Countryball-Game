local love = require "love"
local lg = love.graphics
local countryball = require "source.countryball"
local utils = require("source.utils")

local healthBar = {
    health = countryball.health or 5,
    maxHealth = countryball.maxHealth or 5,
    heart = lg.newImage("image/bar/heart.png"),
    gold_heart = lg.newImage("image/bar/gold_heart.png"),
    heart_damaged = lg.newImage("image/bar/heart_damage.png"),
    bar = lg.newImage("image/bar/bar.png"),
    x = 20,
    y = 20,
    damageTimer = 0,
    damageFlash = 0,
    shakeTimer = 0,
    heartbeatTimer = 0,
    heartbeatDuration = 10,
    heartbeatDelay = 0.3,
    timeSinceLastBeat = 0,
    heartbeatIntensity = 0,
    heartbeatActive = true,
    lastHealth = nil,
}

function healthBar:setHealth(value)
    value = math.max(0, math.min(value, self.maxHealth))

    if value ~= self.lastHealth then
        self.damageTimer = 0.3
        self.damageFlash = 1
        self.shakeTimer = 0.2
        self.heartbeatTimer = self.heartbeatDuration
        self.timeSinceLastBeat = 0
        self.heartbeatActive = true
    end

    self.health = value
    self.lastHealth = value
end

function healthBar:damageHealth(amount)
    if amount <= 0 then return end
    self:setHealth(self.health - amount)
    countryball:takeDamage(amount)
end

function healthBar:update(dt)
    if self.damageTimer > 0 then
        self.damageTimer = self.damageTimer - dt
        self.damageFlash = math.max(0, self.damageFlash - dt * 3)
    end

    if self.shakeTimer > 0 then
        self.shakeTimer = self.shakeTimer - dt
    end

    if self.heartbeatActive then
        self.heartbeatTimer = self.heartbeatTimer - dt
        self.timeSinceLastBeat = self.timeSinceLastBeat + dt
        if self.heartbeatTimer <= 0 then
            self.heartbeatActive = false
        end
    else
        self.heartbeatIntensity = math.max(0, self.heartbeatIntensity - dt * 0.5)
    end

    local target = self.heartbeatActive and 1 or 0
    self.heartbeatIntensity = self.heartbeatIntensity + (target - self.heartbeatIntensity) * dt * 4
end

function healthBar:getHeartScale(index)
    if self.heartbeatIntensity <= 0 then return 1 end

    local beatCycle = (self.timeSinceLastBeat - (index - 1) * self.heartbeatDelay)
    if beatCycle < 0 then return 1 end

    local beatTime = beatCycle % (self.maxHealth * self.heartbeatDelay)
    local pulse = math.sin(math.min(beatTime * math.pi * 2, math.pi))
    return 1 + pulse * 0.1 * self.heartbeatIntensity
end

function hsvToRgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0

    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end

    return r + m, g + m, b + m
end

function healthBar:draw()
    local scaleX = lg.getWidth() / 1000
    local scaleY = lg.getHeight() / 525
    local scale = math.min(scaleX, scaleY)
    local barWidth = self.heart:getWidth() * scale
    local spacing = 8 * scale
    local startX = 10 * scale
    local shakeOffsetX, shakeOffsetY = 0, 0

    if self.shakeTimer > 0 then
        local intensity = 3 * (self.shakeTimer / 0.2)
        shakeOffsetX = (math.random() - 0.5) * intensity
        shakeOffsetY = (math.random() - 0.5) * intensity
    end

    for i = 1, self.maxHealth do
        local x = startX + (i-1) * (barWidth + spacing)
        local img = (i <= self.health) and self.heart or self.heart_damaged
        local heartScale = self:getHeartScale(i) * scale

        lg.setColor(1, 1, 1)
        lg.draw(self.bar, x + shakeOffsetX, self.y + shakeOffsetY, 0, scale, scale)

        if i > self.health and self.damageFlash > 0 then
            lg.setColor(1, 1 - self.damageFlash, 1 - self.damageFlash)
        else
            lg.setColor(1, 1, 1)
        end

        local ox = self.heart:getWidth() / 2
        local oy = self.heart:getHeight() / 2
        lg.draw(img, x + ox * scale + shakeOffsetX, self.y + oy * scale + shakeOffsetY, 0, heartScale, heartScale, ox, oy)
    end

    if self.health > self.maxHealth then
        for i = self.maxHealth + 1, self.health do
            local x = startX + (i-1) * (barWidth + spacing)
            local img = self.gold_heart
            local ox = self.heart:getWidth() / 2
            local oy = self.heart:getHeight() / 2
            lg.draw(img, x + ox * scale + shakeOffsetX, self.y + oy * scale + shakeOffsetY, 0, scale, scale, ox, oy)
        end
    end

    lg.setColor(1, 1, 1)
end

return healthBar
