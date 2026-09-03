local love = require("love")
local camera = require("source.projectile.camera")
local base_width, base_height = camera.hw * 2, camera.hh * 2

function love.conf(t)
    t.identity = "A Random Countryball Game"
    t.version = "12.0"
    t.window.title = "A Random Countryball Game"
    t.window.borderless = false
    t.window.resizable = true
    t.window.vsync = 1
    t.window.msaa = 0
    t.window.stencil = 8
    if tonumber(t.version) <= 11.5 then
        t.window.depth = 24
        t.window.highdpi = false
    else
        t.window.depth = true
        t.highdpi = false
    end

    t.window.width = base_width
    t.window.height = base_height
end