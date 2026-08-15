local love = require "love"
local utils = {}

local floor, sqrt, max, min, abs = math.floor, math.sqrt, math.max, math.min, math.abs
local random = math.random
local sharpTextShader = love.graphics.newShader("shaders/text_unblur.glsl")
sharpTextShader:send("threshold", 0.5)
sharpTextShader:send("tintColor", {1, 1, 1, 1})
local lg = love.graphics

function utils.clamp(v, a, b)
    return v < a and a or (v > b and b or v)
end

function utils.clamp01(x)
    return x < 0 and 0 or (x > 1 and 1 or x)
end

local bit = require("bit")
local bxor, band, lshift = bit.bxor, bit.band, bit.lshift

local function hashNoise(ix, iz)
    local n = ix * 374761393 + iz * 668265263
    n = band(bxor(n, lshift(n,13)), 0xffffffff)
    n = band(n*(n*n*15731 + 789221) + 1376312589, 0xffffffff)
    return (n % 10000) * 0.0001
end
utils.hashNoise = hashNoise

local function smoothNoise(x, z)
    local ix, iz = floor(x), floor(z)
    local fx, fz = x - ix, z - iz

    local v00 = hashNoise(ix, iz)
    local v10 = hashNoise(ix+1, iz)
    local v01 = hashNoise(ix, iz+1)
    local v11 = hashNoise(ix+1, iz+1)

    local ux = fx * fx * (3 - 2 * fx)
    local uz = fz * fz * (3 - 2 * fz)

    local i1 = v00 + (v10 - v00) * ux
    local i2 = v01 + (v11 - v01) * ux

    return i1 + (i2 - i1) * uz
end
utils.smoothNoise = smoothNoise

local function perlin(x, z, octaves, lacunarity, persistence)
    octaves = octaves or 4
    lacunarity = lacunarity or 2
    persistence = persistence or 0.5

    local amplitude, frequency = 1, 1
    local total, maxA = 0, 0

    for o = 1, octaves do
        total = total + smoothNoise(x * frequency, z * frequency) * amplitude
        maxA = maxA + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end

    return total / maxA
end
utils.perlin = perlin

local noiseCache = {}

local function fastPerlin(x, z, octaves, lacunarity, persistence)
    if x == nil or z == nil then
        error("fastPerlin: one of the arguments is nil: x="..tostring(x).." z="..tostring(z))
    end
    local k = x .. "_" .. z .. "_" .. (octaves or "") .. "_" .. (lacunarity or "") .. "_" .. (persistence or "")
    local v = noiseCache[k]
    if v ~= nil then return v end
    v = perlin(x, z, octaves, lacunarity, persistence)
    noiseCache[k] = v
    return v
end
utils.fastPerlin = fastPerlin

function utils.clearNoiseCache()
    noiseCache = {}
end

function utils.randomRange(a, b)
    return random() * (b - a) + a
end

function utils.drawSharpText(text, x, y, limit, align)
    text = text or ""
    x = x or 0
    y = y or 0
    limit = limit or lg.getWidth()
    align = align or "left"
    lg.setShader(sharpTextShader)
    lg.printf(text, x, y, limit, align)
    lg.setShader()
end

function utils.drawTextWithBorder(text, x, y, limit, align, borderColor, textColor)
    text = text or ""
    x = x or 0
    y = y or 0
    limit = limit or lg.getWidth()
    align = align or "left"
    borderColor = borderColor or {0, 0, 0, 1}
    textColor = textColor or {1, 1, 1, 1}

    lg.setShader(sharpTextShader)
    lg.setColor(borderColor)
    lg.printf(text, x - 1, y - 1, limit, align)
    lg.printf(text, x + 1, y - 1, limit, align)
    lg.printf(text, x - 1, y + 1, limit, align)
    lg.printf(text, x + 1, y + 1, limit, align)
    lg.setColor(textColor)
    lg.printf(text, x, y, limit, align)

    lg.setShader()
end

function utils.hsvToRgb(h, s, v)
    local c = v * s
    local hp = h / 60
    local x = c * (1 - abs(hp % 2 - 1))
    local m = v - c

    if hp < 1 then return c + m, x + m, m end
    if hp < 2 then return x + m, c + m, m end
    if hp < 3 then return m, c + m, x + m end
    if hp < 4 then return m, x + m, c + m end
    if hp < 5 then return x + m, m, c + m end
    return c + m, m, x + m
end

function utils.parseColor(hex)
    local r, g, b = hex:match("#?(%x%x)(%x%x)(%x%x)")
    if not r then return {1, 1, 1, 1} end
    return {tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, 1}
end

function utils.any(t, func)
    for k, v in pairs(t) do
        if func(v, k) then
            return true
        end
    end
    return false
end

function utils.normalize(vx, vy, vz)
    local l = sqrt(vx*vx + vy*vy + vz*vz)
    if l == 0 then return 0,1,0 end
    return vx/l, vy/l, vz/l
end

function utils.toByte(v, gamma)
    v = utils.clamp01(v)
    if gamma then
        v = v^(1/gamma)
    end
    return floor(v * 255 + 0.5)
end

function utils.tileKey(x, z)
    return floor(x) .. ":" .. floor(z)
end

function utils.getChunkKey(cx, cz)
    return cx * 10000 + cz
end

return utils