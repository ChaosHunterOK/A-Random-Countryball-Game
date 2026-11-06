local love = require "love"
local lg = love.graphics
local sqrt, pi = math.sqrt, math.pi
local utils = require("source.utils.utils")

local proj = (...) and (...):match("^(.*%.)[^%.]*$") or "source.projectile.map.generation."
local Verts = require("source.projectile.verts")

local Water = {}
Water.shader = Verts.loadShader("shaders/water.glsl")

local pushQuad = Verts.pushQuad
local QUAD = Verts.QUAD
local VFORMAT = Verts.VFORMAT
local ensureWrap = Verts.ensureWrap

local WATER_ALPHA = 0.55

local waveDefs = {
    {dir={1,0.3}, amplitude=0.12, wavelength=6, speed=1.2, steepness=0.9, uvSpeed=0.08},
    {dir={0.6,0.8}, amplitude=0.08, wavelength=3.5, speed=1.6, steepness=0.6, uvSpeed=0.12},
    {dir={0.2,-1}, amplitude=0.04, wavelength=1.8, speed=2.4, steepness=0.45, uvSpeed=0.18},
}

local WN = #waveDefs
local waveDirX, waveDirZ, waveAmp, waveSteepAmp = {}, {}, {}, {}
local waveSpeed, waveUvSpeed = {}, {}
local timeK = {}

for i = 1, WN do
    local w = waveDefs[i]
    local dx, dz = w.dir[1], w.dir[2]
    local len = sqrt(dx*dx + dz*dz)
    local k = 2 * pi / w.wavelength
    waveDirX[i] = (dx / len) * k
    waveDirZ[i] = (dz / len) * k
    waveAmp[i] = w.amplitude
    waveSteepAmp[i] = (w.steepness * w.amplitude) / k
    waveSpeed[i] = w.speed
    waveUvSpeed[i] = w.uvSpeed
    timeK[i] = 0
end

local waveDirSend, wavePhaseSend = {}, {}
for i = 1, WN do
    waveDirSend[i] = {waveDirX[i], waveDirZ[i]}
end

local function doSendWaveUniforms(shader)
    shader:send("waveDir", unpack(waveDirSend))
    shader:send("waveAmp", unpack(waveAmp))
    shader:send("waveSteepAmp", unpack(waveSteepAmp))
    shader:send("wavePhase", unpack(wavePhaseSend))
end

local function sendWaveUniforms(shader)
    if not shader then return end
    for i = 1, WN do wavePhaseSend[i] = timeK[i] end
    pcall(doSendWaveUniforms, shader)
end

local waterSmall, waterMed, waterDeep
local scrollU, scrollV = 0, 0

function Water.beginFrame(ctx)
    local materials = ctx.materials
    waterSmall, waterMed, waterDeep = materials.waterSmall, materials.waterMedium, materials.waterDeep

    Verts.sendCameraUniforms(Water.shader, ctx.camera)

    local timeVal = ctx.time
    local u, v = 0, 0
    for i = 1, WN do
        timeK[i] = waveSpeed[i] * timeVal
        u = u + (waveUvSpeed[i] * waveDirX[i])
        v = v + (waveUvSpeed[i] * waveDirZ[i])
    end
    scrollU, scrollV = (u * timeVal) % 1, (v * timeVal) % 1
    sendWaveUniforms(Water.shader)
end

function Water.isWaterTexture(tex)
    return tex == waterSmall or tex == waterMed or tex == waterDeep
end

function Water.getKind(tex)
    if tex == nil then return nil end
    if tex == waterSmall then return "small" end
    if tex == waterMed then return "medium" end
    if tex == waterDeep then return "deep" end
    return nil
end

function Water.emit(tile, ctx, dx, dy, dz)
    local c1, c2, c3, c4 = tile[1], tile[2], tile[3], tile[4]
    local dist = dx * dx + dy * dy + dz * dz - 0.01

    utils.setQuadVerts(QUAD, c1, c2, c3, c4)

    pushQuad(ctx.camera, QUAD[1], QUAD[2], QUAD[3], QUAD[4],
        tile.texture, "top", dist,
        ctx.tr, ctx.tg, ctx.tb,
        WATER_ALPHA, true, scrollU, scrollV, 1)
end

local transparentPool = {}
local meshDataPool = {}

local function sortByDistDesc(a, b) return a.dist > b.dist end

local function getOrCreateTransparentMesh(i)
    local mesh = Verts.meshPool[i]
    local md = meshDataPool[i]
    if not mesh then
        local data, ptr = Verts.newVertexData(4)
        mesh = lg.newMesh(VFORMAT, 4, "fan", "dynamic")
        md = {data = data, ptr = ptr}
        Verts.meshPool[i] = mesh
        meshDataPool[i] = md
    end
    return mesh, md
end

function Water.buildTransparent(visibleQuads, fallback)
    local count = 0
    for i = 1, #visibleQuads do
        local q = visibleQuads[i]
        if Verts.isTransparent(q) then
            count = count + 1
            transparentPool[count] = q
        end
    end

    for i = count + 1, #transparentPool do transparentPool[i] = nil end
    table.sort(transparentPool, sortByDistDesc)

    for i = 1, count do
        local q = transparentPool[i]
        local mesh, md = getOrCreateTransparentMesh(i)

        Verts.writeQuadVerts(md.ptr, 0, q, WATER_ALPHA)
        mesh:setVertices(md.data)
        local tex = q.texture or fallback
        ensureWrap(tex)
        if tex then mesh:setTexture(tex) end
        q.mesh = mesh
    end

    return transparentPool, count
end

function Water.draw(mesh, uvU, uvV, shaderOverride, camera)
    lg.setColor(1, 1, 1, 1)
    local previousShader = lg.getShader()
    local shader = shaderOverride or Water.shader
    if shaderOverride then
        Verts.sendCameraUniforms(shaderOverride, camera)
        shaderOverride:send("useTerrainProjection", true)
    elseif Water.shader then
        Water.shader:send("uvOffset", {uvU or 0, uvV or 0})
    end
    if shader then lg.setShader(shader) end
    lg.draw(mesh)
    if shaderOverride then shaderOverride:send("useTerrainProjection", false) end
    if previousShader then lg.setShader(previousShader) else lg.setShader() end
end

function Water.setTime(t)
    if Water.shader then
        pcall(Water.shader.send, Water.shader, "time", t)
    end
end

return Water