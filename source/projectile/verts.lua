local ffi = require "ffi"
local love = require "love"
local night = require "source.projectile.night_cycle"
local lg = love.graphics
local m = math
local sqrt, sin, cos, pi, min, floor = m.sqrt, m.sin, m.cos, m.pi, m.min, m.floor
local glOk, glcompat = pcall(require, "source.gl.opengles2")
if not glOk then glcompat = nil end

ffi.cdef[[
    typedef struct {double dirx, dirz, amplitude, k, speed, steepness, uvSpeed;} Wave;
    typedef struct {float x, y, u, v, r, g, b, a;} TerrainVert;
]]

local Verts = {}
Verts.meshPool = {}
Verts.batches = {}
local time = 0
local wrappedTextures = {}

local function ensureWrap(tex)
    if tex and not wrappedTextures[tex] then
        tex:setWrap("repeat", "repeat")
        wrappedTextures[tex] = true
    end
end

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

local MAX_QUADS = 4000
local outPool = {}
for i = 1, MAX_QUADS do
    outPool[i] = {
        verts = ffi.new("float[12]"),
        brightness = {0, 0, 0},
        uvOffset = {u = 0, v = 0},
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

local projBuf = ffi.new("double[12]")
local QUAD = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}, {0, 0, 0}}

local function projectQuadToBuf(camera, v1, v2, v3, v4, buf)
    local sx1, sy1, sz1 = camera:project3D(v1[1], v1[2], v1[3])
    if not sx1 then return false end
    local sx2, sy2, sz2 = camera:project3D(v2[1], v2[2], v2[3])
    if not sx2 then return false end
    local sx3, sy3, sz3 = camera:project3D(v3[1], v3[2], v3[3])
    if not sx3 then return false end
    local sx4, sy4, sz4 = camera:project3D(v4[1], v4[2], v4[3])
    if not sx4 then return false end

    local screenW, screenH = camera.hw * 2, camera.hh * 2
    if (sx1 < 0 and sx2 < 0 and sx3 < 0 and sx4 < 0) or
       (sx1 > screenW and sx2 > screenW and sx3 > screenW and sx4 > screenW) or
       (sy1 < 0 and sy2 < 0 and sy3 < 0 and sy4 < 0) or
       (sy1 > screenH and sy2 > screenH and sy3 > screenH and sy4 > screenH) then
        return false
    end

    buf[0], buf[1], buf[2] = sx1, sy1, sz1
    buf[3], buf[4], buf[5] = sx2, sy2, sz2
    buf[6], buf[7], buf[8] = sx3, sy3, sz3
    buf[9], buf[10], buf[11] = sx4, sy4, sz4
    return true
end

local function pushQuad(camera, v1, v2, v3, v4, texture, face, dist,
                         brR, brG, brB, alpha, isWater, uvU, uvV, vRepeat)
    if outCount >= MAX_QUADS then return false end
    if not projectQuadToBuf(camera, v1, v2, v3, v4, projBuf) then return false end

    outCount = outCount + 1
    local entry = outPool[outCount]
    local ev = entry.verts
    for j = 0, 11 do ev[j] = projBuf[j] end

    entry.dist = dist
    entry.texture = texture
    entry.face = face
    entry.isWater = isWater or false
    entry.alpha = alpha or 1.0
    entry.uvOffset.u = uvU or 0
    entry.uvOffset.v = uvV or 0
    entry.vRepeat = vRepeat or 1

    local b = entry.brightness
    b[1], b[2], b[3] = brR, brG, brB
    return true
end

local neighborOffsets = {
    {nx=0, nz=-1, i1=1, i2=2},
    {nx=1, nz=0, i1=2, i2=3},
    {nx=0, nz=1, i1=3, i2=4},
    {nx=-1,nz=0, i1=4, i2=1},
}

local BAND_HEIGHT = 1
local MIN_WALL_HEIGHT = 0.7

local function getBandTexture(tile, bandIndex, materials, fallbackTex)
    local sub = tile.subsurface
    local matName = sub and sub[bandIndex]
    if not matName then matName = "stone" end
    return materials[matName] or fallbackTex
end

