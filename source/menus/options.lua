local love = require"love"
local lg = love.graphics
local utils = require("source.utils")
local json = require("source.dkjson")

local Options = {}
local optionsFile = "options.json"

Options.items = {
    {name="Music Volume", type="slider", value=0.5, min=0, max=1, step=0.05},
    {name="Camera Sensitivity", type="slider", value=0, min=-3.0, max=3.0, step=0.1},
    {name="Camera Smoothness", type="slider", value=5.0, min=2.5, max=10.0, step=0.1},
    {name="Chunk Size", type="slider", value=4, min=1, max=30, step=1},
    {name="Render Chunk Radious", type="slider", value=4, min=1, max=30, step=1},
    --{name="Back", type="action"}
}
Options.selectedIndex = 1

function Options:load(camera, chunk_thing)
    if love.filesystem.getInfo(optionsFile) then
        local data = love.filesystem.read(optionsFile)
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
        if item.name == "Music Volume" then
            love.audio.setVolume(item.value)
        elseif item.name == "Camera Sensitivity" then
            camera.sensitivity = item.value
        elseif item.name == "Camera Smoothness" then
            camera.smoothness = item.value
        elseif item.name == "Chunk Size" then
            chunk_thing.chunk_size = item.value
        elseif item.name == "Render Chunk Radious" then
            chunk_thing.render_chunk_radius = item.value
        end
    end
end

function Options:save()
    local data = {}

    for _, item in ipairs(self.items) do
        data[item.name] = item.value
    end

    local encoded = json.encode(data, { indent = true })
    love.filesystem.write(optionsFile, encoded)
end

function Options:update(dt)
end

function Options:draw()
    local startX, startY = 50, 100
    local spacing = 60

    for i, item in ipairs(self.items) do
        local y = startY + (i-1) * spacing
        local isSelected = i == self.selectedIndex
        local textColor = isSelected and {1,1,0} or {1,1,1}
        local borderColor = {0,0,0}

        utils.drawTextWithBorder(item.name, startX, y, love.graphics.getWidth(), "left", borderColor, textColor)

        if item.type == "slider" then
            local sliderWidth = 200
            local sliderHeight = 8
            local fill = (item.value - item.min)/(item.max - item.min)
            lg.setColor(0.3,0.3,0.3)
            lg.rectangle("fill", startX + 675, y + 10, sliderWidth, sliderHeight)
            lg.setColor(1,1,0)
            lg.rectangle("fill", startX + 675, y + 10, sliderWidth*fill, sliderHeight)
            lg.setColor(1,1,1)
        end
    end
    lg.setColor(1,1,1)
end

function Options:keypressed(key, camera, chunk_thing)
    local current = self.items[self.selectedIndex]
    if key == "up" then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then self.selectedIndex = #self.items end
    elseif key == "down" then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > #self.items then self.selectedIndex = 1 end
    elseif key == "left" or key == "right" then
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
                chunk_thing.chunk_size = current.value
            elseif current.name == "Render Chunk Radious" then
                chunk_thing.render_chunk_radius = current.value
            end

            if current.value ~= oldValue then
                self:save()
            end
        end
    end
end

return Options