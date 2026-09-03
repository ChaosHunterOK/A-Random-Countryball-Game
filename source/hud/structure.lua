local love = require "love"
local lg = love.graphics
local utils = require("source.utils.utils")
local Structures = require("source.structures")
local Audio = require("source.audio")
local tweens = require("source.utils.tweens")

local Structure = {}
Structure.open = false
Structure.anim = 0
Structure.timer = 0
Structure.duration = 0.525
Structure.bgAlpha = 0
Structure.target = nil

Structure.invBar = lg.newImage("image/bar/inv.png")
Structure.outputBar = lg.newImage("image/bar/give.png")

local easeInOutQuad = tweens.easeInOutQuad

function Structure:animateToOpen(open)
    tweens.cancelProperty(self, "anim")
    tweens.cancelProperty(self, "bgAlpha")
    self.timer = 0
    tweens.to(self, "anim", open and 1 or 0, self.duration, tweens.easeInOutQuad)
    tweens.to(self, "bgAlpha", open and 0.25 or 0, self.duration, tweens.easeInOutQuad)
end

function Structure:openFor(structure)
    self.target = structure
    self.open = true
    self:animateToOpen(true)
end

function Structure:close()
    self.open = false
    self:animateToOpen(false)
    self.draggingFrom = nil
end

function Structure:update(dt)
    if self.open and not self.target then
        self:close()
    end
end

function Structure:layout()
    local s = self.target
    if not s then return nil end
    local def = Structures.DEFS[s.type]

    local scaleX, scaleY = lg.getWidth() / 1000, lg.getHeight() / 525
    local scale = math.min(scaleX, scaleY)
    local barW, barH = self.invBar:getWidth() * scale, self.invBar:getHeight() * scale
    local spacing = 8 * scale

    local slotCount = 1 + def.inputSlots -- fuel + inputs
    local totalWidth = slotCount * barW + (slotCount - 1) * spacing
    local startX = (lg.getWidth() - totalWidth) / 2
    local startY = lg.getHeight() / 2 + 355 * (1 - self.anim) - 60

    local outStartX = startX
    local outY = startY + barH + spacing * 3
    local outTotalWidth = def.outputSlots * barW + (def.outputSlots - 1) * spacing
    outStartX = (lg.getWidth() - outTotalWidth) / 2

    return {
        scale = scale,
        barW = barW,
        barH = barH,
        spacing = spacing,
        startX = startX,
        startY = startY,
        outStartX = outStartX,
        outY = outY,
        def = def,
    }
end

function Structure:draw(inventory, itemTypes)
    if self.anim <= 0 or not self.target then return end
    local s = self.target
    local L = self:layout()
    if not L then return end

    lg.setColor(0, 0, 0, self.bgAlpha)
    lg.rectangle("fill", 0, 0, lg.getWidth(), lg.getHeight())

    local title = L.def.name .. (s.lit and " (burning)" or " (unlit)")
    utils.drawTextWithBorder(title, 0, L.startY - 34 * L.scale, lg.getWidth(), "center")
    lg.setColor(1, 1, 1, 1)
    lg.draw(self.invBar, L.startX, L.startY, 0, L.scale, L.scale)
    if s.fuel then
        local img = itemTypes[s.fuel.type] and itemTypes[s.fuel.type].img
        if img then
            local iw, ih = img:getWidth(), img:getHeight()
            lg.draw(img, L.startX + (L.barW - iw * L.scale) / 2, L.startY + (L.barH - ih * L.scale) / 2, 0, L.scale,
                L.scale)
            utils.drawTextWithBorder(s.fuel.count, L.startX + 16 * L.scale, L.startY + 8 * L.scale)
        end
    end
    for i = 1, L.def.inputSlots do
        local x = L.startX + i * (L.barW + L.spacing)
        lg.setColor(1, 1, 1, 1)
        lg.draw(self.invBar, x, L.startY, 0, L.scale, L.scale)
        local slot = s.inputs[i]
        if slot and slot.type then
            local img = itemTypes[slot.type] and itemTypes[slot.type].img
            if img then
                local iw, ih = img:getWidth(), img:getHeight()
                lg.draw(img, x + (L.barW - iw * L.scale) / 2, L.startY + (L.barH - ih * L.scale) / 2, 0, L.scale, L
                .scale)
                utils.drawTextWithBorder(slot.count, x + 16 * L.scale, L.startY + 8 * L.scale)
            end
        end
    end
    local progRatio = 0
    if L.def.batch then
        progRatio = math.min(1, s.kilnProgress / Structures.PIT_KILN_FIRE_TIME)
    elseif s.lit and s.inputs[1] then
        local recipe = Structures.SMELT_RECIPES[s.inputs[1].type]
        if recipe then progRatio = math.min(1, s.cookProgress / recipe.time) end
    end
    local pbX, pbY = L.startX, L.startY + L.barH + 6 * L.scale
    local pbW, pbH = (L.barW + L.spacing) * (1 + L.def.inputSlots) - L.spacing, 8 * L.scale
    lg.setColor(0, 0, 0, 1)
    lg.rectangle("fill", pbX, pbY, pbW, pbH)
    lg.setColor(1, 0.55, 0.1, 1)
    lg.rectangle("fill", pbX + L.scale, pbY + L.scale, (pbW - 2 * L.scale) * progRatio, pbH - 2 * L.scale)
    lg.setColor(1, 1, 1, 1)
    for i = 1, L.def.outputSlots do
        local x = L.outStartX + (i - 1) * (L.barW + L.spacing)
        lg.setColor(1, 1, 1, 1)
        lg.draw(self.outputBar, x, L.outY, 0, L.scale, L.scale)
        local slot = s.outputs[i]
        if slot and slot.type then
            local img = itemTypes[slot.type] and itemTypes[slot.type].img
            if img then
                local iw, ih = img:getWidth(), img:getHeight()
                lg.draw(img, x + (L.barW - iw * L.scale) / 2, L.outY + (L.barH - ih * L.scale) / 2, 0, L.scale, L.scale)
                utils.drawTextWithBorder(slot.count, x + 16 * L.scale, L.outY + 8 * L.scale)
            end
        end
    end

    local hint = s.lit and "Right-click the structure to feed the fire" or
    "Hold a firestarter and right-click the structure to light it"
    utils.drawTextWithBorder(hint, 0, L.outY + L.barH + 10 * L.scale, lg.getWidth(), "center")

    if inventory.heldItem then
        local img = itemTypes[inventory.heldItem] and itemTypes[inventory.heldItem].img
        if img then
            local mx, my = love.mouse.getPosition()
            lg.setColor(1, 1, 1, 1)
            lg.draw(img, mx - 16 * L.scale, my - 16 * L.scale, 0, L.scale, L.scale)
            utils.drawTextWithBorder(inventory.heldCount or 1, mx + 10 * L.scale, my + 10 * L.scale)
        end
    end