function Verts.generate(tiles, camera, renderDistanceSq, tileGrid, materials)
    if not tiles or not camera then return {} end
    camera:updateProjectionConstants()
    local camX, camY, camZ = camera.x, camera.y, camera.z
    local timeVal = time

    local uvU, uvV = 0, 0
    for i = 0, WN-1 do
        local w = waves_ffi[i]
        timeK_ffi[i] = w.speed * timeVal
        uvU = uvU + (w.uvSpeed * w.dirx)
        uvV = uvV + (w.uvSpeed * w.dirz)
    end
    uvU, uvV = (uvU * timeVal) % 1, (uvV * timeVal) % 1
    local texMul = night.getTextureMultiplier() or {1, 1, 1}
    local tr, tg, tb = texMul[1], texMul[2], texMul[3]

    outCount = 0
    local waterSmall, waterMed, waterDeep = materials.waterSmall, materials.waterMedium, materials.waterDeep
    local tileCount = #tiles
    local TILE_RADIUS = 1.5

    for t = 1, tileCount do
        if outCount >= MAX_QUADS then break end

        local tile = tiles[t]
        if not tile then goto continue end
        if tile.isAir or not tile.texture then goto drawCave end

        do
            local c1, c2, c3, c4 = tile[1], tile[2], tile[3], tile[4]
            local v1x, v1y, v1z = c1[1], c1[2], c1[3]
            local v2x, v2y, v2z = c2[1], c2[2], c2[3]
            local v3x, v3y, v3z = c3[1], c3[2], c3[3]
            local v4x, v4y, v4z = c4[1], c4[2], c4[3]

            local tx, tz = (v1x + v3x) * 0.5, (v1z + v3z) * 0.5
            local ty = (v1y + v2y + v3y + v4y) * 0.25
            local dx, dy, dz = tx - camX, ty - camY, tz - camZ
            if (dx * dx + dz * dz) > (renderDistanceSq + TILE_RADIUS * TILE_RADIUS) then
                goto continue
            end

            local tex = tile.texture
            local isWater = (tex == waterSmall or tex == waterMed or tex == waterDeep)
            local isLava = tile.isLava or false
            local dist = dx * dx + dy * dy + dz * dz
            if isWater then
                dist = dist - 0.01
                local wy, wx, wz
                wy, wx, wz = gerstner_f(v1x, v1z); v1y = v1y + wy; v1x = v1x + wx; v1z = v1z + wz
                wy, wx, wz = gerstner_f(v2x, v2z); v2y = v2y + wy; v2x = v2x + wx; v2z = v2z + wz
                wy, wx, wz = gerstner_f(v3x, v3z); v3y = v3y + wy; v3x = v3x + wx; v3z = v3z + wz
                wy, wx, wz = gerstner_f(v4x, v4z); v4y = v4y + wy; v4x = v4x + wx; v4z = v4z + wz
            end
            local lavaGlow
            if isLava then
                lavaGlow = 0.8 + 0.2 * sin(timeVal * 2.2 + (tile.x + tile.z) * 0.6)
            end
            local gridX, gridZ = floor(v1x), floor(v1z)
            local topY = tile.height or ty

            local topR, topG, topB
            if isLava then
                topR, topG, topB = lavaGlow, lavaGlow * 0.45, lavaGlow * 0.15
            else
                topR, topG, topB = tr, tg, tb
            end

            QUAD[1][1], QUAD[1][2], QUAD[1][3] = v1x, v1y, v1z
            QUAD[2][1], QUAD[2][2], QUAD[2][3] = v2x, v2y, v2z
            QUAD[3][1], QUAD[3][2], QUAD[3][3] = v3x, v3y, v3z
            QUAD[4][1], QUAD[4][2], QUAD[4][3] = v4x, v4y, v4z

            pushQuad(camera, QUAD[1], QUAD[2], QUAD[3], QUAD[4],
                tex, "top", dist,
                topR, topG, topB,
                isWater and 0.55 or 1.0, isWater,
                isWater and uvU or 0, isWater and uvV or 0, 1)

            if not (isWater or isLava) then
                for oi = 1, 4 do
                    if outCount >= MAX_QUADS then break end
                    local off = neighborOffsets[oi]
                    local nbRow = tileGrid[gridX + off.nx]
                    local nb = nbRow and nbRow[gridZ + off.nz]

                    local needsWall, wallBottom
                    if not nb then
                        needsWall, wallBottom = true, 0
                    elseif nb.isAir and nb.cave then
                        wallBottom = nb.cave.floorHeight
                        needsWall = (topY - wallBottom) >= MIN_WALL_HEIGHT
                    else
                        wallBottom = nb.height or 0
                        needsWall = (topY - wallBottom) >= MIN_WALL_HEIGHT
                    end

                    if needsWall then
                        local cs1, cs2 = tile[off.i1], tile[off.i2]
                        local sx1, sy1, sz1 = cs1[1], cs1[2], cs1[3]
                        local sx2, sy2, sz2 = cs2[1], cs2[2], cs2[3]

                        local bandIdx = 0
                        local yTop1, yTop2 = sy1 - 0.01, sy2 - 0.01
                        while outCount < MAX_QUADS do
                            local avgTop = (yTop1 + yTop2) * 0.5
                            local remaining = avgTop - wallBottom
                            if remaining <= 0.001 then break end

                            bandIdx = bandIdx + 1
                            local bandHeight = min(BAND_HEIGHT, remaining)

                            local yBot1 = yTop1 - bandHeight
                            local yBot2 = yTop2 - bandHeight

                            QUAD[1][1], QUAD[1][2], QUAD[1][3] = sx1, yTop1, sz1
                            QUAD[2][1], QUAD[2][2], QUAD[2][3] = sx2, yTop2, sz2
                            QUAD[3][1], QUAD[3][2], QUAD[3][3] = sx2, yBot2, sz2
                            QUAD[4][1], QUAD[4][2], QUAD[4][3] = sx1, yBot1, sz1
                            local wallCenterX = (sx1 + sx2) * 0.5
                            local wallCenterY = (avgTop + (avgTop - bandHeight)) * 0.5
                            local wallCenterZ = (sz1 + sz2) * 0.5
                            local wdx, wdy, wdz = wallCenterX - camX, wallCenterY - camY, wallCenterZ - camZ
                            local wallDist = wdx * wdx + wdy * wdy + wdz * wdz * 5

                            local bandTex = getBandTexture(tile, bandIdx, materials, tex)

                            pushQuad(camera, QUAD[1], QUAD[2], QUAD[3], QUAD[4],
                                bandTex, "side", wallDist,
                                tr, tg, tb,
                                1.0, false, 0, 0, bandHeight)

                            yTop1, yTop2 = yBot1, yBot2
                        end
                    end
                end
            end
        end
        ::drawCave::
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
local DEPTH_BUCKETS = 128

