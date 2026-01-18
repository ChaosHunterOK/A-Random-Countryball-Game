local ffi = require "ffi"
local love = require "love"
local utils = require("source.utils")
local night = require "source.projectile.night_cycle"
local lib3d = require "source.projectile.lib3d"
local lg = love.graphics
local m = math
local base_width, base_height = 1000, 525
local sqrt, sin, cos, pi, max, floor = m.sqrt, m.sin, m.cos, m.pi, m.max, m.floor

ffi.cdef[[typedef struct {double dirx, dirz, amplitude, k, speed, steepness, uvSpeed;} Wave;]]

local Verts = {}
Verts.meshPool = {}
Verts.meshCount = 0
local time = 0
local result_table = {}
local outCount = 0
local wrappedTextures = {}

local waveDefs = {
    {dir={1,0.3}, amplitude=0.12, wavelength=6, speed=1.2, steepness=0.9, uvSpeed=0.08},
    {dir={0.6,0.8}, amplitude=0.08, wavelength=3.5, speed=1.6, steepness=0.6, uvSpeed=0.12},
    {dir={0.2,-1}, amplitude=0.04, wavelength=1.8, speed=2.4, steepness=0.45, uvSpeed=0.18},
}

local WN = #waveDefs
local waves_ffi = ffi.new("Wave[?]", WN)
local timeK_ffi = ffi.new("double[?]", WN)

for i = 0, WN-1 do
    local w = waveDefs[i+1]
    local dx, dz = w.dir[1], w.dir[2]
    local len = sqrt(dx*dx + dz*dz)
    local k = 2 * pi / w.wavelength
    waves_ffi[i].dirx = (dx / len) * k
    waves_ffi[i].dirz = (dz / len) * k
    waves_ffi[i].amplitude = w.amplitude
    waves_ffi[i].k = k
    waves_ffi[i].speed = w.speed
    waves_ffi[i].steepness = w.steepness
    waves_ffi[i].uvSpeed = w.uvSpeed
end

local projBuf = ffi.new("double[8]")
local V_TMP = { {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} }
local S_TMP = { {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} }

local MAX_QUADS = 4000
local outPool = {}
for i = 1, MAX_QUADS do 
    outPool[i] = {
        verts = ffi.new("float[8]"),
        brightness = {0, 0, 0},
        uvOffset = {u=0, v=0},
        dist = 0,
        hC = 0,
        gridX = 0,
        gridZ = 0
    }
end

local function gerstner_f(x, z)
    local y, ox, oz = 0.0, 0.0, 0.0
    for i = 0, WN-1 do
        local w = waves_ffi[i]
        local phase = (w.dirx * x + w.dirz * z) - timeK_ffi[i]
        local s, c = sin(phase), cos(phase)
        y = y + w.amplitude * s
        local a = (w.steepness * w.amplitude) / w.k
        ox = ox + a * w.dirx * c
        oz = oz + a * w.dirz * c
    end
    return y, ox, oz
end

local waterShader = nil
if love.filesystem.getInfo("shaders/water.glsl") then
    local ok, code = pcall(function() return love.filesystem.read("shaders/water.glsl") end)
    if ok and code then
        pcall(function() waterShader = lg.newShader(code) end)
    end
end
Verts.waterShader = waterShader

local function projectQuadToBuf(camera, v1, v2, v3, v4, buf)
    local sx1, sy1 = camera:project3D(v1[1], v1[2], v1[3])
    if not sx1 then return false end
    local sx2, sy2 = camera:project3D(v2[1], v2[2], v2[3])
    if not sx2 then return false end
    local sx3, sy3 = camera:project3D(v3[1], v3[2], v3[3])
    if not sx3 then return false end
    local sx4, sy4 = camera:project3D(v4[1], v4[2], v4[3])
    if not sx4 then return false end

    if (sx1 < 0 and sx2 < 0 and sx3 < 0 and sx4 < 0) or
       (sx1 > base_width and sx2 > base_width and sx3 > base_width and sx4 > base_width) or
       (sy1 < 0 and sy2 < 0 and sy3 < 0 and sy4 < 0) or
       (sy1 > base_height and sy2 > base_height and sy3 > base_height and sy4 > base_height) then
        return false
    end

    buf[0], buf[1], buf[2], buf[3] = sx1, sy1, sx2, sy2
    buf[4], buf[5], buf[6], buf[7] = sx3, sy3, sx4, sy4
    return true
