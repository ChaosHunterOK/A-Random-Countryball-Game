local night = {}

night.time = 0
night.dayLength = 125
night.light = 2
night.skyColor = {0.45, 0.70, 1.0}
night.nightColor = {0.03, 0.03, 0.07}
night.currentColor = {0.45, 0.70, 1.0}
--FF2D4C
--{0x28/255, 0x2D/255, 0x4C/255}
night.textureNightColor = {0x28/255, 0x2D/255, 0x4C/255}

local function lerp(a, b, t) return a + (b - a) * t end

function night.update(dt)
    night.time = night.time + dt
    if night.time >= night.dayLength then
        night.time = night.time - night.dayLength
    end

    local t = night.time / night.dayLength
    local light = (math.sin((t * 2 * math.pi) - math.pi/2) + 1) * 0.5
    night.light = light * 0.85 + 0.15
    for i = 1, 3 do
        night.currentColor[i] = lerp(night.skyColor[i], night.nightColor[i], 1 - night.light)
    end
end

function night.getTextureMultiplier()
    local light = night.light
    local multiplier = {}
    for i = 1, 3 do
        multiplier[i] = lerp(night.textureNightColor[i], 1, light)
    end
    return multiplier
end

function night.getLight()
    return night.light
end

function night.getSkyColor()
    return night.currentColor
end

return night