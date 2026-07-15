local ffi = require "ffi"
local love = require "love"
local utils = require("source.utils")
local night = require "source.projectile.night_cycle"
local lib3d = require "source.projectile.lib3d"
local lg = love.graphics
local m = math
local base_width, base_height = 1000, 525
local sqrt, sin, cos, pi, max, floor = m.sqrt, m.sin, m.cos, m.pi, m.max, m.floor
local glOk, glcompat = pcall(require, "source.gl.opengles2")
if not glOk then glcompat = nil end

ffi.cdef[[
    typedef struct {double dirx, dirz, amplitude, k, speed, steepness, uvSpeed;} Wave;
    typedef struct {float x, y, u, v, r, g, b, a;} TerrainVert;
]]

local Verts = {}
Verts.meshPool = {}
local time = 0
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

local projBuf = ffi.new("double[12]")
local V_TMP = { {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} }
local S_TMP = { {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} }

local MAX_QUADS = 4000
local outPool = {}
for i = 1, MAX_QUADS do
    outPool[i] = {
        verts = ffi.new("float[12]"),
        brightness = {0, 0, 0},
        uvOffset = {u=0, v=0},
        dist = 0,
        alpha = 1.0,
        face = "top",
        isWater = false,
        texture = nil,
        vRepeat = 1,
    }
end
local result_table = {}
local outCount = 0

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
    local sx1, sy1, sz1 = camera:project3D(v1[1], v1[2], v1[3])
    if not sx1 then return false end
    local sx2, sy2, sz2 = camera:project3D(v2[1], v2[2], v2[3])
    if not sx2 then return false end
    local sx3, sy3, sz3 = camera:project3D(v3[1], v3[2], v3[3])
    if not sx3 then return false end
    local sx4, sy4, sz4 = camera:project3D(v4[1], v4[2], v4[3])
    if not sx4 then return false end

    if (sx1 < 0 and sx2 < 0 and sx3 < 0 and sx4 < 0) or
       (sx1 > base_width and sx2 > base_width and sx3 > base_width and sx4 > base_width) or
       (sy1 < 0 and sy2 < 0 and sy3 < 0 and sy4 < 0) or
       (sy1 > base_height and sy2 > base_height and sy3 > base_height and sy4 > base_height) then
        return false
    end

    buf[0], buf[1], buf[2] = sx1, sy1, sz1
    buf[3], buf[4], buf[5] = sx2, sy2, sz2
    buf[6], buf[7], buf[8] = sx3, sy3, sz3
    buf[9], buf[10], buf[11] = sx4, sy4, sz4
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

    for t = 1, tileCount do
        if outCount >= MAX_QUADS then break end

        local tile = tiles[t]
        local t1, t3 = tile[1], tile[3]
        local v1x, v1y, v1z = t1[1], t1[2], t1[3]
        local v3x, v3y, v3z = t3[1], t3[2], t3[3]

        local t2, t4 = tile[2], tile[4]
        local v2x, v2y, v2z = t2[1], t2[2], t2[3]
        local v4x, v4y, v4z = t4[1], t4[2], t4[3]

        local tx, tz = (v1x + v3x) * 0.5, (v1z + v3z) * 0.5
        local ty = (v1y + v2y + v3y + v4y) * 0.25
        local dx, dy, dz = tx - camX, ty - camera.y, tz - camZ
        local dist2 = dx*dx + dz*dz
        local tileRadius = 1.5
        if dist2 > (renderDistanceSq + tileRadius * tileRadius) then goto continue end

        local tex = tile.texture
        local isWater = (tex == waterSmall or tex == waterMed or tex == waterDeep)

        if isWater then
            dist2 = dist2 - 0.01
            local wy, wx, wz
            wy, wx, wz = gerstner_f(v1x, v1z); v1y = v1y + wy; v1x = v1x + wx; v1z = v1z + wz
            wy, wx, wz = gerstner_f(v2x, v2z); v2y = v2y + wy; v2x = v2x + wx; v2z = v2z + wz
            wy, wx, wz = gerstner_f(v3x, v3z); v3y = v3y + wy; v3x = v3x + wx; v3z = v3z + wz
            wy, wx, wz = gerstner_f(v4x, v4z); v4y = v4y + wy; v4x = v4x + wx; v4z = v4z + wz
        end

        V_TMP[1][1], V_TMP[1][2], V_TMP[1][3] = v1x, v1y, v1z
        V_TMP[2][1], V_TMP[2][2], V_TMP[2][3] = v2x, v2y, v2z
        V_TMP[3][1], V_TMP[3][2], V_TMP[3][3] = v3x, v3y, v3z
        V_TMP[4][1], V_TMP[4][2], V_TMP[4][3] = v4x, v4y, v4z

        if outCount < MAX_QUADS and projectQuadToBuf(camera, V_TMP[1], V_TMP[2], V_TMP[3], V_TMP[4], projBuf) then
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
            local ev = entry.verts
            for j=0,11 do ev[j] = projBuf[j] end
            entry.dist = dx*dx + dy*dy + dz*dz
            entry.texture = tex
            entry.uvOffset.u = isWater and uvU or 0
            entry.uvOffset.v = isWater and uvV or 0
            entry.vRepeat = 1
            local b_arr = entry.brightness
            b_arr[1], b_arr[2], b_arr[3] = tr, tg, tb
            entry.isWater = isWater
            entry.alpha = isWater and 0.55 or 1.0
            entry.face = "top"
        end
        do
            local gridX, gridZ = floor(t1[1]), floor(t1[3])
            local hC = tile.height or ((v1y + v2y + v3y + v4y) * 0.25)
            local water = isWater
            local topY = hC
            local tileTexture = tile.texture
            for oi = 1, 4 do
                if outCount >= MAX_QUADS then break end
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
                        outCount = outCount + 1
                        local entry = outPool[outCount]
                        local ev = entry.verts
                        for j=0,11 do ev[j] = projBuf[j] end
                        entry.dist = dx*dx + dy*dy + dz*dz
                        entry.texture = tileTexture
                        entry.uvOffset.u = 0
                        entry.uvOffset.v = 0
                        entry.isWater = false
                        entry.alpha = 1.0
                        entry.face = "side"
                        entry.vRepeat = floor(max(1, topY - nbHeight))

                        local b_arr = entry.brightness
                        b_arr[1], b_arr[2], b_arr[3] = tr, tg, tb
                    end
                end
            end
        end

        ::continue::
    end

    for i = 1, outCount do result_table[i] = outPool[i] end
    for i = outCount + 1, #result_table do result_table[i] = nil end
    return result_table
