local love = require("love")
local lg = love.graphics
local utils = require("source.utils")
local json = require("source.dkjson")

local ModsMenu = {
    mods = {},
    enabled = {},
    selected = 1,

    scrollOffset = 0,
    visibleRows = 8,
    itemSpacing = 60,
}

local MODS_FOLDER = "mods"
local MODS_STATE_FILE = MODS_FOLDER .. "/mods_state.json"
local WARNING_TEXT = "WARNING: Disabling one of the mods might cause the game to either crash or just give some errors."
love.filesystem.createDirectory(MODS_FOLDER)

function ModsMenu.load()
    ModsMenu.mods = {}

    ModsMenu.loadState()

    local entries = love.filesystem.getDirectoryItems(MODS_FOLDER)
    for _, folder in ipairs(entries) do
        local path = MODS_FOLDER .. "/" .. folder
        if love.filesystem.getInfo(path, "directory") then
            table.insert(ModsMenu.mods, folder)

            if ModsMenu.enabled[folder] == nil then
                ModsMenu.enabled[folder] = false
            end
            if ModsMenu.enabled[folder] then
                ModsMenu.loadMod(folder)
            end
        end
    end

    table.sort(ModsMenu.mods)
end

function ModsMenu.loadState()
    if not love.filesystem.getInfo(MODS_STATE_FILE) then
        ModsMenu.enabled = {}
        return
    end

    local data = love.filesystem.read(MODS_STATE_FILE)
    local decoded = json.decode(data)

    if decoded and decoded.mods then
        ModsMenu.enabled = decoded.mods
    else
        ModsMenu.enabled = {}
    end
end

function ModsMenu.saveState()
    local data = {
        warning = WARNING_TEXT,
        mods = ModsMenu.enabled
    }

    local encoded = json.encode(data, { indent = true })
    love.filesystem.write(MODS_STATE_FILE, encoded)
end

function ModsMenu.toggle(modName)
    ModsMenu.enabled[modName] = not ModsMenu.enabled[modName]

    if ModsMenu.enabled[modName] then
        ModsMenu.loadMod(modName)
    end

    ModsMenu.saveState()
end

function ModsMenu.loadMod(modName)
    local initPath = MODS_FOLDER .. "/" .. modName .. "/init.lua"
    if not love.filesystem.getInfo(initPath) then
        print("[MODS] Missing init.lua in", modName)
        return
    end

    local ModAPI = require("source.mod_api")

    local env = {
        love = love,
        print = print,
        ModAPI = ModAPI,
        utils = utils,
        json = json,
        math = math,
        pcall = pcall,
    }
    setmetatable(env, { __index = _G })

    local chunk, err = love.filesystem.load(initPath)
    if not chunk then
        print("[MODS] Load error:", err)
        return
    end

    setfenv(chunk, env)
    local ok, res = pcall(chunk)
    if not ok then
        print("[MODS] Runtime error:", res)
    else
        print("[MODS] Loaded:", modName)
    end
end

local base_width, base_height = 1000, 525
function ModsMenu:draw()
    utils.drawTextWithBorder("MODS", base_width/2 - 40, 40)

    local startY = 120
    for i, name in ipairs(self.mods) do
        local drawIndex = i - self.scrollOffset
        if drawIndex >= 1 and drawIndex <= self.visibleRows then
            local y = startY + (drawIndex - 1) * self.itemSpacing
            local selected = (i == self.selected)

            local col = selected and {1,1,0} or {1,1,1}
            local state = self.enabled[name] and "[ON]" or "[OFF]"
            local text = name .. " " .. state

            utils.drawTextWithBorder(text, 50, y, nil, "left", {0,0,0}, col)
        end
    end
    lg.setColor(1,1,1)
    utils.drawTextWithBorder(WARNING_TEXT, 0, base_height - 50, nil, "center")
end

function ModsMenu:keypressed(key)
    if key == "down" then
        self.selected = self.selected + 1
        if self.selected > #self.mods then self.selected = 1 end

    elseif key == "up" then
        self.selected = self.selected - 1
        if self.selected < 1 then self.selected = #self.mods end

    elseif key == "return" then
        local mod = self.mods[self.selected]
        if mod then
            ModsMenu.toggle(mod)
        end
    end
    if self.selected - 1 < self.scrollOffset then
        self.scrollOffset = self.selected - 1
    elseif self.selected > self.scrollOffset + self.visibleRows then
        self.scrollOffset = self.selected - self.visibleRows
    end

    if self.scrollOffset < 0 then self.scrollOffset = 0 end
end

return ModsMenu
