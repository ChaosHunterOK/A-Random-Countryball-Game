local love = require"love"
local lg = love.graphics
local utils = require("source.utils")
local json = require("source.dkjson")
local fs = love.filesystem
local base_width, base_height = 1000, 525

local Options = {}
local optionsFile = "options.json"

Options.items = {
    {name="FPS Cap", type="slider", value=60, min=30, max=240, step=30},
    {name="Music Volume", type="slider", value=0.5, min=0, max=1, step=0.05},
    {name="Camera Sensitivity", type="slider", value=0, min=-3.0, max=3.0, step=0.1},
    {name="Camera Smoothness", type="slider", value=5.0, min=2.5, max=10.0, step=0.1},
    {name="Chunk Size", type="slider", value=4, min=1, max=30, step=1},
    {name="Render Chunk Radious", type="slider", value=4, min=1, max=30, step=1},
    {name="Custom Cursor", type="toggle", value=true},
    {name="Sky Box", type="toggle", value=false},
    {name="Reset to Defaults", type="action"},
    --{name="Back", type="action"}
}

Options.defaults = {
    ["FPS Cap"] = 60,
    ["Music Volume"] = 0.5,
    ["Camera Sensitivity"] = 0,
    ["Camera Smoothness"] = 5.0,
    ["Chunk Size"] = 4,
    ["Render Chunk Radious"] = 4,
    ["Custom Cursor"] = true,
    ["Sky Box"] = false,
}
Options.selectedIndex = 1
Options.scrollOffset = 0
Options.visibleRows = 7
Options.itemSpacing = 60

function Options:load(camera, chunkCfg, visible_idk)
    if fs.getInfo(optionsFile) then
        local data = fs.read(optionsFile)
        local decoded = json.decode(data)

        if decoded then
            for _, item in ipairs(self.items) do
                if decoded[item.name] ~= nil then
                    item.value = decoded[item.name]
                end
            end
        end
    end
    for _, item in ipairs(self.items) do
        if item.name == "FPS Cap" then
        elseif item.name == "Music Volume" then
            love.audio.setVolume(item.value)
        elseif item.name == "Camera Sensitivity" then
            camera.sensitivity = item.value
        elseif item.name == "Camera Smoothness" then
            camera.smoothness = item.value
        elseif item.name == "Chunk Size" then
            chunkCfg.size = item.value
        elseif item.name == "Render Chunk Radious" then
            chunkCfg.radius = item.value
        elseif item.name == "Custom Cursor" then
            visible_idk.cursor = item.value
        elseif item.name == "Sky Box" then
            visible_idk.skyBox = item.value
        end
    end
end

function Options:save()
    local data = {}

    for _, item in ipairs(self.items) do
        data[item.name] = item.value
    end

    local encoded = json.encode(data, { indent = true })
    fs.write(optionsFile, encoded)
end

function Options:update(dt)
end

function Options:draw()
    local startX = 50
    local startY = 100
    local spacing = self.itemSpacing

    local screenW = love.graphics.getWidth()
    utils.drawTextWithBorder("OPTIONS", base_width/2 - 40, 40)
    for i, item in ipairs(self.items) do
        local drawIndex = i - self.scrollOffset
        if drawIndex >= 1 and drawIndex <= self.visibleRows then
            local y = startY + (drawIndex-1) * spacing
            local isSelected = i == self.selectedIndex
            local textColor = isSelected and {1,1,0} or {1,1,1}
            utils.drawTextWithBorder(item.name, startX, y, screenW, "left", {0,0,0}, textColor)

            if item.type == "slider" then
                local sliderX = startX + 675
                local sliderWidth = 200
                local sliderHeight = 8
                local fill = (item.value - item.min) / (item.max - item.min)

                lg.setColor(0.3,0.3,0.3)
                lg.rectangle("fill", sliderX, y + 10, sliderWidth, sliderHeight)
                lg.setColor(1,1,0)
                lg.rectangle("fill", sliderX, y + 10, sliderWidth * fill, sliderHeight)
                lg.setColor(1,1,1)
            end
            if item.type == "toggle" then
                local toggleBoxX = startX + 675
                local toggleBoxWidth = 200

                local text = item.value and "ON" or "OFF"
                utils.drawTextWithBorder(text, toggleBoxX, y, toggleBoxWidth, "center", {0,0,0}, isSelected and {1,1,0} or {1,1,1})
                lg.setColor(1,1,1)
            end
        end
    end
end

function Options:keypressed(key, camera, chunkCfg, visible_idk)
    if key == "up" then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then
            self.selectedIndex = #self.items
        end

    elseif key == "down" then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > #self.items then
            self.selectedIndex = 1
        end
    end

    if self.selectedIndex < self.scrollOffset + 1 then
        self.scrollOffset = self.selectedIndex - 1
    elseif self.selectedIndex > self.scrollOffset + self.visibleRows then
        self.scrollOffset = self.selectedIndex - self.visibleRows
    end

    local maxScroll = math.max(0, #self.items - self.visibleRows)
    self.scrollOffset = math.max(0, math.min(self.scrollOffset, maxScroll))

    local current = self.items[self.selectedIndex]

    if key == "left" or key == "right" then
        if current.type == "slider" then
            local delta = (key == "left") and -current.step or current.step
            local oldValue = current.value
            current.value = math.max(current.min, math.min(current.max, current.value + delta))

            if current.name == "Music Volume" then
                love.audio.setVolume(current.value)
            elseif current.name == "Camera Sensitivity" then
                camera.sensitivity = current.value
            elseif current.name == "Camera Smoothness" then
                camera.smoothness = current.value
            elseif current.name == "Chunk Size" then
                chunkCfg.size = current.value
            elseif current.name == "Render Chunk Radious" then
                chunkCfg.radius = current.value
            end

            if current.value ~= oldValue then
                self:save()
            end
        end
    end

    if current.type == "toggle" and (key == "left" or key == "right" or key == "return") then
        current.value = not current.value
        if current.name == "Custom Cursor" then
            visible_idk.cursor = current.value
        elseif current.name == "Sky Box" then
            visible_idk.skyBox = current.value
        end
        self:save()
    end

    if current.type == "action" and key == "return" then
        if current.name == "Reset to Defaults" then
            for _, item in ipairs(self.items) do
                if self.defaults[item.name] ~= nil then
                    item.value = self.defaults[item.name]
                end
            end

            FPS_CAP = self.defaults["FPS Cap"]
            love.audio.setVolume(self.defaults["Music Volume"])
            camera.sensitivity = self.defaults["Camera Sensitivity"]
            camera.smoothness = self.defaults["Camera Smoothness"]
            chunkCfg.size = self.defaults["Chunk Size"]
            chunkCfg.radius = self.defaults["Render Chunk Radious"]
            visible_idk.cursor = self.defaults["Custom Cursor"]
            visible_idk.skyBox = self.defaults["Sky Box"]

            self:save()
        end
    end
end

return Options