end
local VFORMAT = {
    {"VertexPosition", "float", 2},
    {"VertexTexCoord", "float", 2},
    {"VertexColor", "float", 4},
}
local TERRAIN_VERT_SIZE = ffi.sizeof("TerrainVert")
local INITIAL_BATCH_QUADS = 128
local DEPTH_BUCKETS = 64

Verts.batches = {}
local activeBatches = {}
local activeBatchCount = 0
local terrainDrawList = {}
local terrainDrawCount = 0

local function buildVertexMap(capacityQuads)
    local map = {}
    for i = 0, capacityQuads - 1 do
        local base = i * 4
        local o = i * 6
        map[o+1] = base+1
        map[o+2] = base+2
        map[o+3] = base+3
        map[o+4] = base+1
        map[o+5] = base+3
        map[o+6] = base+4
    end
    return map
end

local function newBatch(capacityQuads)
    local vcount = capacityQuads * 4
    local data = love.data.newByteData(vcount * TERRAIN_VERT_SIZE)
    local ptrOk, ptr = pcall(function() return ffi.cast("TerrainVert*", data:getFFIPointer()) end)
    if not ptrOk then
        ptr = ffi.cast("TerrainVert*", data:getPointer())
    end
    local mesh = lg.newMesh(VFORMAT, vcount, "triangles", "stream")
    mesh:setVertexMap(buildVertexMap(capacityQuads))
    return {
        mesh = mesh,
        data = data,
        ptr = ptr,
        capacity = capacityQuads,
        quadCount = 0,
    }
end

local function getOrCreateBatch(tex, bucket)
    local perTex = Verts.batches[tex]
    if not perTex then
        perTex = {}
        Verts.batches[tex] = perTex
    end
    local batch = perTex[bucket]
    if not batch then
        batch = newBatch(INITIAL_BATCH_QUADS)
        perTex[bucket] = batch
    end
    return batch
end

local function writeQuad(tex, bucket, batch, q)
    if batch.quadCount >= batch.capacity then
        local grown = newBatch(batch.capacity * 2)
        grown.quadCount = batch.quadCount
        Verts.batches[tex][bucket] = grown
        batch = grown
    end

    local idx = batch.quadCount
    local ptr = batch.ptr
    local base = idx * 4
    local v = q.verts
    local uv = q.uvOffset
    local vr = q.vRepeat or 1
    local br = q.brightness
    local r, g, b, a = br[1], br[2], br[3], q.alpha or 1.0

    local p0 = ptr[base]
    p0.x, p0.y, p0.u, p0.v = v[0], v[1], uv.u, uv.v
    p0.r, p0.g, p0.b, p0.a = r, g, b, a

    local p1 = ptr[base+1]
    p1.x, p1.y, p1.u, p1.v = v[3], v[4], uv.u + 1, uv.v
    p1.r, p1.g, p1.b, p1.a = r, g, b, a

    local p2 = ptr[base+2]
    p2.x, p2.y, p2.u, p2.v = v[6], v[7], uv.u + 1, uv.v + vr
    p2.r, p2.g, p2.b, p2.a = r, g, b, a

    local p3 = ptr[base+3]
    p3.x, p3.y, p3.u, p3.v = v[9], v[10], uv.u, uv.v + vr
    p3.r, p3.g, p3.b, p3.a = r, g, b, a

    batch.quadCount = idx + 1
