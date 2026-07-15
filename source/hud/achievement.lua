local love = require"love"
local camera = require"source.projectile.camera"
local Achievement = {}
Achievement.list = {
    stone_age = {title = "First Steps", desc = "Entered the Stone Age!"},
    pottery_age = {title = "Clay Master", desc = "Entered the Pottery Age!"},
    copper_age = {title = "Heavy Metal", desc = "Entered the Copper Age!"}
}

local activeNotification = nil
local notificationTimer = 0
local bannerDuration = 3.5
function Achievement:trigger(ageName)
    local data = self.list[ageName]
    if data then
        activeNotification = {
            title = data.title,
            desc = data.desc,
            alpha = 0
        }
        notificationTimer = bannerDuration
    end
end

function Achievement:update(dt)
    if not activeNotification then return end

    notificationTimer = notificationTimer - dt

    if notificationTimer > bannerDuration - 0.5 then
        activeNotification.alpha = math.min(1, activeNotification.alpha + dt * 2)
    elseif notificationTimer < 0.5 then
        activeNotification.alpha = math.max(0, activeNotification.alpha - dt * 2)
    else
        activeNotification.alpha = 1
    end

    if notificationTimer <= 0 then
        activeNotification = nil
    end
end
function Achievement:draw()
    if not activeNotification then return end
    local screenWidth = camera.hw * 2
    local width, height = 220, 60
    local padding = 20
    local x = screenWidth - width - padding
    local y = padding
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(0.15, 0.15, 0.15, 0.85 * activeNotification.alpha)
    love.graphics.rectangle("fill", x, y, width, height, 6, 6)
    love.graphics.setColor(0.85, 0.65, 0.12, 1.0 * activeNotification.alpha)
    love.graphics.rectangle("line", x, y, width, height, 6, 6)
    love.graphics.setColor(1, 1, 1, 1.0 * activeNotification.alpha)
    love.graphics.print(activeNotification.title, x + 12, y + 10)
    love.graphics.setColor(0.7, 0.7, 0.7, 1.0 * activeNotification.alpha)
    love.graphics.print(activeNotification.desc, x + 12, y + 32, 0, 0.85, 0.85)
    love.graphics.setColor(r, g, b, a)
end

return Achievement