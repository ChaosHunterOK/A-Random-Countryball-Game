local love = require("love")
local lg = love.graphics
local base_width, base_height = 1000, 525
local utils = require("source.utils.utils")
local Audio = require("source.audio")
local CreditsMenu = {
    credits = {"DEVS", "CopiluCuSarmle - Artist, Animator, Coder, Composer", "Solid - Composer", "FORMER DEVS", "Replayer - Composer"},
    scrollOffset = 0,
    visibleRows = 8,
    itemSpacing = 60,
    open = true,
}

local creditsVolume = 0
local fadeSpeed = 2
function CreditsMenu.update(dt)
    --Audio.update(dt)

    local creditsSource = Audio.getMusic("credits")
    if not creditsSource then
        return
    end

    if CreditsMenu.open then
        if not creditsSource:isPlaying() then
            creditsSource:setVolume(0)
            creditsSource:play()
        end

        creditsVolume = math.min(creditsVolume + fadeSpeed * dt, 1)
        creditsSource:setVolume(creditsVolume)
    else
        creditsVolume = math.max(creditsVolume - fadeSpeed * dt, 0)
        creditsSource:setVolume(creditsVolume)

        if creditsVolume <= 0 and creditsSource:isPlaying() then
            creditsSource:stop()
        end
    end
end

function CreditsMenu.toggle(guh)
    CreditsMenu.open = guh
end

function CreditsMenu.draw()
    utils.drawTextWithBorder("CREDITS", base_width/2 - 40, 40)
    local startY = 120
    for i, name in ipairs(CreditsMenu.credits) do
        local drawIndex = i - CreditsMenu.scrollOffset
        if drawIndex >= 1 and drawIndex <= CreditsMenu.visibleRows then
            local y = startY + (drawIndex - 1) * CreditsMenu.itemSpacing
            local text = name

            utils.drawTextWithBorder(text, 50, y, nil, "left")
        end
    end
end

return CreditsMenu