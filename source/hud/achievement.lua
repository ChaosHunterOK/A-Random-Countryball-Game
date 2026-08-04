local love = require "love"
local camera = require "source.projectile.camera"
local utils = require("source.utils")

local Achievement = {}

Achievement.list = {
    stone_age = {title = "First Steps", desc = "Entered the Stone Age!"},
    pottery_age = {title = "Clay Master", desc = "Entered the Pottery Age!"},
    copper_age = {title = "Heavy Metal", desc = "Entered the Copper Age!"}
}

local queue = {}
local activeNotification = nil
local notificationTimer = 0
local bannerDuration = 3.5
local bannerWidth, bannerHeight = 220, 60

function Achievement:register(id, title, desc)
    self.list[id] = {title = title, desc = desc}
end

function Achievement:trigger(id)
    local data = self.list[id]
    if not data then return end

    table.insert(queue, {
        title = data.title,
        desc = data.desc,
        alpha = 0
    })
end

function Achievement:update(dt)
    if not activeNotification and #queue > 0 then
        activeNotification = table.remove(queue, 1)
        notificationTimer = bannerDuration
    end

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
    local padding = 20
    local x = screenWidth - bannerWidth - padding
    local y = padding

    love.graphics.setColor(0, 0, 0, 0.85 * activeNotification.alpha)
    love.graphics.rectangle("fill", x, y, bannerWidth, bannerHeight)
    love.graphics.setColor(0.5, 0.5, 0.5, 1.0 * activeNotification.alpha)
    love.graphics.rectangle("line", x, y, bannerWidth, bannerHeight)
    love.graphics.setColor(1, 1, 1, 1)
    utils.drawTextWithBorder(activeNotification.title or "N/A", x + 12, y + 10, bannerWidth - 20, "left", {0, 0, 0, 1}, {1, 1, 1, 1 * activeNotification.alpha})
    utils.drawTextWithBorder(activeNotification.desc or "N/A", x + 12, y + 32, bannerWidth - 20, "left", {0, 0, 0, 1}, {1, 1, 1, 0.5 * activeNotification.alpha})
    love.graphics.setColor(1, 1, 1, 1)
end

function Achievement:reset()
    queue = {}
    activeNotification = nil
    notificationTimer = 0
end

return Achievement