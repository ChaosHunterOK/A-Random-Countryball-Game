local love = require "love"
local lg = love.graphics
local countryball = require "source.countryball"
local utils = require("source.utils")

local hungerBar = {
    hunger = countryball.hunger or 5,
    maxHunger = countryball.maxHunger or 5,
    food = lg.newImage("image/bar/food.png"),
    food_empty = lg.newImage("image/bar/food_empty.png"),
    x = 20,
    y = 115,
    scale = 0.5,
    shakeTimer = 0,
    changeFlash = 0,
    lastHunger = nil,
    bounceTimer = 0,
    bar = lg.newImage("image/bar/bar.png"),
}

function hungerBar:setHunger(value)
    value = math.max(0, math.min(value, self.maxHunger))
    if value ~= self.lastHunger then
        self.shakeTimer = 0.2
        self.changeFlash = 1
        self.lastHunger = value
    end

    self.hunger = value
    countryball.hunger = value
end

function hungerBar:update(dt)
    if self.lastHunger == nil then self.lastHunger = countryball.hunger end
    if countryball.hunger ~= self.hunger then
        self:setHunger(countryball.hunger)
    end
    if self.shakeTimer > 0 then
        self.shakeTimer = self.shakeTimer - dt
    end

    if self.changeFlash > 0 then
        self.changeFlash = math.max(0, self.changeFlash - dt * 3)
    end
    if self.hunger <= 1 then
        self.bounceTimer = self.bounceTimer + dt * 5
    else
        self.bounceTimer = 0
    end

    if countryball.hunger ~= self.hunger then
        self:setHunger(countryball.hunger)
    end
end

function hungerBar:draw()
    local scaleX = lg.getWidth() / 1000
    local scaleY = lg.getHeight() / 525
    local baseScale = math.min(scaleX, scaleY) * self.scale
    
    local iconWidth = self.food:getWidth() * baseScale
    local spacing = 4 * baseScale
    local startX = self.x * baseScale
    local currentY = self.y * scaleY

    local shakeOffsetX, shakeOffsetY = 0, 0
    if self.shakeTimer > 0 or self.hunger <= 1 then
        local intensity = (self.shakeTimer > 0) and 3 or 1
        shakeOffsetX = (math.random() - 0.5) * intensity
        shakeOffsetY = (math.random() - 0.5) * intensity
    end

    for i = 1, self.maxHunger do
        local x = startX + (i-1) * (iconWidth + spacing)
        local isFull = (i <= self.hunger)
        local img = isFull and self.food or self.food_empty
        lg.draw(self.bar, x, currentY, 0, baseScale, baseScale)
        if self.changeFlash > 0 then
            lg.setColor(1, 1 - self.changeFlash, 1 - self.changeFlash)
        else
            lg.setColor(1, 1, 1)
        end
        local ox = img:getWidth() / 2
        local oy = img:getHeight() / 2
        
        local bounce = (self.hunger <= 1 and isFull) and math.sin(self.bounceTimer) * 2 or 0
        
        lg.draw(img, x + ox * baseScale + shakeOffsetX, currentY + oy * baseScale + shakeOffsetY + bounce, 0, baseScale, baseScale, ox, oy)
    end

    lg.setColor(1, 1, 1)
end

return hungerBar