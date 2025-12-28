local love = require "love"
local lg = love.graphics
local utils = require("source.utils")

local Inventory = {}
Inventory.items = {}
Inventory.maxSlots = 4
Inventory.slotYOffsets = {}
Inventory.slotTargets = {}
Inventory.slotTimers = {}
Inventory.animDuration = 0.3
Inventory.selectedSlot = 1
Inventory.invBar = lg.newImage("image/bar/inv.png")
Inventory.heldItem = nil
Inventory.heldCount = 0
Inventory.heldDurability = nil
Inventory.dragging = false

for i = 1, Inventory.maxSlots do
    Inventory.items[i] = nil
    Inventory.slotYOffsets[i] = 0
    Inventory.slotTargets[i] = 0
    Inventory.slotTimers[i] = 0
end

local function easeInOutBack(t)
    local c1 = 1.70158
    local c2 = c1 * 1.525
    if t < 0.5 then
        return (2*t)^2 * ((c2 + 1)*2*t - c2) / 2
    else
        return ((2*t - 2)^2 * ((c2 + 1)*(2*t - 2) + c2) + 2) / 2
    end
end

function Inventory:canAddEvenIfFull(itemType, itemTypes)
    local stackLimit = itemTypes[itemType].stack or 1
    for i = 1, self.maxSlots do
        local slot = self.items[i]
        if slot and slot.type == itemType and slot.count < stackLimit then
            return true
        end
    end
    return false
end

function Inventory:add(itemType, amount, itemTypes, durability)
    amount = amount or 1
    local stackLimit = itemTypes[itemType].stack or 1
    for _, slot in ipairs(self.items) do
        if slot and slot.type == itemType then
            local toAdd = math.min(amount, stackLimit - slot.count)
            slot.count = slot.count + toAdd
            if durability then slot.durability = durability end
            amount = amount - toAdd
            if amount <= 0 then return true end
        end
    end

    if not self:hasFreeSlot() then return false end
    for i = 1, self.maxSlots do
        if not self.items[i] and amount > 0 then
            local toAdd = math.min(amount, stackLimit)
            self.items[i] = { type = itemType, count = toAdd, durability = durability or itemTypes[itemType].durability }
            amount = amount - toAdd
            if amount <= 0 then break end
        end
    end
    return true
end

function Inventory:update(dt)
    for i = 1, self.maxSlots do
        local target = self.slotTargets[i]
        local current = self.slotYOffsets[i]

        if math.abs(current - target) > 0.1 then
            local t = math.min(self.slotTimers[i] + dt, self.animDuration) / self.animDuration
            self.slotTimers[i] = self.slotTimers[i] + dt
            local eased = easeInOutBack(t)
            local startY = (target == -10) and 0 or -10
            self.slotYOffsets[i] = startY + (target - startY) * eased
        else
            self.slotYOffsets[i] = target
        end
    end
end

local function getScale()
    local scaleX = lg.getWidth() / 1000
    local scaleY = lg.getHeight() / 525
    local scale = math.min(scaleX, scaleY)
    return scale
end

function Inventory:draw(itemTypes)
    local scale = getScale()
    local barW, barH = self.invBar:getWidth()*scale, self.invBar:getHeight()*scale
    local spacing = 8 * scale
    local startX, startY = 10*scale, lg.getHeight() - barH - 10*scale

    for i = 1, self.maxSlots do
        local x, y = startX + (i-1)*(barW+spacing), startY + self.slotYOffsets[i]*scale
        lg.setColor(1,1,1,1)
        lg.draw(self.invBar, x, y, 0, scale, scale)

        local slot = self.items[i]
        if slot and slot.count > 0 then
            local img = itemTypes[slot.type].img
            local iw, ih = img:getWidth(), img:getHeight()
            lg.draw(img, x + (barW-iw*scale)/2, y + (barH-ih*scale)/2, 0, scale, scale)
            utils.drawTextWithBorder(tostring(slot.count), x+16*scale, y+8*scale)

            if slot.durability and itemTypes[slot.type].durability then
                local ratio = math.max(0, slot.durability / itemTypes[slot.type].durability)
                local bw, bh = barW-12*scale, 6*scale
                local bx, by = x+6*scale, y+barH-bh-6*scale
                lg.setColor(0,0,0)
                lg.rectangle("fill", bx, by, bw, bh)
                lg.setColor(1-ratio, ratio, 0)
                lg.rectangle("fill", bx+1*scale, by+1*scale, (bw-2*scale)*ratio, bh-2*scale)
                lg.setColor(1,1,1,1)
            end
        end
    end

    if self.heldItem then
        local mx, my = love.mouse.getPosition()
        local img = itemTypes[self.heldItem].img
        lg.setColor(1,1,1,1)
        lg.draw(img, mx-16*scale, my-16*scale, 0, scale, scale)
        utils.drawTextWithBorder(self.heldCount, mx+12*scale, my+12*scale)
    end
end

function Inventory:selectSlot(newSlot)
    if newSlot ~= self.selectedSlot and newSlot >= 1 and newSlot <= self.maxSlots then
        self.slotTimers[self.selectedSlot], self.slotTimers[newSlot] = 0, 0
        self.slotTargets[self.selectedSlot], self.slotTargets[newSlot] = 0, -10
        self.selectedSlot = newSlot
    end
end

function Inventory:getSelected()
    return self.items[self.selectedSlot]
end

function Inventory:hasFreeSlot()
    for i = 1, self.maxSlots do
        local slot = self.items[i]
        if not slot or slot.count <= 0 then return true end
    end
    return false
end

function Inventory:keypressed(key)
    local n = tonumber(key)
    if n and n >= 1 and n <= self.maxSlots then
        self:selectSlot(n)
    end
