local love = require("love")
local lg = love.graphics
local base_width, base_height = 1000, 525
local utils = require("source.utils.utils")
local HelpMenu = {
    credits = {"Gulp"},
    scrollOffset = 0,
    visibleRows = 8,
    itemSpacing = 60,
    open = true,
}

function HelpMenu.update(dt)
    --Audio.update(dt)
end

function HelpMenu.toggle(guh)
    HelpMenu.open = guh
end

function HelpMenu.draw()
    utils.drawTextWithBorder("HELP", base_width/2 - 40, 40)
    local startY = 120
    for i, name in ipairs(HelpMenu.credits) do
        local drawIndex = i - HelpMenu.scrollOffset
        if drawIndex >= 1 and drawIndex <= HelpMenu.visibleRows then
            local y = startY + (drawIndex - 1) * HelpMenu.itemSpacing
            local text = name

            utils.drawTextWithBorder(text, 50, y, nil, "left")
        end
    end
end

return HelpMenu