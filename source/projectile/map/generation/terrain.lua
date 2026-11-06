local ffi = require "ffi"
local love = require "love"
local lg = love.graphics
local min, sin, floor = math.min, math.sin, math.floor

local proj = (...) and (...):match("^(.*%.)[^%.]*$") or "source.projectile.map.generation."
local Verts = require("source.projectile.verts")
local utils = require("source.utils.utils")
local Cave = require(proj .. "cave")
local Underwater = require(proj .. "underwater")

local glOk, glcompat = pcall(require, "source.gl.opengles2")
if not glOk then glcompat = nil end

local Terrain = {}
Terrain.shader = Verts.loadShader("shaders/terrain.glsl")

local pushQuad, isFull = Verts.pushQuad, Verts.isFull
local QUAD = Verts.QUAD
local VFORMAT, VERT_SIZE = Verts.VFORMAT, Verts.VERT_SIZE
local ensureWrap = Verts.ensureWrap

local neighborOffsets = Verts.NEIGHBORS

local BAND_HEIGHT = 1
local MIN_WALL_HEIGHT = 0.7

local function getBandTexture(tile, bandIndex, materials, fallbackTex)
    local sub = tile.subsurface
    local matName = sub and sub[bandIndex]
    if not matName then matName = "stone" end
    return materials[matName] or fallbackTex
end

function Terrain.beginFrame(ctx)
    Verts.sendCameraUniforms(Terrain.shader, ctx.camera)
end

function Terrain.emit(tile, ctx, dx, dy, dz, ty)
    local camera = ctx.camera
    local camX, camY, camZ = ctx.camX, ctx.camY, ctx.camZ
    local tr, tg, tb = ctx.tr, ctx.tg, ctx.tb
    local tileGrid, materials = ctx.tileGrid, ctx.materials

    local c1, c2, c3, c4 = tile[1], tile[2], tile[3], tile[4]

    local tex = tile.texture
    local isLava = tile.isLava or false
    local dist = dx * dx + dy * dy + dz * dz
    local gridX, gridZ = floor(c1[1]), floor(c1[3])
    local topY = tile.height or ty

    local topR, topG, topB
    if isLava then
        local lavaGlow = 0.8 + 0.2 * sin(ctx.time * 2.2 + (tile.x + tile.z) * 0.6)
        topR, topG, topB = lavaGlow, lavaGlow * 0.45, lavaGlow * 0.15
    else
        topR, topG, topB = tr, tg, tb
    end

    utils.setQuadVerts(QUAD, c1, c2, c3, c4)

    pushQuad(camera, QUAD[1], QUAD[2], QUAD[3], QUAD[4],
        tex, "top", dist,
        topR, topG, topB,
        1.0, false, 0, 0, 1)

    if isLava then return end

    for oi = 1, 4 do
        if isFull() then break end
        local off = neighborOffsets[oi]
        local nbRow = tileGrid[gridX + off.nx]
        local nb = nbRow and nbRow[gridZ + off.nz]

        local needsWall, wallBottom, waterSurfaceY
        if not nb then
            needsWall, wallBottom = true, 0
        elseif Cave.isCaveTile(nb) then
            wallBottom = Cave.getFloorHeight(nb)
            needsWall = (topY - wallBottom) >= MIN_WALL_HEIGHT
        elseif Underwater.enabled and Underwater.isWaterTile(nb) then
            wallBottom = Underwater.getBedHeight(nb)
            waterSurfaceY = Underwater.getSurfaceHeight(nb)
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
            while not isFull() do
                local avgTop = (yTop1 + yTop2) * 0.5
                local remaining = avgTop - wallBottom
                if remaining <= 0.001 then break end

                bandIdx = bandIdx + 1
                local bandHeight = min(BAND_HEIGHT, remaining)

                local yBot1 = yTop1 - bandHeight
                local yBot2 = yTop2 - bandHeight

                utils.setQuadVerts(QUAD, 
                    {sx1, yTop1, sz1}, 
                    {sx2, yTop2, sz2}, 
                    {sx2, yBot2, sz2}, 
                    {sx1, yBot1, sz1}
                )

                local wallCenterX = (sx1 + sx2) * 0.5
                local wallCenterY = (avgTop + (avgTop - bandHeight)) * 0.5
                local wallCenterZ = (sz1 + sz2) * 0.5
                local wdx, wdy, wdz = wallCenterX - camX, wallCenterY - camY, wallCenterZ - camZ
                local wallDist = wdx * wdx + wdy * wdy + wdz * wdz * 5

                local bandTex = getBandTexture(tile, bandIdx, materials, tex)

                local br, bg, bb = tr, tg, tb
                if waterSurfaceY and wallCenterY < waterSurfaceY then
                    br, bg, bb = Underwater.tint(waterSurfaceY - wallCenterY, tr, tg, tb)
                end

                pushQuad(camera, QUAD[1], QUAD[2], QUAD[3], QUAD[4],
                    bandTex, "side", wallDist,
                    br, bg, bb,
                    1.0, false, 0, 0, bandHeight)

                yTop1, yTop2 = yBot1, yBot2
            end
        end
    end