end

local neighborOffsets = {
    {nx=0, nz=-1, i1=1, i2=2},
    {nx=1, nz=0, i1=2, i2=3},
    {nx=0, nz=1, i1=3, i2=4},
    {nx=-1,nz=0, i1=4, i2=1},
}

function Verts.generate(tiles, camera, renderDistanceSq, tileGrid, materials)
    if not tiles or not camera then return {} end
    camera:updateProjectionConstants()
    
    local camX, camZ = camera.x, camera.z
    local uvU, uvV = 0, 0
    local timeVal = time
    
    for i = 0, WN-1 do
        local w = waves_ffi[i]
        timeK_ffi[i] = w.speed * timeVal
        uvU = uvU + (w.uvSpeed * w.dirx)
        uvV = uvV + (w.uvSpeed * w.dirz)
    end
    uvU, uvV = (uvU * timeVal) % 1, (uvV * timeVal) % 1

    local sunAngle = (night.time / night.dayLength) * (2 * pi)
    local cosSun, sinSun = cos(sunAngle), sin(sunAngle)
    local sDX = cosSun
    local sDY = sinSun * 0.65 + 0.35
    local sDZ = sin(sunAngle + 0.7)
    local slen = sqrt(sDX*sDX + sDY*sDY + sDZ*sDZ)
    sDX, sDY, sDZ = sDX/slen, sDY/slen, sDZ/slen

    local texMul = night.getTextureMultiplier() or {1, 1, 1}
    local tr, tg, tb = texMul[1], texMul[2], texMul[3]
    local avgMul = (tr + tg + tb) * 0.33333
    local lF = (night.getLight and night.getLight() or 1.0)
    local ambient = 0.05 + (lF * lF)
    local invAmbient = 1.0 - ambient

    outCount = 0
    local waterSmall, waterMed, waterDeep = materials.waterSmall, materials.waterMedium, materials.waterDeep
    local invAmbient2 = invAmbient * 1.05
    local tileCount = #tiles
    
    local hwDist = camera.hw
    local camZoom = camera.zoom
    local fovTan = camera._fovTan or math.tan(math.rad(camera.fov / 2))
    camera._fovTan = fovTan

    for t = 1, tileCount do
        if outCount >= MAX_QUADS then break end
        
        local tile = tiles[t]
        local t1, t3 = tile[1], tile[3]
        local v1x, v1y, v1z = t1[1], t1[2], t1[3]
        local v3x, v3y, v3z = t3[1], t3[2], t3[3]

        local tx, tz = (v1x + v3x) * 0.5, (v1z + v3z) * 0.5
        local dx, dz = tx - camX, tz - camZ
        local dist2 = dx*dx + dz*dz
        if dist2 > renderDistanceSq then goto continue end

        local t2, t4 = tile[2], tile[4]
        local v2x, v2y, v2z = t2[1], t2[2], t2[3]
        local v4x, v4y, v4z = t4[1], t4[2], t4[3]

        local tex = tile.texture
        local isWater = (tex == waterSmall or tex == waterMed or tex == waterDeep)

        if isWater then
            local dy, dx, dz
            dy, dx, dz = gerstner_f(v1x, v1z); v1y = v1y + dy; v1x = v1x + dx; v1z = v1z + dz
            dy, dx, dz = gerstner_f(v2x, v2z); v2y = v2y + dy; v2x = v2x + dx; v2z = v2z + dz
            dy, dx, dz = gerstner_f(v3x, v3z); v3y = v3y + dy; v3x = v3x + dx; v3z = v3z + dz
            dy, dx, dz = gerstner_f(v4x, v4z); v4y = v4y + dy; v4x = v4x + dx; v4z = v4z + dz
        end

        V_TMP[1][1], V_TMP[1][2], V_TMP[1][3] = v1x, v1y, v1z
        V_TMP[2][1], V_TMP[2][2], V_TMP[2][3] = v2x, v2y, v2z
        V_TMP[3][1], V_TMP[3][2], V_TMP[3][3] = v3x, v3y, v3z
        V_TMP[4][1], V_TMP[4][2], V_TMP[4][3] = v4x, v4y, v4z

        if projectQuadToBuf(camera, V_TMP[1], V_TMP[2], V_TMP[3], V_TMP[4], projBuf) then
            local gridX, gridZ = floor(t1[1]), floor(t1[3])
            local hC = tile.height or ((v1y + v2y + v3y + v4y) * 0.25)
            local rowL, rowR, rowC = tileGrid[gridX-1], tileGrid[gridX+1], tileGrid[gridX]
            local hL = (rowL and rowL[gridZ] and rowL[gridZ].height) or hC
            local hR = (rowR and rowR[gridZ] and rowR[gridZ].height) or hC
            local hU = (rowC and rowC[gridZ-1] and rowC[gridZ-1].height) or hC
            local hD = (rowC and rowC[gridZ+1] and rowC[gridZ+1].height) or hC

            local nx, ny, nz = -(hR - hL) * 0.5, 1.0, -(hD - hU) * 0.5
            nx, ny, nz = lib3d.vec3Normalize(nx, ny, nz)
            
            local dotV = lib3d.vec3Dot(nx, ny, nz, sDX, sDY, sDZ)
            local diff = (dotV < 0) and 0 or dotV
            local br = ambient + diff * (isWater and invAmbient2 or invAmbient)
            if br > 1 then br = 1 end

            outCount = outCount + 1
            local entry = outPool[outCount]
            for j=0,7 do entry.verts[j] = projBuf[j] end
            entry.dist = dist2
            entry.texture = tex
            entry.uvOffset.u = isWater and uvU or 0
            entry.uvOffset.v = isWater and uvV or 0
            entry.vRepeat = 1
            local b_arr = entry.brightness
            b_arr[1], b_arr[2], b_arr[3] = tr, tg, tb
            entry.isWater = isWater
        end
        do
            local gridX, gridZ = floor(t1[1]), floor(t1[3])
            local hC = tile.height or ((v1y + v2y + v3y + v4y) * 0.25)
            local water = isWater
            local topY = hC
            local tileTexture = tile.texture
            for oi = 1, 4 do
                local off = neighborOffsets[oi]
                local nbRow = tileGrid[gridX + off.nx]
                local nb = nbRow and nbRow[gridZ + off.nz]
                local nbHeight = nb and nb.height or 0
                if not nb or (topY - nbHeight > 1.25) then
                    local v1s, v2s = tile[off.i1], tile[off.i2]
                    local v1x_s, v1y_s, v1z_s = v1s[1], v1s[2], v1s[3]
                    local v2x_s, v2y_s, v2z_s = v2s[1], v2s[2], v2s[3]

                    if water then
                        local dy, dx, dz
                        dy, dx, dz = gerstner_f(v1x_s, v1z_s); v1y_s = v1y_s + dy; v1x_s = v1x_s + dx; v1z_s = v1z_s + dz
                        dy, dx, dz = gerstner_f(v2x_s, v2z_s); v2y_s = v2y_s + dy; v2x_s = v2x_s + dx; v2z_s = v2z_s + dz
                    end

                    local S1, S2, S3, S4 = S_TMP[1], S_TMP[2], S_TMP[3], S_TMP[4]
                    S1[1], S1[2], S1[3] = v1x_s, v1y_s, v1z_s
                    S2[1], S2[2], S2[3] = v2x_s, v2y_s, v2z_s
                    S3[1], S3[2], S3[3] = v2x_s, nbHeight, v2z_s
                    S4[1], S4[2], S4[3] = v1x_s, nbHeight, v1z_s

                    local ux, uy, uz = S2[1]-S1[1], S2[2]-S1[2], S2[3]-S1[3]
                    local vx_, vy_, vz_ = S3[1]-S1[1], S3[2]-S1[2], S3[3]-S1[3]
                    local sxn, syn, szn = lib3d.vec3Cross(ux, uy, uz, vx_, vy_, vz_)
                    local snx, sny, snz = lib3d.vec3Normalize(sxn, syn, szn)
                    local sdiff = lib3d.vec3Dot(snx, sny, snz, sDX, sDY, sDZ)
                    if sdiff < 0 then sdiff = 0 end
                    local sideBrightness = ambient + sdiff * (1.0 - ambient)
                    sideBrightness = sideBrightness * avgMul

                    local sideVisible = projectQuadToBuf(camera, S1, S2, S3, S4, projBuf)
                    if sideVisible then
                        local midx, midz = (v1x_s + v2x_s) * 0.5 - camX, (v1z_s + v2z_s) * 0.5 - camZ
                        local dist = midx*midx + midz*midz
                        if not (dist > renderDistanceSq * 0.4) and dist <= renderDistanceSq then
                            outCount = outCount + 1
                            local entry = outPool[outCount]
                            for j=0,7 do entry.verts[j] = projBuf[j] end
                            entry.dist = dist
                            entry.texture = tileTexture
                            entry.tile = tile
                            entry.uvOffset.u = 0
                            entry.uvOffset.v = 0
                            entry.isWater = water
                            entry.face = "side"
                            entry.vRepeat = floor(max(1, topY - nbHeight))

                            local b_arr = entry.brightness
                            b_arr[1], b_arr[2], b_arr[3] = tr, tg, tb
                        end
                    end
                end
            end
        end

        ::continue::
    end

    for i = 1, outCount do result_table[i] = outPool[i] end
    for i = outCount + 1, #result_table do result_table[i] = nil end
    
    table.sort(result_table, function(a, b) return a.dist > b.dist end)
    return result_table