local activeBatches = {}
local activeBatchCount = 0
local activeBatchEntryPool = {}
local terrainDrawList = {}
local terrainDrawCount = 0
local terrainDrawEntryPool = {}

local function getPooledEntry(pool, i)
    local e = pool[i]
    if not e then
        e = {}
        pool[i] = e
    end
    return e
end

local function buildVertexMap(capacityQuads)
    local map = {}
    for i = 0, capacityQuads - 1 do
        local base, o = i * 4, i * 6
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
        ffi.copy(grown.ptr, batch.ptr, batch.quadCount * 4 * TERRAIN_VERT_SIZE)
        grown.quadCount = batch.quadCount
        Verts.batches[tex][bucket] = grown
        batch = grown
    end

    local idx = batch.quadCount
    local ptr = batch.ptr
    local base = idx * 4
    local v, uv = q.verts, q.uvOffset
    local vr = q.vRepeat or 1
    local br = q.brightness
    local r, g, b, a = br[1], br[2], br[3], q.alpha or 1.0

    local p0 = ptr[base]
    p0.x, p0.y, p0.u, p0.v = v[0], v[1], uv.u, uv.v
    p0.r, p0.g, p0.b, p0.a = r, g, b, a

    local p1 = ptr[base + 1]
    p1.x, p1.y, p1.u, p1.v = v[3], v[4], uv.u + 1, uv.v
    p1.r, p1.g, p1.b, p1.a = r, g, b, a

    local p2 = ptr[base + 2]
    p2.x, p2.y, p2.u, p2.v = v[6], v[7], uv.u + 1, uv.v + vr
    p2.r, p2.g, p2.b, p2.a = r, g, b, a

    local p3 = ptr[base + 3]
    p3.x, p3.y, p3.u, p3.v = v[9], v[10], uv.u, uv.v + vr
    p3.r, p3.g, p3.b, p3.a = r, g, b, a

    batch.quadCount = idx + 1
