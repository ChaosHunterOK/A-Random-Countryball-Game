local ffi = require "ffi"
local love = require "love"
local gl = require "source.gl.opengl"
local utils = require("source.utils")
local lg = love.graphics
local m = math
local base_width, base_height = 1000, 525
local sqrt, sin, cos, pi, max, floor = m.sqrt, m.sin, m.cos, m.pi, m.max, m.floor

ffi.cdef[[
typedef struct { double dirx, dirz, amplitude, k, speed, steepness, uvSpeed; } Wave;
]]

local Verts = {}
local time = 0

local waveDefs = {
    {dir={1,0.3}, amplitude=0.12, wavelength=6, speed=1.2, steepness=0.9, uvSpeed=0.08},
    {dir={0.6,0.8}, amplitude=0.08, wavelength=3.5, speed=1.6, steepness=0.6, uvSpeed=0.12},
    {dir={0.2,-1}, amplitude=0.04, wavelength=1.8, speed=2.4, steepness=0.45, uvSpeed=0.18},
}

for i,w in ipairs(waveDefs) do
    local dx,dz = w.dir[1], w.dir[2]
    local len = sqrt(dx*dx + dz*dz)
    if len>0 then w.dir[1],w.dir[2] = dx/len, dz/len end
    w.k = 2*pi / w.wavelength
end

local WN = #waveDefs
local waves_ffi = ffi.new("Wave[?]", WN)
for i = 0, WN-1 do
    local w = waveDefs[i+1]
    waves_ffi[i].dirx, waves_ffi[i].dirz = w.dir[1], w.dir[2]
    waves_ffi[i].amplitude, waves_ffi[i].k = w.amplitude, w.k
    waves_ffi[i].speed, waves_ffi[i].steepness = w.speed, w.steepness
    waves_ffi[i].uvSpeed = w.uvSpeed
end

local projBuf = ffi.new("double[8]")
local timeK_ffi = ffi.new("double[?]", WN)
local V1T = {0, 0, 0}
local V2T = {0, 0, 0}
local V3T = {0, 0, 0}
local V4T = {0, 0, 0}
local S1 = {0, 0, 0}
local S2 = {0, 0, 0}
local S3 = {0, 0, 0}
local S4 = {0, 0, 0}

function Verts.setTime(t) time = t or 0 end

local MAX_QUADS = 4000
local VERTS_PER_QUAD = 4
local MAX_OUT = 8000
local outPool = {}
for i = 1, MAX_OUT do
    outPool[i] = {
        verts = {0,0,0,0,0,0,0,0},
        brightness = {0,0,0},
        uvOffset = {u=0, v=0}
    }
end

local function gerstner_f(x, z)
    local y, ox, oz = 0.0, 0.0, 0.0
    for i = 0, WN-1 do
        local w = waves_ffi[i]
        local phase = w.k * (w.dirx * x + w.dirz * z) - timeK_ffi[i]
        local s, c = sin(phase), cos(phase)
        y = y + w.amplitude * s
        local a = w.steepness * w.amplitude
        ox = ox + a * w.dirx * c
        oz = oz + a * w.dirz * c
    end
    return y, ox, oz
end

local meshFormat = {
    {"VertexPosition", "float", 2},
    {"VertexTexCoord", "float", 2},
    {"VertexColor", "float",  4},
}

local clamp01 = utils.clamp01

local function buildMesh(mesh, vertices, uvOffset, vRepeat, texture, fallback, color)
    uvOffset = uvOffset or {u = 0, v = 0}
    vRepeat = vRepeat or 1

    local r, g, b, a = 1, 1, 1, 1
    if type(color) == "table" then
        r, g, b = clamp01(color[1]), clamp01(color[2]), clamp01(color[3])
    elseif type(color) == "number" then
        r, g, b = clamp01(color[1]), clamp01(color[2]), clamp01(color[3])
    end

    mesh:setVertices({
        {vertices[1], vertices[2], 0 + uvOffset.u, 0 + uvOffset.v, r, g, b, a},
        {vertices[3], vertices[4], 1 + uvOffset.u, 0 + uvOffset.v, r, g, b, a},
        {vertices[5], vertices[6], 1 + uvOffset.u, (vRepeat or 1) + uvOffset.v, r, g, b, a},
        {vertices[7], vertices[8], 0 + uvOffset.u, (vRepeat or 1) + uvOffset.v, r, g, b, a},
    })

    local tex = texture or fallback
    if tex then
        tex:setWrap("repeat", "repeat")
        mesh:setTexture(tex)
    end
