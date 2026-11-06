local love = require "love"
local utils = require "source.utils.utils"
local night = {}

night.dayLength = 180
night.time = night.dayLength / 2
night.light = 1
night.skyColor = {0.45, 0.70, 1.0}
night.nightColor = {0.03, 0.03, 0.07}
night.currentColor = {0.45, 0.70, 1.0}
--FF2D4C
--{0x28/255, 0x2D/255, 0x4C/255}
night.textureNightColor = {0x28/255, 0x2D/255, 0x4C/255}

local utils = require("source.utils.utils")
local function lerp(a, b, t) return a + (b - a) * t end

local clamp = utils.clamp
local sin, cos, rad, sqrt = math.sin, math.cos, math.rad, math.sqrt
local atan2 = math.atan2 or math.atan

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

function night.getCelestialState()
    local phase = night.time / night.dayLength
    local nightAmount = clamp((0.58 - night.light) / 0.43, 0, 1)

    return {
        phase = phase,
        sunAlpha = clamp((night.light - 0.18) / 0.35, 0, 1),
        moonAlpha = clamp((0.72 - night.light) / 0.42, 0, 1),
        starAlpha = nightAmount,
        venusAlpha = clamp((0.76 - night.light) / 0.42, 0, 1),
    }
end

local celestialPaths = {
    sun = "image/sky/sun.png",
    moon = "image/sky/moon.png",
    star = "image/sky/star.png",
    venus = "image/sky/venus.png",
}
local SUN_RISE, SUN_SPAN = 0.25, 0.5
local MOON_RISE, MOON_SPAN = 0.75, 0.5

local SUN_AZIMUTH_SPAN, SUN_MAX_ELEV = 168, 76
local MOON_AZIMUTH_SPAN, MOON_MAX_ELEV = 150, 62
local VENUS_AZIMUTH_SPAN, VENUS_MAX_ELEV = 168, 24
local VENUS_AZIMUTH_OFFSET = 10

local STAR_COUNT = 90

local sunImg, moonImg, starImg, venusImg
local starField = {}
local celestialLoaded = false

function night.load()
    if celestialLoaded then return end

    sunImg = love.graphics.newImage(celestialPaths.sun)
    moonImg = love.graphics.newImage(celestialPaths.moon)
    starImg = love.graphics.newImage(celestialPaths.star)
    venusImg = love.graphics.newImage(celestialPaths.venus)
    local rng = love.math.newRandomGenerator(1337)
    for i = 1, STAR_COUNT do
        local az = rng:random() * math.pi * 2
        local elevFactor = rng:random() ^ 1.6
        local elev = elevFactor * rad(87)
        local cosElev = cos(elev)
        starField[i] = {
            dx = sin(az) * cosElev,
            dy = sin(elev),
            dz = cos(az) * cosElev,
            scale = 0.35 + rng:random() * 0.55,
            twinkleSpeed = 0.6 + rng:random() * 1.4,
            twinklePhase = rng:random() * math.pi * 2,
            baseAlpha = 0.5 + rng:random() * 0.5,
        }
    end

    celestialLoaded = true
end

local function arcProgress(t, riseT, span)
    local progress = ((t - riseT) % 1) / span
    if progress < 0 or progress > 1 then return nil end
    return progress
end

local function skyDirection(progress, azimuthSpanDeg, maxElevDeg, azimuthOffsetDeg)
    local elevationFactor = sin(progress * math.pi)
    local az = rad((azimuthOffsetDeg or 0) - azimuthSpanDeg / 2 + azimuthSpanDeg * progress)
    local elev = rad(maxElevDeg) * elevationFactor
    local cosElev = cos(elev)
    return sin(az) * cosElev, sin(elev), cos(az) * cosElev, elevationFactor
end

local function cameraView(camera)
    if not camera then return nil end

    if camera.updateProjectionConstants and not camera._cosYaw then
        pcall(camera.updateProjectionConstants, camera)
    end

    local cy, sy = camera._cosYaw, camera._sinYaw
    local cp, sp = camera._cosPitch, camera._sinPitch
    if not (cy and sy and cp and sp) then
        local yaw, pitch = camera.yaw or 0, camera.pitch or 0
        cy, sy = cos(yaw), sin(yaw)
        cp, sp = cos(pitch), sin(pitch)
    end

    local hw = (camera.hw and camera.hw > 1) and camera.hw or (love.graphics.getWidth() * 0.5)
    local hh = (camera.hh and camera.hh > 1) and camera.hh or (love.graphics.getHeight() * 0.5)

    return {
        cy = cy, sy = sy, cp = cp, sp = sp,
        f = (camera._f and camera._f > 0) and camera._f or 1,
        aspect = (camera.aspect and camera.aspect > 0) and camera.aspect or (hw / hh),
        hw = hw,
        hh = hh,
    }
