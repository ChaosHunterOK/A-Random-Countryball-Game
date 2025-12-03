function love.conf(t)
    t.identity = "A Random Countryball Game"
    t.version = "11.5"
    t.console = false

    t.window.title = "A Random Countryball Game"
    t.window.width = 1280
    t.window.height = 720
    t.window.vsync = 1
    t.window.msaa = 2
    t.window.depth = 24
    t.window.stencil = true
    t.window.highdpi = false
    t.window.resizable = true

    t.modules.graphics = true
    t.modules.window = true
    t.modules.audio = true
    t.modules.sound = true
    t.modules.image = true
    t.modules.timer = true
    t.modules.event = true
    t.modules.mouse = true
    t.modules.keyboard = true
    t.modules.joystick = false
    t.modules.touch = false
    
    t.window.usedpiscale = true
end
