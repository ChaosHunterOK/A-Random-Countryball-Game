local love = require("love")
local lg = love.graphics
local utils = require("source.utils.utils")
local tweens = require("source.utils.tweens")
local countryball = require("source.countryball")
local base_width, base_height = 1000, 525
local stage = lg.newImage("image/stage.png")

local SkinsMenu = {
    skins = {"default", "remake"},
    selected = 1,
    loadedSkinName = "countryball",
    animStates = {},
    ejectingSkin = nil,
    scrollOffset = 0,
    visibleRows = 8,
    itemSpacing = 60
}

local expEase = tweens.expEase

local SKIN_FOLDER = "skins"
love.filesystem.createDirectory(SKIN_FOLDER)

function SkinsMenu.load()
    SkinsMenu.skins = {"default", "remake"}
    local entries = love.filesystem.getDirectoryItems(SKIN_FOLDER)

    for _, folder in ipairs(entries) do
        local full = SKIN_FOLDER .. "/" .. folder
        if love.filesystem.getInfo(full, "directory") then
            if folder ~= "default" and folder ~= "remake" then
                table.insert(SkinsMenu.skins, folder)
            end
        end
    end

    table.sort(SkinsMenu.skins, function(a, b)
        if a == "default" then return true end
        if b == "default" then return false end
        if a == "remake" then return true end
        if b == "remake" then return false end
        return a < b
    end)

    SkinsMenu.animStates = {}
    for i = 1, #SkinsMenu.skins do
        SkinsMenu.animStates[i] = { offset = 0, pulse = 0 }
    end
    
    SkinsMenu.selected = 1
    SkinsMenu.scrollOffset = 0
end

function SkinsMenu:update(dt)
    for i = 1, #self.skins do
        local anim = self.animStates[i]
        if anim then
            local target = (i == self.selected) and 20 or 0
            anim.offset = expEase(anim.offset, target, 10, dt)
            anim.pulse = anim.pulse + dt * ((i == self.selected) and 6 or 2)
        end
    end
    if self.ejectingSkin then
        local e = self.ejectingSkin
        if e then
            e.vy = (e.vy or 0) + (e.gravity or 0) * dt
            e.x = (e.x or 0) + (e.vx or 0) * dt
            e.y = (e.y or 0) + (e.vy or 0) * dt
            e.angle = (e.angle or 0) + (e.vr or 0) * dt
            if e.y > love.graphics.getHeight() + 100 then
                self.ejectingSkin = nil
            end
        end
    end
end

function SkinsMenu.tryImage(path, fallback)
    if love.filesystem.getInfo(path) then return lg.newImage(path) end
    return lg.newImage(fallback)
end

function SkinsMenu.applySkin(name)
    if countryball.images and countryball.images.idle and countryball.images.idle[1] then
        SkinsMenu.ejectingSkin = {
            img = countryball.images.idle[1],
            x = base_width - 120,
            y = base_height / 2.5,
            vx = 100,
            vy = -600,
            angle = 0,
            vr = 5,
            gravity = 1200
        }
    end

    if name == "default" then
        name = "countryball"
    end

    SkinsMenu.loadedSkinName = name
    countryball.images = countryball.getSkinImages(name)
end

function SkinsMenu:draw()
    local spacing = self.itemSpacing
    local startY = 100
    local screenW = love.graphics.getWidth()
    
    lg.draw(stage, base_width - 355, base_height / 1.7, 0, 2, 2)
    countryball.viewDraw(base_width - 120, base_height / 2.5, -1, 2)

    if self.ejectingSkin then
        local e = self.ejectingSkin
        if e and e.img then
            lg.setColor(1, 1, 1, 1)
            lg.draw(e.img, e.x, e.y, e.angle, -2, 2, e.img:getWidth()/2, e.img:getHeight()/2)
        end
    end
    
    utils.drawTextWithBorder("SKINS", base_width/2 - 40, 40)

    for i, s in ipairs(self.skins) do
        local drawIndex = i - self.scrollOffset
        if drawIndex >= 1 and drawIndex <= self.visibleRows then
            local anim = self.animStates[i]
            local y = startY + (drawIndex-1) * spacing
            local x = 25 + (anim and anim.offset or 0)
            local col = (i == self.selected) and {1, 1, 0} or {1, 1, 1}
            local label = (s == "default") and "Senegal (Default)" or (s == "remake") and "Senegal Remake" or s

            lg.push()
            utils.drawTextWithBorder(label, x, y, screenW, "left", {0, 0, 0}, col)
            lg.pop()
        end
    end

    lg.setColor(1, 1, 1)
end

function SkinsMenu:keypressed(key)
    if key == "down" then
        self.selected = self.selected + 1
        if self.selected > #self.skins then self.selected = 1 end
    elseif key == "up" then
        self.selected = self.selected - 1
        if self.selected < 1 then self.selected = #self.skins end
    elseif key == "return" then
        SkinsMenu.applySkin(self.skins[self.selected])
    end
    if self.selected - 1 < self.scrollOffset then
        self.scrollOffset = self.selected - 1
    elseif self.selected > self.scrollOffset + self.visibleRows then
        self.scrollOffset = self.selected - self.visibleRows
    end

    if self.scrollOffset < 0 then 
        self.scrollOffset = 0 
    end
end

return SkinsMenu