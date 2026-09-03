local love = require("love")
local lg = love.graphics
local m = math
local sin, cos, pi = m.sin, m.cos, m.pi

local Particles = {}
local wavyCache = setmetatable({}, {__mode = "k"})

local function getWavyCache(img, segments)
    local cache = wavyCache[img]
    if cache and cache.segments == segments then
        return cache
    end

    local w, h = img:getWidth(), img:getHeight()
    local sliceH = h / segments
    local quads, canvases = {}, {}
    for i = 0, segments - 1 do
        quads[i + 1] = love.graphics.newQuad(0, i * sliceH, w, sliceH, w, h)
        canvases[i + 1] = love.graphics.newCanvas(w, sliceH)
    end

    cache = {segments = segments, quads = quads, canvases = canvases, sliceH = sliceH, w = w}
    wavyCache[img] = cache
    return cache
end

function Particles.drawWavy(img, drawFunc, x, y, z, segments, amplitude, frequency)
    if not img or not drawFunc then return end
    segments = segments or 20
    amplitude = amplitude or 5
    frequency = frequency or 1

    local cache = getWavyCache(img, segments)
    local time = love.timer.getTime()

    for i = 1, segments do
        local offset = sin((i / segments) * frequency * 2 * pi + time) * amplitude
        local canvas = cache.canvases[i]

        love.graphics.setCanvas(canvas)
        love.graphics.clear()
        lg.draw(img, cache.quads[i], 0, offset)
        love.graphics.setCanvas()

        drawFunc(x, y + offset / 10, z, canvas, false)
    end
end

function Particles.drawPulse(img, drawFunc, x, y, z, baseScale, speed, maxScale)
    if not img or not drawFunc then return end
    baseScale = baseScale or 1
    speed = speed or 2
    maxScale = maxScale or 0.3
    local scale = baseScale + sin(love.timer.getTime() * speed) * maxScale
    drawFunc(x, y, z, img, false, scale, scale)
end

function Particles.drawSway(img, drawFunc, x, y, z, amplitude, speed)
    amplitude = amplitude or 5
    speed = speed or 2
    local offset = sin(love.timer.getTime() * speed) * amplitude
    drawFunc(x + offset / 10, y, z, img, false)
end

Particles.smokeParticles = {}

function Particles.spawnSmoke(img, x, y, z, lifetime, speedX, speedY, speedZ, scale, alpha)
    table.insert(Particles.smokeParticles, {
        img = img,
        x = x,
        y = y,
        z = z or 0,

        vx = speedX or (math.random() - 0.5) * 2,
        vy = speedY or math.random() * 2,
        vz = speedZ or (math.random() - 0.5) * 2,

        drag = 2.5,
        gravity = -0.4,
        rise = 0.8,

        life = lifetime or 2,
        maxLife = lifetime or 2,

        scale = scale or 1,
        startScale = scale or 1,
        endScale = (scale or 1) * 1.8,

        rotation = math.random() * math.pi * 2,
        rotSpeed = (math.random() - 0.5) * 4,

        alpha = alpha or 1
    })
end

