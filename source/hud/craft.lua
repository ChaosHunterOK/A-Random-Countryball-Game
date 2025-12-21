local love = require "love"
local lg = love.graphics
local crafting_recipes = require("source.hud.crafting_recipes")
local utils = require("source.utils")
local Crafting = {}
Crafting.open = false
Crafting.anim = 0
Crafting.timer = 0
Crafting.duration = 0.525
Crafting.bgAlpha = 0
Crafting.slots = {nil, nil, nil, nil}
Crafting.craftedItem = nil
Crafting.invBar = lg.newImage("image/bar/inv.png")
Crafting.outputBar = lg.newImage("image/bar/give.png")
Crafting.recipes = crafting_recipes.recipes
Crafting.draggingSlot = nil
Crafting.hoveredItem = nil
Crafting.previewItem = nil
Crafting.craftSound = love.audio.newSource("sounds/craft.ogg", "static")

local function easeInOutQuad(t)
    if t < 0.5 then return 2*t*t end
    return -1 + (4 - 2*t)*t
end
local function easeInOutExpo(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    if t < 0.5 then return 2^(20*t-10)/2 end
    return (2 - 2^(-20*t+10))/2
end

function Crafting:update(dt)
    if self.open and self.anim < 1 then
        self.timer = math.min(self.timer + dt, self.duration)
        local t = self.timer / self.duration
        self.anim = easeInOutQuad(t)
        self.bgAlpha = 0.25 * self.anim
    elseif not self.open and self.anim > 0 then
        self.timer = math.min(self.timer + dt, self.duration)
        local t = self.timer / self.duration
        self.anim = 1 - easeInOutQuad(t)
        self.bgAlpha = 0.25 * self.anim
    end

    self.craftedItem = self:checkRecipe()
end

function Crafting:draw(inventory, itemTypes, items)
    if self.anim <= 0 then return end
    local scaleX = lg.getWidth()/1000
    local scaleY = lg.getHeight()/525
    local scale = math.min(scaleX, scaleY)

    lg.setColor(0,0,0,self.bgAlpha)
    lg.rectangle("fill", 0,0, lg.getWidth(), lg.getHeight())

    local barWidth, barHeight = self.invBar:getWidth()*scale, self.invBar:getHeight()*scale
    local spacing = 8*scale
    local totalWidth = (barWidth + spacing)*2
    local startX = (lg.getWidth()-totalWidth)/2
    local startY = lg.getHeight()/2 + 355*(1-self.anim) - 100

    local mx, my = love.mouse.getPosition()
    self.hoveredItem = nil

    for i = 1, 4 do
        local col = (i-1)%2
        local row = math.floor((i-1)/2)
        local x = startX + col*(barWidth+spacing)
        local y = startY + row*(barHeight+spacing)
        local slot = self.slots[i]

        lg.setColor(1,1,1,1)
        lg.draw(self.invBar, x, y, 0, scale, scale)

        if slot and slot.type then
            local itemImg = itemTypes[slot.type].img
            local iw, ih = itemImg:getWidth(), itemImg:getHeight()
            lg.draw(itemImg, x + (barWidth-iw*scale)/2, y + (barHeight-ih*scale)/2, 0, scale, scale)
            lg.setColor(1,1,1,1)
            utils.drawTextWithBorder(slot.count, x + 16*scale, y + 8*scale)

            if slot.durability and itemTypes[slot.type].durability then
                local maxDur = itemTypes[slot.type].durability
                local ratio = math.max(0, slot.durability / maxDur)

                local barW = barWidth - 12 * scale
                local barH = 6 * scale
                local bx = x + 6 * scale
                local by = y + barHeight - barH - 6 * scale

                lg.setColor(0,0,0,1)
                lg.rectangle("fill", bx, by, barW, barH)
                lg.setColor(1 - ratio, ratio, 0)
                lg.rectangle("fill", bx + 1*scale, by + 1*scale, (barW - 2*scale) * ratio, barH - 2*scale)

                lg.setColor(1,1,1,1)
            end
        end

        if mx >= x and mx <= x + barWidth and my >= y and my <= y + barHeight and slot then
            self.hoveredItem = slot.type
        end
    end

    local outputX = startX + totalWidth + spacing*2
    local outputY = startY + (barHeight + spacing)/2
    lg.setColor(1,1,1,1)
    lg.draw(self.outputBar, outputX, outputY, 0, scale, scale)

    if self.craftedItem then
        local itemImg = items[self.craftedItem]
        if itemImg then
            local iw, ih = itemImg:getWidth(), itemImg:getHeight()
            local t = easeInOutExpo(self.anim)
            lg.draw(itemImg, outputX + barWidth/2, outputY + barHeight/2, 0, scale*t, scale*t, iw/2, ih/2)
        end
    end

    if self.draggingSlot then
        local slot = self.slots[self.draggingSlot] or {type=inventory.heldItem, count=inventory.heldCount, durability = inventory.heldDurability or itemTypes[inventory.heldItem].durability}
        if slot and slot.type then
            local itemImg = itemTypes[slot.type] and itemTypes[slot.type].img
            if itemImg then
                lg.setColor(1,1,1,1)
                lg.draw(itemImg, mx - 16*scale, my - 16*scale, 0, scale, scale)
                utils.drawTextWithBorder(slot.count or 1, mx + 10*scale, my + 10*scale)
            end
        end
    end

    if self.hoveredItem and itemTypes[self.hoveredItem] then
        lg.setColor(0,0,0,0.7)
        local name = self.hoveredItem
        local w = lg.getFont():getWidth(name) + 10
        local h = lg.getFont():getHeight() + 6
        lg.rectangle("fill", mx + 8, my - h - 8, w, h)
        lg.setColor(1,1,1,1)
        utils.drawTextWithBorder(name, mx + 12, my - h - 4)
    end
end

function Crafting:toggle()
    self.open = not self.open
    self.timer = 0
end

function Crafting:mousepressed(mx, my, button, inventory, itemTypes, itemsModule)
    local scaleX = lg.getWidth() / 1000
    local scaleY = lg.getHeight() / 525
    local scale = math.min(scaleX, scaleY)
    local barWidth, barHeight = self.invBar:getWidth() * scale, self.invBar:getHeight() * scale
    local spacing = 8 * scale
    local totalWidth = (barWidth + spacing) * 2
    local startX = (lg.getWidth() - totalWidth) / 2
    local startY = lg.getHeight() / 2 + 355 * (1 - self.anim) - 100
    local outputX = startX + totalWidth + spacing * 2
    local outputY = startY + (barHeight + spacing) / 2

    if (button == 1 or button == 2) and self.craftedItem and mx >= outputX and mx <= outputX + barWidth and my >= outputY and my <= outputY + barHeight then
        if inventory:hasFreeSlot() then
            local maxDur = itemTypes[self.craftedItem].durability

            inventory:add(self.craftedItem, 1, itemTypes)
            for i = inventory.maxSlots, 1, -1 do
                local slot = inventory.items[i]
                if slot and slot.type == self.craftedItem then
                    slot.durability = maxDur
                    break
                end
            end

            for i = 1, 4 do
                local slot = self.slots[i]
                if slot then
                    slot.count = slot.count - 1
                    if slot.count <= 0 then
                        self.slots[i] = nil
                    end
                end
            end

            love.audio.play(self.craftSound)
            self.craftedItem = self:checkRecipe()
        end
        return
    end

    for i = 1, 4 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = startX + col * (barWidth + spacing)
        local y = startY + row * (barHeight + spacing)
        local slot = self.slots[i]

        if mx >= x and mx <= x + barWidth and my >= y and my <= y + barHeight then
            if slot and slot.count then
                if not inventory.heldItem then
                    if button == 1 then
                        self.slots[i] = nil
                        inventory.heldItem = slot.type
                        inventory.heldCount = slot.count
                        self.draggingSlot = nil
                        self.isDragging = false
                    elseif button == 2 then
                        inventory.heldItem = slot.type
                        inventory.heldCount = 1
                        slot.count = slot.count - 1
                        if slot.count <= 0 then self.slots[i] = nil end
                    end
                    self.draggingSlot = i
                    self.isDragging = true
                    return
                end
                if inventory.heldItem == slot.type then
                    local stackLimit = itemTypes[slot.type].stack or 1
                    if button == 2 then
                        if slot.count < stackLimit then
                            slot.count = slot.count + 1
                            inventory.heldCount = inventory.heldCount - 1
                            if inventory.heldCount <= 0 then
                                inventory.heldItem = nil
                                inventory.heldCount = 0
                            end
                        end
                        return
                    elseif button == 1 then
                        local canTake = math.min(inventory.heldCount, stackLimit - slot.count)
                        slot.count = slot.count + canTake
                        inventory.heldCount = inventory.heldCount - canTake
                        if inventory.heldCount <= 0 then
                            inventory.heldItem = nil
                            inventory.heldCount = 0
                        end
                        return
                    end
                else
                    local prev = { type = slot.type, count = slot.count }
                    self.slots[i] = { type = inventory.heldItem, count = inventory.heldCount }
                    inventory.heldItem = prev.type
                    inventory.heldCount = prev.count
                    self.draggingSlot = i
                    return
                end
            else
                if inventory.heldItem then
                    local stackLimit = itemTypes[inventory.heldItem].stack or 1
                    if button == 1 then
                        local toPlace = math.min(inventory.heldCount, stackLimit)
                        self.slots[i] = { type = inventory.heldItem, count = toPlace }
                        inventory.heldCount = inventory.heldCount - toPlace
                        if inventory.heldCount <= 0 then
                            inventory.heldItem = nil
                            inventory.heldCount = 0
                        end
                    elseif button == 2 then
                        self.slots[i] = { type = inventory.heldItem, count = 1 }
                        inventory.heldCount = inventory.heldCount - 1
                        if inventory.heldCount <= 0 then
                            inventory.heldItem = nil
                            inventory.heldCount = 0
                        end
                    end
                    return
                end
            end

            if inventory.heldItem and self.draggingSlot == i then
                return
            end
        end
    end
end

function Crafting:mousereleased(_, _, button)
    if button == 1 then
        self.draggingSlot = nil
        self.isDragging = false
    end
end

function Crafting:checkRecipe()
    for _, recipe in ipairs(self.recipes) do
        local match = true
        for i = 1, 4 do
            local slot = self.slots[i]
            local required = recipe.input[i]
            if (required and (not slot or slot.type ~= required)) or (not required and slot) then
                match = false
                break
            end
        end
        if match then return recipe.output end
    end
    return nil
end

return Crafting