local ffi = require "ffi"
local love = require "love"
local night = require "source.projectile.night_cycle"
local utils = require "source.utils.utils"
local lg = love.graphics
local floor = math.floor

local MODNAME = ...
local proj = "source.projectile.map.generation." or (MODNAME and MODNAME:match("^(.*%.)[^%.]*$"))

ffi.cdef[[
    typedef struct {float x, y, z, u, v; uint8_t r, g, b, a;} TerrainVert;
]]

local Verts = {}
Verts.meshPool = {}
Verts.batches = {}
if MODNAME then package.loaded[MODNAME] = Verts end

local Terrain, Water, Cave, Underwater

local time = 0

Verts.VFORMAT = {
    {"VertexPosition", "float", 3},
    {"VertexTexCoord", "float", 2},
    {"VertexColor", "byte", 4},
}
Verts.VERT_SIZE = ffi.sizeof("TerrainVert")

local toByte = utils.toByte

local wrappedTextures = {}
function Verts.ensureWrap(tex)
    if tex and not wrappedTextures[tex] then
        tex:setWrap("repeat", "repeat")
        wrappedTextures[tex] = true
    end
end

function Verts.loadShader(path)
    if not love.filesystem.getInfo(path) then return nil end
    local ok, code = pcall(function() return love.filesystem.read(path) end)
    if not (ok and code) then return nil end
    local shader
    pcall(function() shader = lg.newShader(code) end)
    return shader
end

function Verts.sendCameraUniforms(shader, camera)
    if not shader then return end
    pcall(function()
        shader:send("cameraPosition", {camera.x, camera.y, camera.z})
        shader:send("cameraRotation", {camera._cosYaw, camera._sinYaw, camera._cosPitch, camera._sinPitch})
        shader:send("cameraProjection", {camera._fx, camera._fy})
    end)
end

function Verts.newVertexData(vertexCount)
    local data = love.data.newByteData(vertexCount * Verts.VERT_SIZE)
    local ptrOk, ptr = pcall(function() return ffi.cast("TerrainVert*", data:getFFIPointer()) end)
    if not ptrOk then
        ptr = ffi.cast("TerrainVert*", data:getPointer())
    end
    return data, ptr
end

function Verts.writeQuadVerts(ptr, base, q, defaultAlpha)
    local v, uv = q.verts, q.uvOffset
    local vr = q.vRepeat or 1
    local br = q.brightness
    local r, g, b, a = toByte(br[1]), toByte(br[2]), toByte(br[3]), toByte(q.alpha or defaultAlpha)

    local p0 = ptr[base]
    p0.x, p0.y, p0.z, p0.u, p0.v = v[0], v[1], v[2], uv.u, uv.v
    p0.r, p0.g, p0.b, p0.a = r, g, b, a

    local p1 = ptr[base + 1]
    p1.x, p1.y, p1.z, p1.u, p1.v = v[3], v[4], v[5], uv.u + 1, uv.v
    p1.r, p1.g, p1.b, p1.a = r, g, b, a

    local p2 = ptr[base + 2]
    p2.x, p2.y, p2.z, p2.u, p2.v = v[6], v[7], v[8], uv.u + 1, uv.v + vr
    p2.r, p2.g, p2.b, p2.a = r, g, b, a

    local p3 = ptr[base + 3]
    p3.x, p3.y, p3.z, p3.u, p3.v = v[9], v[10], v[11], uv.u, uv.v + vr
    p3.r, p3.g, p3.b, p3.a = r, g, b, a
end

local MAX_QUADS = 4000
local outPool = {}
local result_table = {}
local outCount = 0

local function newOutputEntry()
    return {
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

local projBuf = ffi.new("double[12]")
Verts.QUAD = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}, {0, 0, 0}}
Verts.NEIGHBORS = {
    {nx=0, nz=-1, i1=1, i2=2},
    {nx=1, nz=0, i1=2, i2=3},
    {nx=0, nz=1, i1=3, i2=4},
    {nx=-1,nz=0, i1=4, i2=1},
}

