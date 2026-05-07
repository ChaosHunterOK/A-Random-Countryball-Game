local Console = {}

local utils = require("source.utils")

Console.active = false
Console.lines = {}
Console.maxLines = 12

local oldPrint = print

function Console:installGlobalHooks()
    print = function(...)
        local msg = {}
        local args = {...}
        for i = 1, select("#", ...) do
            msg[#msg+1] = tostring(args[i])
        end
        self:log(table.concat(msg, "    "))
        oldPrint(...)
    end

    love.errorhandler = function(msg)
        self:log("ERROR: " .. tostring(msg))
        oldPrint(msg)
        return nil
    end
end

function Console:toggle()
    self.active = not self.active
end

function Console:log(msg)
    table.insert(self.lines, tostring(msg))
    if #self.lines > 200 then
        table.remove(self.lines, 1)
    end
end

function Console:draw()
    if not self.active then return end

    local lg = love.graphics
    local w, h = lg.getDimensions()

    lg.setColor(0, 0, 0, 0.75)
    lg.rectangle("fill", 0, h * 0.6, w, h * 0.4)

    local start = math.max(1, #self.lines - self.maxLines)
    local y = h * 0.62

    lg.setColor(1, 1, 1, 1)
    for i = start, #self.lines do
        utils.drawSharpText(self.lines[i], 10, y, w - 20, "left")
        y = y + 24
    end
end

return Console