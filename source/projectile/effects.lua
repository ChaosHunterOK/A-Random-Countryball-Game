local love = require("love")
local lg = love.graphics
local m = math
local sin, cos, pi = m.sin, m.cos, m.pi

local Effects = {}

function Effects.drawWavy(img, drawFunc, x, y, z, segments, amplitude, frequency)
    if not img or not drawFunc then return end
    segments = segments or 20
    amplitude = amplitude or 5
    frequency = frequency or 1

    local w, h = img:getWidth(), img:getHeight()
    local sliceH = h / segments
    local quads = {}

    for i = 0, segments-1 do
        local quad = love.graphics.newQuad(0, i*sliceH, w, sliceH, w, h)
        table.insert(quads, quad)
    end

    for i, quad in ipairs(quads) do
        local offset = sin((i / segments) * frequency * 2 * pi + love.timer.getTime()) * amplitude
        local canvas = love.graphics.newCanvas(w, sliceH)
        love.graphics.setCanvas(canvas)
        love.graphics.clear()
        lg.draw(img, quad, 0, offset)
        love.graphics.setCanvas()
        drawFunc(x, y + offset / 10, z, canvas, false)
    end
end

function Effects.drawPulse(img, drawFunc, x, y, z, baseScale, speed, maxScale)
    if not img or not drawFunc then return end
    baseScale = baseScale or 1
    speed = speed or 2
    maxScale = maxScale or 0.3
    local scale = baseScale + sin(love.timer.getTime() * speed) * maxScale
    drawFunc(x, y, z, img, false)
end

function Effects.drawSway(img, drawFunc, x, y, z, amplitude, speed)
    amplitude = amplitude or 5
    speed = speed or 2
    local offset = sin(love.timer.getTime() * speed) * amplitude
    drawFunc(x + offset / 10, y, z, img, false)
end

Effects.smokeParticles = {}

function Effects.spawnSmoke(img, x, y, z, lifetime, speedX, speedY, scale, alpha)
    table.insert(Effects.smokeParticles, {
        img = img,
        x = x,
        y = y,
        z = z or 0,
        vx = speedX or (math.random() - 0.5) * 2,
        vy = speedY or math.random() * 2,
        vz = speedX or (math.random() - 0.5) * 2,
        life = lifetime or 2,
        maxLife = lifetime or 2,
        scale = scale or 1,
        alpha = alpha or 1
    })
end

function Effects.updateSmoke(dt)
    for i = #Effects.smokeParticles, 1, -1 do
        local p = Effects.smokeParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.z = p.z + p.vz * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(Effects.smokeParticles, i)
        end
    end
end

function Effects.drawSmoke(drawFunc)
    for _, p in ipairs(Effects.smokeParticles) do
        local alpha = p.alpha * (p.life / p.maxLife)
        drawFunc(p.x, p.y, p.z, p.img, 1, 0, alpha)
    end
    lg.setColor(1, 1, 1, 1)
end

return Effects