local function projectQuadToBuf(camera, v1, v2, v3, v4, buf)
    local camX, camY, camZ = camera.x, camera.y, camera.z
    local cy, sy = camera._cosYaw, camera._sinYaw
    local cp, sp = camera._cosPitch, camera._sinPitch
    local f, aspect = camera._f, camera.aspect
    local hw, hh = camera.hw, camera.hh

    local dx, dy, dz = v1[1] - camX, v1[2] - camY, v1[3] - camZ
    local x1 = dx * cy - dz * sy
    local z1 = dx * sy + dz * cy
    local y1 = dy * cp - z1 * sp
    local z2 = dy * sp + z1 * cp
    if z2 <= 0.001 then return false end
    local inv = f / z2
    local sx1, sy1, sz1 = (x1 * inv / aspect) * hw + hw, (-y1 * inv) * hh + hh, z2

    dx, dy, dz = v2[1] - camX, v2[2] - camY, v2[3] - camZ
    x1 = dx * cy - dz * sy
    z1 = dx * sy + dz * cy
    y1 = dy * cp - z1 * sp
    z2 = dy * sp + z1 * cp
    if z2 <= 0.001 then return false end
    inv = f / z2
    local sx2, sy2, sz2 = (x1 * inv / aspect) * hw + hw, (-y1 * inv) * hh + hh, z2

    dx, dy, dz = v3[1] - camX, v3[2] - camY, v3[3] - camZ
    x1 = dx * cy - dz * sy
    z1 = dx * sy + dz * cy
    y1 = dy * cp - z1 * sp
    z2 = dy * sp + z1 * cp
    if z2 <= 0.001 then return false end
    inv = f / z2
    local sx3, sy3, sz3 = (x1 * inv / aspect) * hw + hw, (-y1 * inv) * hh + hh, z2

    dx, dy, dz = v4[1] - camX, v4[2] - camY, v4[3] - camZ
    x1 = dx * cy - dz * sy
    z1 = dx * sy + dz * cy
    y1 = dy * cp - z1 * sp
    z2 = dy * sp + z1 * cp
    if z2 <= 0.001 then return false end
    inv = f / z2
    local sx4, sy4, sz4 = (x1 * inv / aspect) * hw + hw, (-y1 * inv) * hh + hh, z2

    local screenW, screenH = hw * 2, hh * 2
    if (sx1 < 0 and sx2 < 0 and sx3 < 0 and sx4 < 0) or
       (sx1 > screenW and sx2 > screenW and sx3 > screenW and sx4 > screenW) or
       (sy1 < 0 and sy2 < 0 and sy3 < 0 and sy4 < 0) or
       (sy1 > screenH and sy2 > screenH and sy3 > screenH and sy4 > screenH) then
        return false
    end

    buf[0], buf[1], buf[2] = v1[1], v1[2], v1[3]
    buf[3], buf[4], buf[5] = v2[1], v2[2], v2[3]
    buf[6], buf[7], buf[8] = v3[1], v3[2], v3[3]
    buf[9], buf[10], buf[11] = v4[1], v4[2], v4[3]
    return true
end

function Verts.isFull()
    return outCount >= MAX_QUADS
end

function Verts.pushQuad(camera, v1, v2, v3, v4, texture, face, dist, brR, brG, brB, alpha, isWater, uvU, uvV, vRepeat)
    if outCount >= MAX_QUADS then return false end
    if not projectQuadToBuf(camera, v1, v2, v3, v4, projBuf) then return false end

    outCount = outCount + 1
    local entry = outPool[outCount]
    if not entry then
        entry = newOutputEntry()
        outPool[outCount] = entry
    end
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

function Verts.isTransparent(q)
    return q.isWater and q.face == "top"
end

local TILE_RADIUS = 1.5
local frame = {}

function Verts.generate(tiles, camera, renderDistanceSq, tileGrid, materials)
    if not tiles or not camera then return {} end
    camera:updateProjectionConstants()

    local texMul = night.getTextureMultiplier() or {1, 1, 1}
    local camX, camY, camZ = camera.x, camera.y, camera.z

    frame.camera = camera
    frame.camX, frame.camY, frame.camZ = camX, camY, camZ
    frame.time = time
    frame.tr, frame.tg, frame.tb = texMul[1], texMul[2], texMul[3]
    frame.tileGrid = tileGrid
    frame.materials = materials
    frame.renderDistanceSq = renderDistanceSq

    Terrain.beginFrame(frame)
    Water.beginFrame(frame)
    Cave.beginFrame(frame)

    outCount = 0
    local tileCount = #tiles
    local maxDistSq = renderDistanceSq + TILE_RADIUS * TILE_RADIUS

    for t = 1, tileCount do
        if outCount >= MAX_QUADS then break end

        local tile = tiles[t]
        if tile then
            if tile.isAir or not tile.texture then
                Cave.emit(tile, frame)
            else
                local tx, ty, tz = utils.getTileCenter(tile)
                local dx, dy, dz = tx - camX, ty - camY, tz - camZ

                if (dx * dx + dz * dz) <= maxDistSq
                   and camera:isInViewFrustum(tx, tz, TILE_RADIUS) then
                    if Water.isWaterTexture(tile.texture) then
                        Water.emit(tile, frame, dx, dy, dz)
                        if Underwater.enabled then
                            Underwater.emit(tile, frame, dx, dy, dz)
                        end
                    else
                        Terrain.emit(tile, frame, dx, dy, dz, ty)
                    end
                end
            end
        end
    end

    for i = 1, outCount do result_table[i] = outPool[i] end
    for i = outCount + 1, #result_table do result_table[i] = nil end
    return result_table
end

function Verts.buildBatches(visibleQuads, fallback)
    local drawList, drawCount = Terrain.buildBatches(visibleQuads, fallback)
    local transparent, transparentCount = Water.buildTransparent(visibleQuads, fallback)
    return transparent, transparentCount, drawList, drawCount
end

function Verts.ensureAllMeshes(visibleTiles, fallback)
    return Verts.buildBatches(visibleTiles, fallback)
end

function Verts.drawTerrainMesh(mesh, shaderOverride, camera)
    return Terrain.draw(mesh, shaderOverride, camera)
end

function Verts.drawWaterMesh(mesh, uvU, uvV, shaderOverride, camera)
    return Water.draw(mesh, uvU, uvV, shaderOverride, camera)
end

function Verts.setTime(t)
    time = t or 0
    Water.setTime(time)
end

Terrain = require(proj .. "terrain")
Water = require(proj .. "water")
Cave = require(proj .. "cave")
Underwater = require(proj .. "underwater")

Verts.terrain, Verts.water, Verts.cave, Verts.underwater = Terrain, Water, Cave, Underwater
Verts.terrainShader = Terrain.shader
Verts.waterShader = Water.shader

return Verts