end

local transparentPool = {}
local transparentCount = 0

local function prepareTransparent(count, fallback)
    for i = count + 1, #transparentPool do transparentPool[i] = nil end
    table.sort(transparentPool, function(a, b) return a.dist > b.dist end)

    for i = 1, count do
        local t = transparentPool[i]
        local mesh = Verts.meshPool[i]
        if not mesh then
            mesh = lg.newMesh(VFORMAT, 4, "fan", "dynamic")
            Verts.meshPool[i] = mesh
        end
        local v, uv, br = t.verts, t.uvOffset, t.brightness
        local vr = t.vRepeat or 1
        local alpha = t.alpha or 0.55
        mesh:setVertices({
            {v[0], v[1],   uv.u,     uv.v,      br[1], br[2], br[3], alpha},
            {v[3], v[4],   uv.u + 1, uv.v,      br[1], br[2], br[3], alpha},
            {v[6], v[7],   uv.u + 1, uv.v + vr, br[1], br[2], br[3], alpha},
            {v[9], v[10],  uv.u,     uv.v + vr, br[1], br[2], br[3], alpha},
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
end
function Verts.buildBatches(visibleQuads, fallback)
    for i = 1, activeBatchCount do
        local e = activeBatches[i]
        local perTex = Verts.batches[e.tex]
        local batch = perTex and perTex[e.bucket]
        if batch then batch.quadCount = 0 end
        activeBatches[i] = nil
    end
    activeBatchCount = 0
    terrainDrawCount = 0

    local n = #visibleQuads
    local minD, maxD = math.huge, -math.huge
    for i = 1, n do
        local q = visibleQuads[i]
        if not (q.isWater and q.face == "top") then
            local d = q.dist
            if d < minD then minD = d end
            if d > maxD then maxD = d end
        end
    end
    local range = maxD - minD
    if range <= 0 or range ~= range then range = 1 end
    local bucketScale = DEPTH_BUCKETS / range

    transparentCount = 0
    for i = 1, n do
        local q = visibleQuads[i]
        if q.isWater and q.face == "top" then
            transparentCount = transparentCount + 1
            transparentPool[transparentCount] = q
        else
            local tex = q.texture or fallback
            if tex then
                local bucket = floor((q.dist - minD) * bucketScale)
                if bucket < 0 then bucket = 0 end
                if bucket >= DEPTH_BUCKETS then bucket = DEPTH_BUCKETS - 1 end

                local batch = getOrCreateBatch(tex, bucket)
                if batch.quadCount == 0 then
                    activeBatchCount = activeBatchCount + 1
                    activeBatches[activeBatchCount] = {tex = tex, bucket = bucket}
                end
                writeQuad(tex, bucket, batch, q)
            end
        end
    end

    for i = 1, activeBatchCount do
        local e = activeBatches[i]
        local batch = Verts.batches[e.tex][e.bucket]
        batch.mesh:setVertices(batch.data)
        batch.mesh:setDrawRange(1, batch.quadCount * 6)
        if not wrappedTextures[e.tex] then
            e.tex:setWrap("repeat", "repeat")
            wrappedTextures[e.tex] = true
        end
        batch.mesh:setTexture(e.tex)

        terrainDrawCount = terrainDrawCount + 1
        terrainDrawList[terrainDrawCount] = {
            dist = minD + (e.bucket + 0.5) / bucketScale,
            mesh = batch.mesh,
        }
    end
    for i = terrainDrawCount + 1, #terrainDrawList do terrainDrawList[i] = nil end
    table.sort(terrainDrawList, function(a, b) return a.dist > b.dist end)

    prepareTransparent(transparentCount, fallback)
    return transparentPool, transparentCount, terrainDrawList, terrainDrawCount
end

function Verts.drawTerrainMesh(mesh)
    if glcompat then
        glcompat.enable(glcompat.GL_CULL_FACE)
        glcompat.cullFace(glcompat.GL_BACK)
    end
    lg.setColor(1, 1, 1, 1)
    lg.draw(mesh)
    if glcompat then
        glcompat.disable(glcompat.GL_CULL_FACE)
    end
end

function Verts.ensureAllMeshes(visibleTiles, fallback)
    return Verts.buildBatches(visibleTiles, fallback)
end

function Verts.setTime(t)
    time = t or 0
    if waterShader then
        pcall(function() waterShader:send("time", time) end)
    end
end

return Verts