end

function Inventory:mousepressed(mx, my, button, itemTypes, crafting)
    local scale = getScale()
    local barWidth = self.invBar:getWidth() * scale
    local barHeight = self.invBar:getHeight() * scale
    local spacing = 8 * scale
    local startX = 10 * scale
    local startY = lg.getHeight() - barHeight - 10 * scale

    for i = 1, self.maxSlots do
        local x = startX + (i-1)*(barWidth + spacing)
        local y = startY + self.slotYOffsets[i]*scale
        if mx >= x and mx <= x+barWidth and my >= y and my <= y+barHeight then
            local slot = self.items[i]

            if not self.heldItem then
                if slot and slot.count > 0 then
                    if button == 1 then
                        self.heldItem = slot.type
                        self.heldCount = slot.count
                        self.heldDurability = slot.durability
                        self.items[i] = nil
                    elseif button == 2 then
                        self.heldItem = slot.type
                        self.heldCount = math.ceil(slot.count / 2)
                        self.heldDurability = slot.durability
                        slot.count = slot.count - self.heldCount
                        if slot.count <= 0 then self.items[i] = nil end
                    end
                    self.dragging = true
                end
            else
                if slot then
                    if slot.type == self.heldItem then
                        local stackLimit = itemTypes[slot.type].stack or 64
                        if button == 1 then
                            local canTake = math.min(self.heldCount, stackLimit - slot.count)
                            slot.count = slot.count + canTake
                            self.heldCount = self.heldCount - canTake
                            if self.heldCount <= 0 then self.heldItem = nil end
                        elseif button == 2 then
                            if slot.count < stackLimit then
                                slot.count = slot.count + 1
                                self.heldCount = self.heldCount - 1
                                if self.heldCount <= 0 then self.heldItem = nil end
                            end
                        end
                    else
                        --[[local prevType, prevCount, prevDurability = slot.type, slot.count, slot.durability
                        
                        self.items[i] = { 
                            type = self.heldItem,
                            count = self.heldCount, 
                            durability = self.heldDurability 
                        }
                        
                        self.heldItem = prevType
                        self.heldCount = prevCount
                        self.heldDurability = prevDurability]]
                    end
                else
                    local stackLimit = itemTypes[self.heldItem].stack or 64
                    if button == 1 then
                        self.items[i] = { type = self.heldItem, count = self.heldCount, durability = self.heldDurability }
                        self.heldItem = nil
                    elseif button == 2 then
                        self.items[i] = { type = self.heldItem, count = 1, durability = self.heldDurability }
                        self.heldCount = self.heldCount - 1
                        if self.heldCount <= 0 then self.heldItem = nil end
                    end
                end
            end
            break
        end
    end
end

function Inventory:mousereleased(mx, my, button, itemsModule, countryball, crafting)
    if button ~= 1 or not self.heldItem then return end

    local scaleX = lg.getWidth() / 1000
    local scaleY = lg.getHeight() / 525
    local scale = math.min(scaleX, scaleY)
    local barWidth = self.invBar:getWidth() * scale
    local barHeight = self.invBar:getHeight() * scale
    local spacing = 8 * scale
    local startX = 10 * scale
    local startY = lg.getHeight() - barHeight - 10 * scale
    local insideInventory = false

    for i = 1, self.maxSlots do
        local x = startX + (i-1)*(barWidth + spacing)
        local y = startY + self.slotYOffsets[i]*scale
        if mx >= x and mx <= x + barWidth and my >= y and my <= y+barHeight then
            insideInventory = true
            if self.items[i] and self.items[i].type == self.heldItem then
                local stackLimit = itemsModule and itemsModule.itemTypes and itemsModule.itemTypes[self.heldItem] and itemsModule.itemTypes[self.heldItem].stack or 64
                local available = stackLimit - self.items[i].count
                local toAdd = math.min(self.heldCount, available)
                self.items[i].count = self.items[i].count + toAdd
                self.heldCount = self.heldCount - toAdd
                if self.heldCount <= 0 then
                    self.heldItem = nil
                    self.heldCount = 0
                else
                    for j = 1, self.maxSlots do
                        if not self.items[j] then
                            local put = math.min(self.heldCount, stackLimit)
                            self.items[j] = { type = self.heldItem, count = put }
                            self.heldCount = self.heldCount - put
                            if self.heldCount <= 0 then break end
                        end
                    end
                end
            elseif not self.items[i] then
                self.items[i] = {type = self.heldItem, count = self.heldCount, durability = self.heldDurability}
                self.heldItem = nil
                self.heldCount = 0
            end
            break
        end
    end
    if not insideInventory and crafting and crafting.open then
        if crafting.mousepressed then
            crafting:mousepressed(mx, my, 1, self, itemsModule and itemsModule.itemTypes or {}, itemsModule)
            if not self.heldItem or self.heldCount == 0 then
                self.heldItem = nil
                self.heldCount = 0
                self.dragging = false
                return
            end
        end
    end

    if self.heldItem and insideInventory then
        for j = 1, self.maxSlots do
            if not self.items[j] then
                self.items[j] = { type = self.heldItem, count = self.heldCount, durability = self.heldDurability }
                self.heldItem = nil
                self.heldCount = 0
                break
            end
        end
    end
    if self.heldItem and not insideInventory and itemsModule and itemsModule.dropItem then
        itemsModule.dropItem(countryball.x + 0.6, countryball.y + 0.5, countryball.z + 0.1, self.heldItem, self.heldCount, self.heldDurability)
        self.heldItem = nil
        self.heldCount = 0
    end
    self.dragging = false
end

return Inventory