end

local function projectDirection(dx, dy, dz, view)
    local x1 = dx * view.cy - dz * view.sy
    local z1 = dx * view.sy + dz * view.cy
    local y1 = dy * view.cp - z1 * view.sp
    local z2 = dy * view.sp + z1 * view.cp
    if z2 <= 0.04 then return nil end

    local inv = view.f / z2
    local sx = (x1 * inv / view.aspect) * view.hw + view.hw
    local sy = (-y1 * inv) * view.hh + view.hh
    local edgeFade = clamp((z2 - 0.04) / 0.16, 0, 1)
    return sx, sy, edgeFade
end

local function tangentUp(dx, dy, dz)
    local ux, uy, uz = -dx * dy, 1 - dy * dy, -dz * dy
    local len = sqrt(ux * ux + uy * uy + uz * uz)
    if len < 1e-4 then
        return 1, 0, 0
    end
    return ux / len, uy / len, uz / len
end

local function billboardRotation(dx, dy, dz, sx, sy, view)
    local uxT, uyT, uzT = tangentUp(dx, dy, dz)
    local nx, ny, nz = utils.normalize3(dx + uxT * 0.02, dy + uyT * 0.02, dz + uzT * 0.02)
    local sx2, sy2 = projectDirection(nx, ny, nz, view)
    if not sx2 then return 0 end
    local tx, ty = sx2 - sx, sy2 - sy
    if tx * tx + ty * ty < 1e-6 then return 0 end
    return atan2(tx, -ty)
end

local function drawGlow(x, y, radius, color, alpha)
    if alpha <= 0.01 then return end
    love.graphics.setBlendMode("add")
    local steps = 5
    for i = steps, 1, -1 do
        local f = i / steps
        love.graphics.setColor(color[1], color[2], color[3], alpha * (1 - f) * 0.5)
        love.graphics.circle("fill", x, y, radius * f, 32)
    end
    love.graphics.setBlendMode("alpha")
end

local function flatProject(progress, elevation, width, height, horizonY, arcHeight, sideMargin)
    local x = sideMargin + progress * (width - 2 * sideMargin)
    local y = horizonY - elevation * arcHeight
    return x, y
end

