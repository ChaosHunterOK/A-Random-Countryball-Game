local love = require"love"
local lg = love.graphics
local utils = require("source.utils")

local Options = {}

Options.items = {
    {name="Music Volume", type="slider", value=0.5, min=0, max=1, step=0.05},
    {name="Camera Sensitivity", type="slider", value=0, min=-3.0, max=3.0, step=0.1},
    {name="Camera Smoothness", type="slider", value=0.5, min=0.5, max=1.0, step=0.1},
    {name="Chunk Size", type="slider", value=4, min=1, max=30, step=1},
    {name="Render Chunk Radious", type="slider", value=4, min=1, max=30, step=1},
    --{name="Back", type="action"}
}
Options.selectedIndex = 1

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
                chunk_thing.render_chunk_radius= current.value
            end
        end
    end
end

return Options