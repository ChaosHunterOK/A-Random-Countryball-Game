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

local function easeInOutQuad(t) return t<0.5 and 2*t*t or -1+(4-2*t)*t end
local function easeInOutExpo(t)
    if t==0 then return 0 end
    if t==1 then return 1 end
    return t<0.5 and 2^(20*t-10)/2 or (2-2^(-20*t+10))/2
end

function Crafting:update(dt)
    if (self.open and self.anim<1) or (not self.open and self.anim>0) then
        self.timer = math.min(self.timer + dt, self.duration)
        local t = self.timer / self.duration
        self.anim = self.open and easeInOutQuad(t) or 1 - easeInOutQuad(t)
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
        local itemImg = items[self.craftedItem.type]
        if itemImg then
            local iw, ih = itemImg:getWidth(), itemImg:getHeight()
            local t = easeInOutExpo(self.anim)
            lg.draw(itemImg, outputX + barWidth/2, outputY + barHeight/2, 0, scale*t, scale*t, iw/2, ih/2)
            utils.drawTextWithBorder(self.craftedItem.count,outputX + 12 * scale,outputY + 8 * scale)
        end
    end

    if self.draggingSlot then
        local slot
        if self.slots[self.draggingSlot] then
            slot = self.slots[self.draggingSlot]
        elseif inventory.heldItem then
            slot = {
                type = inventory.heldItem,
                count = inventory.heldCount or 1,
                durability = inventory.heldDurability or (itemTypes[inventory.heldItem] and itemTypes[inventory.heldItem].durability)
            }
        else
            slot = nil
        end

        if slot and slot.type then
            local itemImg = itemTypes[slot.type] and itemTypes[slot.type].img
            if itemImg then
                local mx, my = love.mouse.getPosition()
                local scaleX = lg.getWidth()/1000
                local scaleY = lg.getHeight()/525
                local scale = math.min(scaleX, scaleY)
                lg.setColor(1,1,1,1)
                lg.draw(itemImg, mx - 16*scale, my - 16*scale, 0, scale, scale)
                utils.drawTextWithBorder(slot.count or 1, mx + 10*scale, my + 10*scale)
            end
        end
    end

    if self.hoveredItem and itemTypes[self.hoveredItem] then
        lg.setColor(0,0,0,0.7)
        local name = string.gsub(self.hoveredItem, "_", " ")
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

function Crafting:mousepressed(mx, my, button, inventory, itemTypes, itemsModule, countryball)
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
        local outType = self.craftedItem.type
        local outCount = self.craftedItem.count
        local maxDur = itemTypes[outType].durability or nil

        if inventory:hasFreeSlot() then
            inventory:add(outType, outCount, itemTypes)
            for i = inventory.maxSlots, 1, -1 do
                local slot = inventory.items[i]
                if slot and slot.type == outType then
                    slot.durability = maxDur
                    break
                end
            end
        else
            itemsModule.dropItem(countryball.x + 0.6,countryball.y + 0.5,countryball.z + 0.1,outType,outCount,maxDur)
        end

        for i = 1, 4 do
            local slots = self.slots[i]
            if slots then
                slots.count = slots.count - 1
                if slots.count <= 0 then
                    self.slots[i] = nil
                end
            end
        end

        love.audio.play(self.craftSound)
        self.craftedItem = self:checkRecipe()
        return
    end

    for i = 1, 4 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = startX + col * (barWidth + spacing)
        local y = startY + row * (barHeight + spacing)

        if mx >= x and mx <= x + barWidth and my >= y and my <= y + barHeight then
            local slot = self.slots[i]
            if slot and not inventory.heldItem then
                if button == 1 then
                    inventory.heldItem = slot.type
                    inventory.heldCount = slot.count
                    inventory.heldDurability = slot.durability
                    self.slots[i] = nil
                elseif button == 2 then
                    inventory.heldItem = slot.type
                    inventory.heldCount = 1
                    inventory.heldDurability = slot.durability
                    slot.count = slot.count - 1
                    if slot.count <= 0 then self.slots[i] = nil end
                end
                self.draggingSlot = i
                return
            elseif inventory.heldItem then
                local stackLimit = itemTypes[inventory.heldItem].stack or 1
                if not slot then
                    if button == 1 then
                        self.slots[i] = {type = inventory.heldItem, count = inventory.heldCount, durability = inventory.heldDurability}
                        inventory.heldItem, inventory.heldCount = nil, 0
                    elseif button == 2 then
                        self.slots[i] = { type = inventory.heldItem, count = 1, durability = inventory.heldDurability}
                        inventory.heldCount = inventory.heldCount - 1
                        if inventory.heldCount <= 0 then inventory.heldItem = nil end
                    end
                elseif slot.type == inventory.heldItem then
                    if button == 2 and slot.count < stackLimit then
                        slot.count = slot.count + 1
                        inventory.heldCount = inventory.heldCount - 1
                    elseif button == 1 then
                        local canTake = math.min(inventory.heldCount, stackLimit - slot.count)
                        slot.count = slot.count + canTake
                        inventory.heldCount = inventory.heldCount - canTake
                    end
                    if inventory.heldCount <= 0 then inventory.heldItem = nil end
                elseif button == 1 then
                    local temp = { type = slot.type, count = slot.count, durability = slot.durability }
                    self.slots[i] = {type = inventory.heldItem, count = inventory.heldCount, durability = inventory.heldDurability}
                    inventory.heldItem = temp.type
                    inventory.heldCount = temp.count
                    inventory.heldDurability = temp.durability
                end
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
        if match then
            return recipe.output
        end
    end
    return nil
end

return Crafting