function Particles.spawnBurst(img, x, y, z, count, opts)
    if not img then return end

    opts = opts or {}
    count = count or 12

    local radius = opts.radius or 0.05
    local speedMin = opts.speedMin or 0.8
    local speedMax = opts.speedMax or 2.8
    local upwardBias = opts.upwardBias or 0.35
    local lifeMin = opts.lifetimeMin or 0.5
    local lifeMax = opts.lifetimeMax or 1.2
    local scaleMin = opts.scaleMin or 0.15
    local scaleMax = opts.scaleMax or 0.35
    local alpha = opts.alpha or 1

    for i = 1, count do
        local theta = math.random() * math.pi * 2
        local phi = math.acos(2 * math.random() - 1)

        local dx = math.sin(phi) * math.cos(theta)
        local dy = math.cos(phi)
        local dz = math.sin(phi) * math.sin(theta)
        dy = dy + upwardBias

        local len = math.sqrt(dx*dx + dy*dy + dz*dz)
        dx, dy, dz = dx/len, dy/len, dz/len

        local speed = speedMin + math.random() * (speedMax - speedMin)

        local lifetime = lifeMin + math.random() * (lifeMax - lifeMin)
        local scale = scaleMin + math.random() * (scaleMax - scaleMin)

        local p = {
            img = img,

            x = x + dx * radius * math.random(),
            y = y + dy * radius * math.random(),
            z = z + dz * radius * math.random(),

            vx = dx * speed,
            vy = dy * speed,
            vz = dz * speed,

            drag = 3 + math.random() * 2,
            gravity = -0.25,
            rise = 0.6 + math.random() * 0.5,

            life = lifetime,
            maxLife = lifetime,

            scale = scale,
            startScale = scale,
            endScale = scale * (1.6 + math.random() * 0.8),

            rotation = math.random() * math.pi * 2,
            rotSpeed = (math.random() - 0.5) * 3,

            alpha = alpha
        }

        table.insert(Particles.smokeParticles, p)
    end
end

function Particles.updateSmoke(dt)
    for i = #Particles.smokeParticles, 1, -1 do
        local p = Particles.smokeParticles[i]

        local drag = math.exp(-p.drag * dt)

        p.vx = p.vx * drag
        p.vy = p.vy * drag + (p.rise + p.gravity) * dt
        p.vz = p.vz * drag

        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.z = p.z + p.vz * dt

        p.rotation = p.rotation + p.rotSpeed * dt

        p.life = p.life - dt

        local t = 1 - (p.life / p.maxLife)
        p.scale = p.startScale + (p.endScale - p.startScale) * t

        if p.life <= 0 then
            table.remove(Particles.smokeParticles, i)
        end
    end
end

function Particles.drawSmoke(drawFunc)
    for _, p in ipairs(Particles.smokeParticles) do
        local t = p.life / p.maxLife
        local alpha = p.alpha * (t * t)
        local img = p.img
        if type(img) == "table" then
            local frameIndex = math.floor((1 - t) * #img) + 1
            frameIndex = math.max(1, math.min(frameIndex, #img))
            img = img[frameIndex]
        end
        
        drawFunc(p.x, p.y, p.z, img, false, p.scale, p.scale, 0, alpha)
    end
    lg.setColor(1, 1, 1, 1)
end

Particles.fireParticles = {}

function Particles.spawnFire(img, x, y, z, lifetime, scale, alpha)
    if not img then return end
    table.insert(Particles.fireParticles, {
        img = img,
        x = x,
        y = y,
        z = z or 0,

        life = lifetime or 1.5,
        maxLife = lifetime or 1.5,

        scale = scale or 1,
        startScale = scale or 1,
        endScale = (scale or 1) * 0.6,

        alpha = alpha or 1
    })
end

function Particles.updateFire(dt)
    for i = #Particles.fireParticles, 1, -1 do
        local p = Particles.fireParticles[i]
        p.life = p.life - dt

        local t = 1 - (p.life / p.maxLife)
        p.scale = p.startScale + (p.endScale - p.startScale) * t

        if p.life <= 0 then
            table.remove(Particles.fireParticles, i)
        end
    end
end

function Particles.drawFire(drawFunc)
    for _, p in ipairs(Particles.fireParticles) do
        local t = p.life / p.maxLife
        local alpha = p.alpha * (1 - t)
        local img = p.img
        if type(img) == "table" then
            local frameIndex = math.floor((1 - t) * #img) + 1
            frameIndex = math.max(1, math.min(frameIndex, #img))
            img = img[frameIndex]
        end
        drawFunc(p.x, p.y, p.z, img, false, p.scale, p.scale, 0, alpha)
    end
    lg.setColor(1, 1, 1, 1)
end

return Particles