function night.draw(width, height, camera)
    if not celestialLoaded then night.load() end
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()

    local state = night.getCelestialState()
    local t = state.phase
    local now = love.timer.getTime()

    local view = cameraView(camera)
    local zoomScale
    if view then
        zoomScale = clamp(camera.zoom or 1, 0.65, 1.9)
    end
    local horizonY = height * 0.68
    local arcHeight = height * 0.55
    local sideMargin = width * 0.06

    love.graphics.push("all")
    love.graphics.setBlendMode("alpha")
    love.graphics.setDepthMode("always", false)

    if state.starAlpha > 0.01 then
        local sw, sh = starImg:getDimensions()
        for i = 1, #starField do
            local s = starField[i]
            local twinkle = 0.55 + 0.45 * math.sin(now * s.twinkleSpeed + s.twinklePhase)
            local a = state.starAlpha * s.baseAlpha * twinkle
            if a > 0.02 then
                local sx, sy, edgeFade, rotation
                if view then
                    sx, sy, edgeFade = projectDirection(s.dx, s.dy, s.dz, view)
                    if sx then
                        rotation = billboardRotation(s.dx, s.dy, s.dz, sx, sy, view)
                    end
                else
                    sx, sy = (s.dx * 0.5 + 0.5) * width, ((1 - (s.dy * 0.5 + 0.5)) ^ 1.6) * (horizonY * 0.92)
                    edgeFade = 1
                end
                if sx and sx > -40 and sx < width + 40 and sy > -40 and sy < height + 40 then
                    love.graphics.setColor(1, 1, 1, a * edgeFade)
                    love.graphics.draw(starImg, sx, sy, rotation or 0, s.scale, s.scale, sw / 2, sh / 2)
                end
            end
        end
    end

    if state.venusAlpha > 0.01 then
        local progress = arcProgress(t, SUN_RISE, SUN_SPAN)
        if progress then
            local x, y, edgeFade, elevationFactor, rotation = nil, nil, nil, nil, 0
            if view then
                local dx, dy, dz, ef = skyDirection(progress, VENUS_AZIMUTH_SPAN, VENUS_MAX_ELEV, VENUS_AZIMUTH_OFFSET)
                elevationFactor = ef
                x, y, edgeFade = projectDirection(dx, dy, dz, view)
                if x then
                    rotation = billboardRotation(dx, dy, dz, x, y, view)
                end
            else
                elevationFactor = math.sin(progress * math.pi) * 0.22
                x, y = flatProject(progress, elevationFactor, width, height, horizonY, arcHeight, sideMargin)
                edgeFade = 1
            end
            if x then
                local vw, vh = venusImg:getDimensions()
                local scale = 0.5 * (zoomScale or 1)
                drawGlow(x, y, 10 * (zoomScale or 1), {0.85, 0.92, 1}, state.venusAlpha * 0.5 * edgeFade)
                love.graphics.setColor(0.9, 0.95, 1, state.venusAlpha * edgeFade)
                love.graphics.draw(venusImg, x, y, rotation, scale, scale, vw / 2, vh / 2)
            end
        end
    end

    if state.moonAlpha > 0.01 then
        local progress = arcProgress(t, MOON_RISE, MOON_SPAN)
        if progress then
            local x, y, edgeFade, elevation, rotation = nil, nil, nil, nil, 0
            if view then
                local dx, dy, dz, ef = skyDirection(progress, MOON_AZIMUTH_SPAN, MOON_MAX_ELEV)
                elevation = ef
                x, y, edgeFade = projectDirection(dx, dy, dz, view)
                if x then
                    rotation = billboardRotation(dx, dy, dz, x, y, view)
                end
            else
                elevation = math.sin(progress * math.pi)
                x, y = flatProject(progress, elevation, width, height, horizonY, arcHeight, sideMargin)
                edgeFade = 1
            end
            if x then
                local nearHorizon = 1 - elevation
                local r = 0.85 + 0.15 * elevation
                local g = 0.87 + 0.13 * elevation
                local b = 0.95
                local mw, mh = moonImg:getDimensions()
                local moonScale = (0.9 + nearHorizon * 0.35) * (zoomScale or 1)
                drawGlow(x, y, 46 * (zoomScale or 1), {0.7, 0.78, 1}, state.moonAlpha * 0.35 * edgeFade)
                love.graphics.setColor(r, g, b, state.moonAlpha * edgeFade)
                love.graphics.draw(moonImg, x, y, rotation, moonScale, moonScale, mw / 2, mh / 2)
            end
        end
    end

    if state.sunAlpha > 0.01 then
        local progress = arcProgress(t, SUN_RISE, SUN_SPAN)
        if progress then
            local x, y, edgeFade, elevation, rotation = nil, nil, nil, nil, 0
            if view then
                local dx, dy, dz, ef = skyDirection(progress, SUN_AZIMUTH_SPAN, SUN_MAX_ELEV)
                elevation = ef
                x, y, edgeFade = projectDirection(dx, dy, dz, view)
                if x then
                    rotation = billboardRotation(dx, dy, dz, x, y, view)
                end
            else
                elevation = math.sin(progress * math.pi)
                x, y = flatProject(progress, elevation, width, height, horizonY, arcHeight, sideMargin)
                edgeFade = 1
            end
            if x then
                local warmth = 1 - elevation
                local sw, sh = sunImg:getDimensions()
                local sunScale = (0.85 + warmth * 0.3) * (zoomScale or 1)
                drawGlow(x, y, (90 - warmth * 20) * (zoomScale or 1), {1, 0.75 - warmth * 0.2, 0.4}, state.sunAlpha * (0.45 + warmth * 0.25) * edgeFade)
                love.graphics.setColor(1, 1, 1, state.sunAlpha * edgeFade)
                love.graphics.draw(sunImg, x, y, rotation, sunScale, sunScale, sw / 2, sh / 2)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

return night