end

local transparentPool = {}
local transparentCount = 0

local function sortByDistDesc(a, b) return a.dist > b.dist end
local meshDataPool = {}

local function getOrCreateTransparentMesh(i)
    local mesh = Verts.meshPool[i]
    local md = meshDataPool[i]
    if not mesh then
        local data = love.data.newByteData(4 * TERRAIN_VERT_SIZE)
        local ptrOk, ptr = pcall(function() return ffi.cast("TerrainVert*", data:getFFIPointer()) end)
        if not ptrOk then ptr = ffi.cast("TerrainVert*", data:getPointer()) end
        mesh = lg.newMesh(VFORMAT, 4, "fan", "dynamic")
        md = {data = data, ptr = ptr}
        Verts.meshPool[i] = mesh
        meshDataPool[i] = md
    end
    return mesh, md
end

local function prepareTransparent(count, fallback)
    for i = count + 1, #transparentPool do transparentPool[i] = nil end
    table.sort(transparentPool, sortByDistDesc)

    for i = 1, count do
        local q = transparentPool[i]
        local mesh, md = getOrCreateTransparentMesh(i)

        local v, uv, br = q.verts, q.uvOffset, q.brightness
        local vr = q.vRepeat or 1
        local alpha = q.alpha or 0.55
        local r, g, b = br[1], br[2], br[3]
        local ptr = md.ptr

        local p0 = ptr[0]
        p0.x, p0.y, p0.u, p0.v = v[0], v[1], uv.u, uv.v
        p0.r, p0.g, p0.b, p0.a = r, g, b, alpha

        local p1 = ptr[1]
        p1.x, p1.y, p1.u, p1.v = v[3], v[4], uv.u + 1, uv.v
        p1.r, p1.g, p1.b, p1.a = r, g, b, alpha

        local p2 = ptr[2]
        p2.x, p2.y, p2.u, p2.v = v[6], v[7], uv.u + 1, uv.v + vr
        p2.r, p2.g, p2.b, p2.a = r, g, b, alpha

        local p3 = ptr[3]
        p3.x, p3.y, p3.u, p3.v = v[9], v[10], uv.u, uv.v + vr
        p3.r, p3.g, p3.b, p3.a = r, g, b, alpha

        mesh:setVertices(md.data)
        local tex = q.texture or fallback
        ensureWrap(tex)
        if tex then mesh:setTexture(tex) end
        q.mesh = mesh
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
                    local e = getPooledEntry(activeBatchEntryPool, activeBatchCount)
                    e.tex, e.bucket = tex, bucket
                    activeBatches[activeBatchCount] = e
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
        ensureWrap(e.tex)
        batch.mesh:setTexture(e.tex)

        terrainDrawCount = terrainDrawCount + 1
        local de = getPooledEntry(terrainDrawEntryPool, terrainDrawCount)
        de.dist = minD + (e.bucket + 0.5) / bucketScale
        de.mesh = batch.mesh
        terrainDrawList[terrainDrawCount] = de
    end
    for i = terrainDrawCount + 1, #terrainDrawList do terrainDrawList[i] = nil end
    table.sort(terrainDrawList, sortByDistDesc)

    prepareTransparent(transparentCount, fallback)
    return transparentPool, transparentCount, terrainDrawList, terrainDrawCount
end

function Verts.ensureAllMeshes(visibleTiles, fallback)
    return Verts.buildBatches(visibleTiles, fallback)
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

function Verts.setTime(t)
    time = t or 0
    if waterShader then
        pcall(function() waterShader:send("time", time) end)
    end
end

return Verts