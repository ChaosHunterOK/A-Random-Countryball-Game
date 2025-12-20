local love = require("love")
local lg = love.graphics
local utils = require("source.utils")
local countryball = require("source.countryball")
local base_width, base_height = 1000, 525
local stage = lg.newImage("image/stage.png")

local SkinsMenu = {
    skins = {"default"}, 
    selected = 1,
    loadedSkinName = "countryball",
}

SkinsMenu.selectedIndex = 1
SkinsMenu.scrollOffset = 0
SkinsMenu.visibleRows = 8
SkinsMenu.itemSpacing = 60

local SKIN_FOLDER = "skins"
love.filesystem.createDirectory(SKIN_FOLDER)

function SkinsMenu.load()
    SkinsMenu.skins = {"default"}
    local entries = love.filesystem.getDirectoryItems(SKIN_FOLDER)

    for _, folder in ipairs(entries) do
        local full = SKIN_FOLDER .. "/" .. folder
        if love.filesystem.getInfo(full, "directory") then
            table.insert(SkinsMenu.skins, folder)
        end
    end

    table.sort(SkinsMenu.skins, function(a, b)
        if a == "default" then return true end
        if b == "default" then return false end
        return a < b
    end)
end

function SkinsMenu.applySkin(name)
    if name == "default" then
        name = "countryball"
    end

    SkinsMenu.loadedSkinName = name

    local path = SKIN_FOLDER .. "/" .. name .. "/"
    local defaultPath = "image/countryball/senegal/"
    if not love.filesystem.getInfo(path, "directory") then
        path = defaultPath
    end

    countryball.images = {
        idle = {
            SkinsMenu.tryImage(path.."idle1.png", defaultPath.."idle1.png"),
            SkinsMenu.tryImage(path.."idle2.png", defaultPath.."idle2.png")
        },
        walk = {
            SkinsMenu.tryImage(path.."walk1.png", defaultPath.."walk1.png"),
            SkinsMenu.tryImage(path.."walk2.png", defaultPath.."walk2.png"),
            SkinsMenu.tryImage(path.."walk3.png", defaultPath.."walk3.png"),
            SkinsMenu.tryImage(path.."walk4.png", defaultPath.."walk4.png"),
            SkinsMenu.tryImage(path.."walk5.png", defaultPath.."walk5.png")
        },
        damage = {
            SkinsMenu.tryImage(path.."damage.png", defaultPath.."damage.png")
        }
    }
end

function SkinsMenu.tryImage(path, fallback)
    if love.filesystem.getInfo(path) then
        return lg.newImage(path)
    end
    return lg.newImage(fallback)
end

function SkinsMenu:draw()
    local spacing = self.itemSpacing
    local startY = 100
    local screenW = love.graphics.getWidth()
    lg.draw(stage, base_width - 355, base_height / 1.7, 0, 2, 2)
    countryball.viewDraw(base_width - 120, base_height / 2.5, -1, 2)
    utils.drawTextWithBorder("SKINS", base_width/2 - 40, 40)

    for i, s in ipairs(self.skins) do
        local drawIndex = i - self.scrollOffset
        if drawIndex >= 1 and drawIndex <= self.visibleRows then
            local y = startY + (drawIndex-1) * spacing
            local col = i == self.selected and {1,1,0} or {1,1,1}

            local label = (s == "default") and "Senegal (Default)" or s
            utils.drawTextWithBorder(label, 25, y, screenW, "left", {0,0,0}, col)
        end
    end

    lg.setColor(1,1,1)
end

function SkinsMenu:keypressed(key)
    if self.selectedIndex - 1 < self.scrollOffset then
        self.scrollOffset = self.selectedIndex - 1
    elseif self.selectedIndex > self.scrollOffset + self.visibleRows then
        self.scrollOffset = self.selectedIndex - self.visibleRows
    end

    if self.scrollOffset < 0 then self.scrollOffset = 0 end
    if key == "down" then
        self.selected = self.selected + 1
        if self.selected > #self.skins then self.selected = 1 end
    elseif key == "up" then
        self.selected = self.selected - 1
        if self.selected < 1 then self.selected = #self.skins end
    elseif key == "return" then
        SkinsMenu.applySkin(self.skins[self.selected])
    end
end

return SkinsMenu