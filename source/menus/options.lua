local love = require"love"
local lg = love.graphics
local utils = require("source.utils")
local json = require("source.dkjson")
local Console = require("source.console")
local fs = love.filesystem
local base_width, base_height = 1000, 525

local Options = {}
local optionsFile = "options.json"

Options.categories = {
    {
        name = "Performance",
        items = {
            {name="FPS Cap", type="slider", value=60, min=30, max=240, step=30},
            {name="Chunk Size", type="slider", value=4, min=1, max=30, step=1},
            {name="Render Chunk Radious", type="slider", value=4, min=1, max=30, step=1},
        }
    },
    {
        name = "Audio",
        items = {
            {name="Music Volume", type="slider", value=0.5, min=0, max=1, step=0.05},
        }
    },
    {
        name = "Camera",
        items = {
            {name="Camera Sensitivity", type="slider", value=0, min=-3.0, max=3.0, step=0.1},
            {name="Camera Smoothness", type="slider", value=5.0, min=2.5, max=10.0, step=0.1},
            {name="FOV", type="slider", value=70, min=40, max=120, step=5},
        }
    },
    {
        name = "Graphics",
        items = {
            {name="Sky Box", type="toggle", value=false},
        }
    },
    {
        name = "Controls",
        items = {
            {name="Custom Cursor", type="toggle", value=true},
        }
    },
    {
        name = "System",
        items = {
            {name="Console", type="toggle", value=false},
            {name="Reset to Defaults", type="action"},
        }
    }
}

Options.state = "categories"
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
Options.selectedCategory = 1
Options.selectedItem = 1
Options.scrollOffset = 0
Options.itemSpacing = math.floor(60 * (base_height / 525))
Options.visibleRows = math.floor((base_height - 400) / Options.itemSpacing)

function Options:forEachItem(callback)
    for _, category in ipairs(self.categories) do
        for _, item in ipairs(category.items) do
            callback(item)
        end
    end
end

function Options:load(camera, chunkCfg, visible_idk)
    if fs.getInfo(optionsFile) then
        local data = fs.read(optionsFile)
        local decoded = json.decode(data)

        if decoded then
            self:forEachItem(function(item)
                if decoded[item.name] ~= nil then
                    item.value = decoded[item.name]
                end
            end)
        end
    end

    self:forEachItem(function(item)
        if item.name == "Music Volume" then
            love.audio.setVolume(item.value)
        elseif item.name == "Camera Sensitivity" then
            camera.sensitivity = item.value
        elseif item.name == "Camera Smoothness" then
            camera.smoothness = item.value
        elseif item.name == "FOV" then
            camera.fov = item.value
        elseif item.name == "Chunk Size" then
            chunkCfg.size = item.value
        elseif item.name == "Render Chunk Radious" then
            chunkCfg.radius = item.value
        elseif item.name == "Custom Cursor" then
            visible_idk.cursor = item.value
        elseif item.name == "Sky Box" then
            visible_idk.skyBox = item.value
        elseif item.name == "Console" then
            Console.active = item.value
        end
    end)
end

function Options:save()
    local data = {}

    self:forEachItem(function(item)
        data[item.name] = item.value
    end)

    local encoded = json.encode(data, {indent = true})
    fs.write(optionsFile, encoded)
end

function Options:update(dt)
end

function Options:draw()
    local startX = 50
    local y = math.floor(base_height * 0.2)
    local spacing = self.itemSpacing

    utils.drawTextWithBorder("OPTIONS", base_width/2 - 40, 40)

    if self.state == "categories" then
        for i, category in ipairs(self.categories) do
            local isSelected = (i == self.selectedCategory)
            local color = isSelected and {1,1,0} or {1,1,1}

            utils.drawTextWithBorder(category.name, startX, y, nil, "left", {0,0,0}, color)
            y = y + spacing
        end
    else
        local category = self.categories[self.selectedCategory]

        --utils.drawTextWithBorder(category.name, startX, y, nil, "left", {0.5,0.8,1}, {0,0,0})
        y = y + spacing

        for i, item in ipairs(category.items) do
            local isSelected = (i == self.selectedItem)
            local color = isSelected and {1,1,0} or {1,1,1}

            utils.drawTextWithBorder(item.name, startX, y, nil, "left", {0,0,0}, color)

            if item.type == "slider" then
                local sliderX = startX + 675
                local sliderWidth = 200
                local fill = (item.value - item.min) / (item.max - item.min)

                lg.setColor(0.3,0.3,0.3)
                lg.rectangle("fill", sliderX, y + 10, sliderWidth, 8)

                lg.setColor(1,1,0)
                lg.rectangle("fill", sliderX, y + 10, sliderWidth * fill, 8)

                lg.setColor(1,1,1)
            elseif item.type == "toggle" then
                local toggleX = startX + 675
                local text = item.value and "ON" or "OFF"
                utils.drawTextWithBorder(text, toggleX, y, 200, "center", {0,0,0}, color)
            end

            y = y + spacing
        end
    end
end

function Options:getFlatIndex()
    local index = 0
    for c = 1, self.selectedCategory - 1 do
        index = index + #self.categories[c].items
    end
    index = index + self.selectedItem
    return index
end

function Options:getTotalItems()
    local total = 0
    for _, cat in ipairs(self.categories) do
        total = total + #cat.items
    end
    return total
end

function Options:keypressed(key, camera, chunkCfg, visible_idk)
    if self.state == "categories" then
        if key == "up" then
            self.selectedCategory = self.selectedCategory - 1
            if self.selectedCategory < 1 then
                self.selectedCategory = #self.categories
            end

        elseif key == "down" then
            self.selectedCategory = self.selectedCategory + 1
            if self.selectedCategory > #self.categories then
                self.selectedCategory = 1
            end

        elseif key == "return" then
            self.state = "items"
            self.selectedItem = 1
        end

        return
    end
    local category = self.categories[self.selectedCategory]
    local items = category.items

    if key == "up" then
        self.selectedItem = self.selectedItem - 1
        if self.selectedItem < 1 then
            self.selectedItem = #items
        end

    elseif key == "down" then
        self.selectedItem = self.selectedItem + 1
        if self.selectedItem > #items then
            self.selectedItem = 1
        end

    elseif key == "escape" then
        self.state = "categories"
        return
    end

    local current = items[self.selectedItem]
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
            elseif current.name == "FOV" then
                camera.fov = current.value
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
        elseif current.name == "Console" then
            Console.active = current.value
        end
        self:save()
    end

    if current.type == "action" and key == "return" then
        if current.name == "Reset to Defaults" then
            self:forEachItem(function(item)
                if self.defaults[item.name] ~= nil then
                    item.value = self.defaults[item.name]
                end
            end)
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