end

local function isWater(tile, mats)
    local t = tile and tile.texture
    if not t or not mats then return false end
    return t == mats.waterSmall or t == mats.waterMedium or t == mats.waterDeep
end

local neighborOffsets = {
    {nx=0, nz=-1, i1=1, i2=2},
    {nx=1, nz=0, i1=2, i2=3},
    {nx=0, nz=1, i1=4, i2=3},
    {nx=-1,nz=0, i1=1, i2=4},
}

local function isTileInRangeFast(tile, camX, camZ, renderDistanceSq)
    local v1 = tile[1]
    local v3 = tile[3]
    local cx = (v1[1] + v3[1]) * 0.5
    local cz = (v1[3] + v3[3]) * 0.5
    local dx, dz = cx - camX, cz - camZ
    return (dx*dx + dz*dz) <= renderDistanceSq
end

local function projBufToLuaArray(buf)
    return { buf[0], buf[1], buf[2], buf[3], buf[4], buf[5], buf[6], buf[7] }
end

local function projectQuadToBuf(camera, v1, v2, v3, v4, buf)
    local w, h = base_width, base_height
    local sx1, sy1 = camera:project3D(v1[1], v1[2], v1[3])
    if not sx1 then return false end
    local sx2, sy2 = camera:project3D(v2[1], v2[2], v2[3])
    if not sx2 then return false end
    local sx3, sy3 = camera:project3D(v3[1], v3[2], v3[3])
    if not sx3 then return false end
    local sx4, sy4 = camera:project3D(v4[1], v4[2], v4[3])
    if not sx4 then return false end

    if (sx1 < 0 and sx2 < 0 and sx3 < 0 and sx4 < 0) or
       (sx1 > w and sx2 > w and sx3 > w and sx4 > w) or
       (sy1 < 0 and sy2 < 0 and sy3 < 0 and sy4 < 0) or
       (sy1 > h and sy2 > h and sy3 > h and sy4 > h) then
        return false
    end

    buf[0], buf[1] = sx1, sy1
    buf[2], buf[3] = sx2, sy2
    buf[4], buf[5] = sx3, sy3
    buf[6], buf[7] = sx4, sy4
    return true
end

local night = require"source.projectile.night_cycle"
local function dot(ax,ay,az, bx,by,bz) return ax*bx + ay*by + az*bz end