end

local function pointInRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function Structure:mousepressed(mx, my, button, inventory, itemTypes, itemsModule, countryball)
    if not self.open or not self.target then return end
    local s = self.target
    local L = self:layout()
    if not L then return end
    for i = 1, L.def.outputSlots do
        local x = L.outStartX + (i - 1) * (L.barW + L.spacing)
        if pointInRect(mx, my, x, L.outY, L.barW, L.barH) then
            local slot = s.outputs[i]
            if slot and slot.type then
                if inventory:hasFreeSlot() or inventory:canAddEvenIfFull(slot.type, itemTypes) then
                    inventory:add(slot.type, slot.count, itemTypes)
                else
                    itemsModule.dropItem(countryball.x + 0.6, countryball.y + 0.5, countryball.z + 0.1, slot.type,
                        slot.count)
                end
                s.outputs[i] = nil
                Audio.playSound("craft")
            end
            return
        end
    end
    if pointInRect(mx, my, L.startX, L.startY, L.barW, L.barH) then
        self:handleSlotClick(s, "coal", 0, button, inventory, itemTypes)
        return
    end
    for i = 1, L.def.inputSlots do
        local x = L.startX + i * (L.barW + L.spacing)
        if pointInRect(mx, my, x, L.startY, L.barW, L.barH) then
            self:handleSlotClick(s, "clay", i, button, inventory, itemTypes)
            return
        end
    end
end

function Structure:handleSlotClick(s, kind, index, button, inventory, itemTypes)
    local getSlot, setSlot
    if kind == "coal" then
        getSlot = function() return s.fuel end
        setSlot = function(v) s.fuel = v end
    else
        getSlot = function() return s.inputs[index] end
        setSlot = function(v) s.inputs[index] = v end
    end

    local slot = getSlot()

    if slot and not inventory.heldItem then
        if button == 1 then
            inventory.heldItem = slot.type
            inventory.heldCount = slot.count
            setSlot(nil)
        elseif button == 2 then
            inventory.heldItem = slot.type
            inventory.heldCount = 1
            slot.count = slot.count - 1
            if slot.count <= 0 then setSlot(nil) end
        end
        return
    end

    if inventory.heldItem then
        if kind == "coal" and not Structures.fuelValue(inventory.heldItem) then
            return
        end

        local stackLimit = itemTypes[inventory.heldItem].stack or 1
        if not slot then
            if button == 1 then
                setSlot({ type = inventory.heldItem, count = inventory.heldCount })
                inventory.heldItem, inventory.heldCount = nil, 0
            elseif button == 2 then
                setSlot({ type = inventory.heldItem, count = 1 })
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
            local temp = { type = slot.type, count = slot.count }
            setSlot({ type = inventory.heldItem, count = inventory.heldCount })
            inventory.heldItem, inventory.heldCount = temp.type, temp.count
        end
    end
end

return Structure