end

function Verts.ensureAllMeshes(visibleTiles, fallback)
    Verts.meshCount = 0
    local meshFormat = {
        {"VertexPosition", "float", 2},
        {"VertexTexCoord", "float", 2},
        {"VertexColor", "float", 4},
    }
    
    local poolIdx = 1

    for i = 1, #visibleTiles do
        local t = visibleTiles[i]
        Verts.meshCount = i
        
        local mesh = Verts.meshPool[poolIdx]
        if not mesh then
            mesh = lg.newMesh(meshFormat, 4, "fan", "dynamic")
            Verts.meshPool[poolIdx] = mesh
        end
        poolIdx = poolIdx + 1

        local v = t.verts
        local uv = t.uvOffset
        local br = t.brightness
        local vr = t.vRepeat or 1
        
        mesh:setVertices({
            {v[0], v[1], 0 + uv.u, 0 + uv.v, br[1], br[2], br[3], 1},
            {v[2], v[3], 1 + uv.u, 0 + uv.v, br[1], br[2], br[3], 1},
            {v[4], v[5], 1 + uv.u, vr + uv.v, br[1], br[2], br[3], 1},
            {v[6], v[7], 0 + uv.u, vr + uv.v, br[1], br[2], br[3], 1},
        })
        
        local tex = t.texture or fallback
        if tex then
            if not wrappedTextures[tex] then
                tex:setWrap("repeat", "repeat")
                wrappedTextures[tex] = true
            end
            mesh:setTexture(tex)
        end
        t.mesh = mesh
    end
    
    local poolSize = #Verts.meshPool
    if poolSize > Verts.meshCount + 64 then
        for i = Verts.meshCount + 1, poolSize do
            local mesh = Verts.meshPool[i]
            if mesh then
                mesh:release()
                Verts.meshPool[i] = nil
            end
        end
    end
end

function Verts.setTime(t)
    time = t or 0
    if waterShader then
        pcall(function() waterShader:send("time", time) end)
    end
end

return Verts