function Verts.generate(tiles, camera, renderDistanceSq, tileGrid, materials)
    if not tiles or not camera then return {} end
    camera:updateProjectionConstants()
    local camX, camZ = camera.x, camera.z
    local uvU, uvV = 0.0, 0.0
    for i = 0, WN-1 do
        local w = waves_ffi[i]
        timeK_ffi[i] = w.speed * time
        uvU = uvU + (w.uvSpeed * w.dirx)
        uvV = uvV + (w.uvSpeed * w.dirz)
    end
    uvU, uvV = (uvU * time) % 1.0, (uvV * time) % 1.0
    local sunAngle = (night.time / (night.dayLength)) * (2 * pi)
    local sunDirX = math.cos(sunAngle)
    local sunDirY = math.sin(sunAngle) * 0.65 + 0.35
    local sunDirZ = math.sin(sunAngle + 0.7)
    sunDirX, sunDirY, sunDirZ = utils.normalize(sunDirX, sunDirY, sunDirZ)

    local textureMul = night.getTextureMultiplier() or {1,1,1}
    local r = textureMul[1]
    local g = textureMul[2]
    local b = textureMul[3]
    local avgMul = (textureMul[1] + textureMul[2] + textureMul[3]) / 3

    local lightFactor = (night.getLight and night.getLight() or 1.0)
    local lightCurve = lightFactor * lightFactor
    local ambient = 0.05 + 1 * lightCurve

    local out = {}
    local outCount = 0

    for t = 1, #tiles do
        local tile = tiles[t]
        if not tile or not tile[1] then goto continue end
        if not isTileInRangeFast(tile, camX, camZ, renderDistanceSq) then goto continue end
        local tx, tz = (tile[1][1] + tile[3][1]) * 0.5, (tile[1][3] + tile[3][3]) * 0.5
        if not camera:isPointInFront(tx, tz) then
            goto continue
        end
        local v1x,v1y,v1z = tile[1][1], tile[1][2], tile[1][3]
        local v2x,v2y,v2z = tile[2][1], tile[2][2], tile[2][3]
        local v3x,v3y,v3z = tile[3][1], tile[3][2], tile[3][3]
        local v4x,v4y,v4z = tile[4][1], tile[4][2], tile[4][3]

        local water = isWater(tile, materials)
        local uvOffset = water and {u = uvU, v = uvV} or {u = 0, v = 0}

        if water then
            local dy, dx, dz
            dy, dx, dz = gerstner_f(v1x, v1z); v1y = v1y + dy; v1x = v1x + dx; v1z = v1z + dz
            dy, dx, dz = gerstner_f(v2x, v2z); v2y = v2y + dy; v2x = v2x + dx; v2z = v2z + dz
            dy, dx, dz = gerstner_f(v3x, v3z); v3y = v3y + dy; v3x = v3x + dx; v3z = v3z + dz
            dy, dx, dz = gerstner_f(v4x, v4z); v4y = v4y + dy; v4x = v4x + dx; v4z = v4z + dz
        end

        V1T[1], V1T[2], V1T[3] = v1x, v1y, v1z
        V2T[1], V2T[2], V2T[3] = v2x, v2y, v2z
        V3T[1], V3T[2], V3T[3] = v3x, v3y, v3z
        V4T[1], V4T[2], V4T[3] = v4x, v4y, v4z

        local tx, tz = floor(tile[1][1]), floor(tile[1][3])
        local hC = tile.height or ((v1y + v2y + v3y + v4y) * 0.25)
        local hL = (tileGrid[tx-1] and tileGrid[tx-1][tz] and tileGrid[tx-1][tz].height) or hC
        local hR = (tileGrid[tx+1] and tileGrid[tx+1][tz] and tileGrid[tx+1][tz].height) or hC
        local hU = (tileGrid[tx] and tileGrid[tx][tz-1] and tileGrid[tx][tz-1].height) or hC
        local hD = (tileGrid[tx] and tileGrid[tx][tz+1] and tileGrid[tx][tz+1].height) or hC

        local dhdx = (hR - hL) * 0.5
        local dhdz = (hD - hU) * 0.5
        local nx, ny, nz = utils.normalize(-dhdx, 1.0, -dhdz)
        local diff = dot(nx, ny, nz, sunDirX, sunDirY, sunDirZ)
        if diff < 0 then diff = 0 end

        local faceBrightness = ambient + diff * (1.0 - ambient) --= ambient + diff * (1.0 - ambient)
        if water then faceBrightness = faceBrightness * 1.05 end
        if faceBrightness > 1 then faceBrightness = 1 end
        faceBrightness = faceBrightness
        local visible = projectQuadToBuf(camera, V1T, V2T, V3T, V4T, projBuf)

        if visible then
            local cx, cz = (tile[1][1] + tile[3][1]) * 0.5 - camX, (tile[1][3] + tile[3][3]) * 0.5 - camZ
            local dist2 = cx*cx + cz*cz
            if dist2 <= renderDistanceSq then
                outCount = outCount + 1
                local entry = outPool[outCount]
                local v = entry.verts
                v[1], v[2], v[3], v[4] = projBuf[0], projBuf[1], projBuf[2], projBuf[3]
                v[5], v[6], v[7], v[8] = projBuf[4], projBuf[5], projBuf[6], projBuf[7]
                
                entry.dist = dist2
                entry.texture = tile.texture
                entry.tile = tile
                entry.uvOffset.u = uvOffset.u
                entry.uvOffset.v = uvOffset.v
                entry.isWater = water
                entry.face = "top"
                entry.vRepeat = 1
                
                local b_arr = entry.brightness
                b_arr[1], b_arr[2], b_arr[3] = r * faceBrightness, g * faceBrightness, b * faceBrightness
            end
        end
        local topY = tile.height or ((v1y + v2y + v3y + v4y) * 0.25)
        for oi = 1, 4 do
            local off = neighborOffsets[oi]
            local nbRow = tileGrid[tx + off.nx]
            local nb = nbRow and nbRow[tz + off.nz]
            local nbHeight = nb and nb.height or 0
            if not nb or (topY - nbHeight > 2) then
                local v1s, v2s = tile[off.i1], tile[off.i2]
                local v1x_s, v1y_s, v1z_s = v1s[1], v1s[2], v1s[3]
                local v2x_s, v2y_s, v2z_s = v2s[1], v2s[2], v2s[3]

                if water then
                    local dy, dx, dz
                    dy, dx, dz = gerstner_f(v1x_s, v1z_s); v1y_s = v1y_s + dy; v1x_s = v1x_s + dx; v1z_s = v1z_s + dz
                    dy, dx, dz = gerstner_f(v2x_s, v2z_s); v2y_s = v2y_s + dy; v2x_s = v2x_s + dx; v2z_s = v2z_s + dz
                end

                S1[1], S1[2], S1[3] = v1x_s, v1y_s, v1z_s
                S2[1], S2[2], S2[3] = v2x_s, v2y_s, v2z_s
                S3[1], S3[2], S3[3] = v2x_s, nbHeight, v2z_s
                S4[1], S4[2], S4[3] = v1x_s, nbHeight, v1z_s

                local ux, uy, uz = S2[1]-S1[1], S2[2]-S1[2], S2[3]-S1[3]
                local vx_, vy_, vz_ = S3[1]-S1[1], S3[2]-S1[2], S3[3]-S1[3]
                local sxn, syn, szn = (uy * vz_ - uz * vy_), (uz * vx_ - ux * vz_), (ux * vy_ - uy * vx_)
                local snx, sny, snz = utils.normalize(sxn, syn, szn)
                local sdiff = dot(snx, sny, snz, sunDirX, sunDirY, sunDirZ)
                if sdiff < 0 then sdiff = 0 end
                local sideBrightness = ambient + sdiff * (1.0 - ambient)
                --sideBrightness = sideBrightness * 0.9
                sideBrightness = sideBrightness * avgMul

                local sideVisible = projectQuadToBuf(camera, S1, S2, S3, S4, projBuf)

                if sideVisible then
                    local midx, midz = (v1x_s + v2x_s) * 0.5 - camX, (v1z_s + v2z_s) * 0.5 - camZ
                    local dist = midx*midx + midz*midz
                    if dist > renderDistanceSq * 0.4 then goto skipSide end
                    if dist <= renderDistanceSq then
                        outCount = outCount + 1
                        local entry = outPool[outCount]
                        local v = entry.verts
                        v[1], v[2], v[3], v[4] = projBuf[0], projBuf[1], projBuf[2], projBuf[3]
                        v[5], v[6], v[7], v[8] = projBuf[4], projBuf[5], projBuf[6], projBuf[7]
                        
                        entry.dist = dist
                        entry.texture = tile.texture
                        entry.tile = tile
                        entry.uvOffset.u = 0
                        entry.uvOffset.v = 0
                        entry.isWater = water
                        entry.face = "side"
                        entry.vRepeat = floor(max(1, topY - nbHeight))
                        
                        local b_arr = entry.brightness
                        b_arr[1], b_arr[2], b_arr[3] = r * sideBrightness, g * sideBrightness, b * sideBrightness
                    end
                    ::skipSide::
                end
            end
        end
        ::continue::
    end

    local result = {}
    for i = 1, outCount do result[i] = outPool[i] end
    table.sort(result, function(a,b) return a.dist > b.dist end)
    return result
end

Verts.meshPool = {}
Verts.meshCount = 0

function Verts.beginFrame()
    Verts.meshCount = 0
end

local function getMesh()
    Verts.meshCount = Verts.meshCount + 1
    if Verts.meshCount > MAX_QUADS then
        return nil
    end

    local m = Verts.meshPool[Verts.meshCount]
    if not m then
        m = lg.newMesh(meshFormat, VERTS_PER_QUAD, "fan", "dynamic")
        Verts.meshPool[Verts.meshCount] = m
    end
    return m
end

function Verts.ensureAllMeshes(visibleTiles, fallback)
    Verts.beginFrame()

    for i = 1, #visibleTiles do
        local t = visibleTiles[i]
        local mesh = getMesh()
        if not mesh then break end

        buildMesh(mesh, t.verts,t.uvOffset, t.vRepeat or 1, t.texture, fallback, t.brightness)

        t.mesh = mesh
    end
end

return Verts