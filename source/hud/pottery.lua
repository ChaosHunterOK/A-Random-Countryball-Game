local love = require "love"
local lg = love.graphics
local Potteryping_recipes = require("source.hud.pottery_recipes")

local Pottery = {}

Pottery.open = false
Pottery.anim = 0
Pottery.timer = 0
Pottery.duration = 0.525
Pottery.bgAlpha = 0
Pottery.gridSize = 25
Pottery.slots = {}
Pottery.craftedItem = nil
Pottery.invBar = lg.newImage("image/bar/inv.png")
Pottery.claySlot = lg.newImage("image/bar/clay.png")
Pottery.outputBar = lg.newImage("image/bar/give.png")
Pottery.recipes = Potteryping_recipes.recipes

local function easeInOutQuad(t) return t<0.5 and 2*t*t or -1+(4-2*t)*t end

function Pottery:resetGrid()
    for i = 1, 25 do
        self.slots[i] = true
    end
end

function Pottery:toggle()
    self.open = not self.open
    self.timer = 0

    if self.open then
        self:resetGrid()
    end
end

function Pottery:update(dt)
    if self.open and self.anim < 1 then
        self.timer = math.min(self.timer + dt, self.duration)
        self.anim = easeInOutQuad(self.timer / self.duration)
        self.bgAlpha = 0.25 * self.anim
    elseif not self.open and self.anim > 0 then
        self.timer = math.min(self.timer + dt, self.duration)
        self.anim = 1 - easeInOutQuad(self.timer / self.duration)
        self.bgAlpha = 0.25 * self.anim
    end

    self.craftedItem = self:checkRecipe()
end

function Pottery:draw(inventory, itemTypes)
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
            lg.draw(self.claySlot, x, y, 0, scale, scale)
        end
    end

    local outputX = startX + gridWidth + spacing * 6
    local outputY = startY + gridWidth / 2 - slotH/2

    lg.draw(self.outputBar, outputX, outputY, 0, scale, scale)

    if self.craftedItem then
        local itemImg = itemTypes[self.craftedItem].img
        local t = easeInOutQuad(self.anim)
        lg.draw(itemImg, outputX + slotW/2, outputY + slotH/2,0, scale*t, scale*t, itemImg:getWidth()/2, itemImg:getHeight()/2)
    end
end

function Pottery:mousepressed(mx, my, btn, inventory, itemTypes, ItemsModule, countryball)
    if btn ~= 1 or not self.open then return end

    local scale = math.min(lg.getWidth()/1000, lg.getHeight()/525)
    local slotW = self.claySlot:getWidth() * scale
    local slotH = self.claySlot:getHeight() * scale
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
        Pottery.open = false
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

function Pottery:checkRecipe()
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

return Pottery