end

local INITIAL_BATCH_QUADS = 32
local DEPTH_BUCKETS = 1

local activeBatches = {}
local activeBatchCount = 0
local activeBatchEntryPool = {}
local terrainDrawList = {}
local terrainDrawCount = 0
local terrainDrawEntryPool = {}

local bucketSlots = {}
local bucketSlotCounts = {}
for b = 1, DEPTH_BUCKETS do
    bucketSlots[b] = {}
    bucketSlotCounts[b] = 0
end
local usedBuckets = {}
local usedBucketCount = 0

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
    local data, ptr = Verts.newVertexData(vcount)
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
        ffi.copy(grown.ptr, batch.ptr, batch.quadCount * 4 * VERT_SIZE)
        grown.quadCount = batch.quadCount
        Verts.batches[tex][bucket] = grown
        batch = grown
    end

    local idx = batch.quadCount
    Verts.writeQuadVerts(batch.ptr, idx * 4, q, 1.0)
    batch.quadCount = idx + 1
    return batch
end

function Terrain.buildBatches(visibleQuads, fallback)
    for i = 1, activeBatchCount do
        local e = activeBatches[i]
        local perTex = Verts.batches[e.tex]
        local batch = perTex and perTex[e.bucket]
        if batch then batch.quadCount = 0 end
        activeBatches[i] = nil
    end
    activeBatchCount = 0
    terrainDrawCount = 0

    for i = 1, usedBucketCount do
        bucketSlotCounts[usedBuckets[i]] = 0
    end
    usedBucketCount = 0

    local n = #visibleQuads
    local minD, maxD = math.huge, -math.huge
    for i = 1, n do
        local q = visibleQuads[i]
        if not Verts.isTransparent(q) then
            local d = q.dist
            if d < minD then minD = d end
            if d > maxD then maxD = d end
        end
    end
    local range = maxD - minD
    if range <= 0 or range ~= range then range = 1 end
    local bucketScale = DEPTH_BUCKETS / range

    for i = 1, n do
        local q = visibleQuads[i]
        if not Verts.isTransparent(q) then
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

                    local slotIdx = bucket + 1
                    local slotCount = bucketSlotCounts[slotIdx]
                    if slotCount == 0 then
                        usedBucketCount = usedBucketCount + 1
                        usedBuckets[usedBucketCount] = slotIdx
                    end
                    slotCount = slotCount + 1
                    bucketSlotCounts[slotIdx] = slotCount
                    bucketSlots[slotIdx][slotCount] = e
                end
                batch = writeQuad(tex, bucket, batch, q)
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
    end
    for bi = DEPTH_BUCKETS, 1, -1 do
        local count = bucketSlotCounts[bi]
        if count > 0 then
            local slot = bucketSlots[bi]
            local bucketDist = minD + ((bi - 1) + 0.5) / bucketScale
            for k = 1, count do
                local e = slot[k]
                local batch = Verts.batches[e.tex][e.bucket]
                terrainDrawCount = terrainDrawCount + 1
                local de = getPooledEntry(terrainDrawEntryPool, terrainDrawCount)
                de.dist = bucketDist
                de.mesh = batch.mesh
                terrainDrawList[terrainDrawCount] = de
            end
        end
    end
    for i = terrainDrawCount + 1, #terrainDrawList do terrainDrawList[i] = nil end

    return terrainDrawList, terrainDrawCount
end

function Terrain.draw(mesh, shaderOverride, camera)
    if glcompat then
        glcompat.enable(glcompat.GL_CULL_FACE)
        glcompat.cullFace(glcompat.GL_BACK)
    end
    lg.setColor(1, 1, 1, 1)
    local previousShader = lg.getShader()
    local shader = shaderOverride or Terrain.shader
    if shader then
        if shaderOverride then
            Verts.sendCameraUniforms(shaderOverride, camera)
            shaderOverride:send("useTerrainProjection", true)
        end
        lg.setShader(shader)
    end
    lg.draw(mesh)
    if shaderOverride then shaderOverride:send("useTerrainProjection", false) end
    if previousShader then lg.setShader(previousShader) else lg.setShader() end
    if glcompat then
        glcompat.disable(glcompat.GL_CULL_FACE)
    end
end

return Terrain