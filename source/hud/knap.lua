local love = require "love"
local lg = love.graphics
local knapping_recipes = require("source.hud.recipes.knapping")
local Progression = require("source.progression")
local tweens = require("source.utils.tweens")

local Knap = {}

Knap.open = false
Knap.anim = 0
Knap.timer = 0
Knap.duration = 0.525
Knap.bgAlpha = 0
Knap.gridSize = 25
Knap.slots = {}
Knap.craftedItem = nil
Knap.invBar = lg.newImage("image/bar/inv.png")
Knap.stoneSlot = lg.newImage("image/bar/stone.png")
Knap.outputBar = lg.newImage("image/bar/give.png")
Knap.recipes = knapping_recipes.recipes

function Knap:animateToOpen(open)
    tweens.cancelProperty(self, "anim")
    tweens.cancelProperty(self, "bgAlpha")
    self.timer = 0
    tweens.to(self, "anim", open and 1 or 0, self.duration, tweens.easeInOutQuad)
    tweens.to(self, "bgAlpha", open and 0.25 or 0, self.duration, tweens.easeInOutQuad)
end

function Knap:resetGrid()
    for i = 1, 25 do
        self.slots[i] = true
    end
end

function Knap:toggle()
    self.open = not self.open
    self:animateToOpen(self.open)

    if self.open then
        self:resetGrid()
    end
end

function Knap:update(dt)
    self.craftedItem = self:checkRecipe()
end

function Knap:draw(inventory, itemTypes)
    if self.anim <= 0 then return end

    local scale = math.min(lg.getWidth()/1000, lg.getHeight()/525)

    lg.setColor(0,0,0, self.bgAlpha)
    lg.rectangle("fill", 0, 0, lg.getWidth(), lg.getHeight())

    local slotW = self.invBar:getWidth() * scale
    local slotH = self.invBar:getHeight() * scale
    local spacing = 4 * scale

    local gridWidth = 5 * slotW + 4 * spacing
    local startX = (lg.getWidth() - gridWidth) / 2
    local startY = lg.getHeight()/2 + 555 * (1 - self.anim) - (gridWidth/2)

    for i = 1, 25 do
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        local x = startX + col*(slotW + spacing)
        local y = startY + row*(slotH + spacing)

        lg.setColor(1,1,1,1)
        lg.draw(self.invBar, x, y, 0, scale, scale)
        if self.slots[i] == true then
            lg.draw(self.stoneSlot, x, y, 0, scale, scale)
        end
    end

    local outputX = startX + gridWidth + spacing * 6
    local outputY = startY + gridWidth / 2 - slotH/2

    lg.draw(self.outputBar, outputX, outputY, 0, scale, scale)

    if self.craftedItem then
        local itemImg = itemTypes[self.craftedItem].img
        local t = tweens.easeInOutQuad(self.anim)
        lg.draw(itemImg, outputX + slotW/2, outputY + slotH/2,0, scale*t, scale*t, itemImg:getWidth()/2, itemImg:getHeight()/2)
    end
end

function Knap:mousepressed(mx, my, btn, inventory, itemTypes, ItemsModule, countryball)
    if btn ~= 1 or not self.open then return end

    local scale = math.min(lg.getWidth()/1000, lg.getHeight()/525)
    local slotW = self.stoneSlot:getWidth() * scale
    local slotH = self.stoneSlot:getHeight() * scale
    local spacing = 4 * scale

    local gridWidth = 5 * slotW + 4 * spacing
    local startX = (lg.getWidth() - gridWidth) / 2
    local startY = lg.getHeight()/2 + 555 * (1 - self.anim) - (gridWidth/2)
    local outputX = startX + gridWidth + spacing * 6
    local outputY = startY + gridWidth / 2 - slotH/2
    if self.craftedItem and
       mx >= outputX and mx <= outputX + slotW and
       my >= outputY and my <= outputY + slotH then

        if inventory:hasFreeSlot() then
            inventory:add(self.craftedItem, 1, itemTypes)
        else
            ItemsModule.dropItem(countryball.x + 0.6, countryball.y + 0.5, countryball.z + 0.1, self.craftedItem, 1)
        end
        Progression:trackItemCrafted(self.craftedItem, itemTypes)
        self:toggle()
        self:resetGrid()
        self.craftedItem = nil
        return
    end
    for i = 1, 25 do
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        local x = startX + col*(slotW + spacing)
        local y = startY + row*(slotH + spacing)

        if mx >= x and mx <= x + slotW and
           my >= y and my <= y + slotH then

            if self.slots[i] then
                self.slots[i] = nil
            end
            return
        end
    end
end

function Knap:checkRecipe()
    for _, recipe in ipairs(self.recipes) do
        local ok = true

        for i = 1, 25 do
            local req = recipe.input[i]
            local slot = self.slots[i]

            if req == "stone" and slot ~= true then ok = false break end
            if req == nil and slot ~= nil then ok = false break end
        end

        if ok then return recipe.output end
    end

    return nil
end

return Knap