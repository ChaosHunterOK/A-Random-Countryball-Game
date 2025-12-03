local ffi = require "ffi"
local love = require "love"
local gl = require "source.gl.opengl"
local lg = love.graphics
local m = math
local sqrt, sin, cos, pi, max, floor = m.sqrt, m.sin, m.cos, m.pi, m.max, m.floor

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

ffi.cdef[[
typedef struct { double dirx, dirz, amplitude, k, speed, steepness, uvSpeed; } Wave;
]]
local waves_ffi = ffi.new("Wave[?]", WN)
for i = 0, WN-1 do
    local w = waveDefs[i+1]
    waves_ffi[i].dirx = w.dir[1]
    waves_ffi[i].dirz = w.dir[2]
    waves_ffi[i].amplitude = w.amplitude
    waves_ffi[i].k = w.k
    waves_ffi[i].speed = w.speed
    waves_ffi[i].steepness = w.steepness
    waves_ffi[i].uvSpeed = w.uvSpeed
end

local projBuf = ffi.new("double[8]")
local tmpVerts = ffi.new("double[12]")

function Verts.setTime(t) time = t or 0 end

local function gerstner_f(x, z)
    local y, ox, oz = 0.0, 0.0, 0.0
    for i = 0, WN-1 do
        local w = waves_ffi[i]
        local phase = w.k * (w.dirx * x + w.dirz * z) - w.speed * time
        local s, c = sin(phase), cos(phase)
        local a = w.steepness * w.amplitude
        y = y + w.amplitude * s
        ox = ox + a * w.dirx * c
        oz = oz + a * w.dirz * c
    end
    return y, ox, oz
end

local function buildMesh(vertices, uvOffset, vRepeat, texture, fallback)
    uvOffset = uvOffset or {u=0,v=0}
    vRepeat = vRepeat or 1
    local verts = {
        {vertices[1], vertices[2], 0+uvOffset.u, 0+uvOffset.v},
        {vertices[3], vertices[4], 1+uvOffset.u, 0+uvOffset.v},
        {vertices[5], vertices[6], 1+uvOffset.u, vRepeat+uvOffset.v},
        {vertices[7], vertices[8], 0+uvOffset.u, vRepeat+uvOffset.v},
    }
    local mesh = lg.newMesh(verts, "fan", "static")
    local tex = texture or fallback
    if tex and tex.setWrap then tex:setWrap("repeat","repeat") end
    if tex then mesh:setTexture(tex) end
    return mesh
end

local function isWater(tile, mats)
    if not tile or not tile.texture then return false end
    local t = tile.texture
    return t == mats.waterSmall or t == mats.waterMedium or t == mats.waterDeep
end

local neighborOffsets = {
    {nx=0,nz=-1,i1=1,i2=2},
    {nx=1,nz=0,i1=2,i2=3},
    {nx=0,nz=1,i1=4,i2=3},
    {nx=-1,nz=0,i1=1,i2=4},
}

local function projectQuadToBuf(camera, v1, v2, v3, v4, buf)
    local sx, sy = camera:project3D(v1[1], v1[2], v1[3])
    if not sx then return false end; buf[0], buf[1] = sx, sy
    sx, sy = camera:project3D(v2[1], v2[2], v2[3])
    if not sx then return false end; buf[2], buf[3] = sx, sy
    sx, sy = camera:project3D(v3[1], v3[2], v3[3])
    if not sx then return false end; buf[4], buf[5] = sx, sy
    sx, sy = camera:project3D(v4[1], v4[2], v4[3])
    if not sx then return false end; buf[6], buf[7] = sx, sy
    return true
end

local function projBufToLuaArray(buf)
    return {buf[0],buf[1],buf[2],buf[3],buf[4],buf[5],buf[6],buf[7]}
end

local outBuf = {}

Verts.vbo = ffi.new("GLuint[1]")
Verts.ebo = ffi.new("GLuint[1]")
Verts.vao = ffi.new("GLuint[1]")

function Verts.generate(tiles, camera, renderDistanceSq, tileGrid, materials)
    if not tiles or not camera then return {} end
    camera:updateProjectionConstants()
    local camX, camZ = camera.x, camera.z
    local uvU, uvV = 0.0, 0.0
    for i = 0, WN-1 do
        local w = waves_ffi[i]
        uvU = uvU + w.uvSpeed * w.dirx
        uvV = uvV + w.uvSpeed * w.dirz
    end
    uvU, uvV = (uvU * time) % 1.0, (uvV * time) % 1.0

    outBuf = {}

    for t = 1, #tiles do
        local tile = tiles[t]
        if not tile or not tile[1] then goto continue end

        local water = isWater(tile, materials)
        local uvOffset = water and {u=uvU, v=uvV} or {u=0, v=0}

        local v1x,v1y,v1z = tile[1][1], tile[1][2], tile[1][3]
        local v2x,v2y,v2z = tile[2][1], tile[2][2], tile[2][3]
        local v3x,v3y,v3z = tile[3][1], tile[3][2], tile[3][3]
        local v4x,v4y,v4z = tile[4][1], tile[4][2], tile[4][3]

        if water then
            local dy, dx, dz
            dy, dx, dz = gerstner_f(v1x, v1z); v1y=v1y+dy; v1x=v1x+dx; v1z=v1z+dz
            dy, dx, dz = gerstner_f(v2x, v2z); v2y=v2y+dy; v2x=v2x+dx; v2z=v2z+dz
            dy, dx, dz = gerstner_f(v3x, v3z); v3y=v3y+dy; v3x=v3x+dx; v3z=v3z+dz
            dy, dx, dz = gerstner_f(v4x, v4z); v4y=v4y+dy; v4x=v4x+dx; v4z=v4z+dz
        end

        local v1t,v2t,v3t,v4t = {v1x,v1y,v1z},{v2x,v2y,v2z},{v3x,v3y,v3z},{v4x,v4y,v4z}

        local visible = projectQuadToBuf(camera, v1t,v2t,v3t,v4t,projBuf)
        if visible then
            local cx, cz = (tile[1][1]+tile[3][1])*0.5-camX, (tile[1][3]+tile[3][3])*0.5-camZ
            if (cx*cx+cz*cz) <= renderDistanceSq then
                outBuf[#outBuf+1] = {
                    verts = projBufToLuaArray(projBuf),
                    dist = cx*cx+cz*cz,
                    texture = tile.texture,
                    tile = tile,
                    uvOffset = uvOffset,
                    isWater = water,
                    face = "top"
                }
            end
        end

        local tx, tz = floor(tile[1][1]), floor(tile[1][3])
        local topY = tile.height or ((tile[1][2]+tile[2][2]+tile[3][2]+tile[4][2])*0.25)

        for oi=1,4 do
            local off = neighborOffsets[oi]
            local nbRow = tileGrid[tx + off.nx]
            local nb = nbRow and nbRow[tz + off.nz]
            local nbHeight = nb and nb.height or 0
            if not nb or (topY - nbHeight > 1) then
                local v1s,v2s = tile[off.i1], tile[off.i2]
                local v1x_s,v1y_s,v1z_s = v1s[1],v1s[2],v1s[3]
                local v2x_s,v2y_s,v2z_s = v2s[1],v2s[2],v2s[3]
                if water then
                    local dy, dx, dz
                    dy, dx, dz = gerstner_f(v1x_s,v1z_s); v1y_s=v1y_s+dy; v1x_s=v1x_s+dx; v1z_s=v1z_s+dz
                    dy, dx, dz = gerstner_f(v2x_s,v2z_s); v2y_s=v2y_s+dy; v2x_s=v2x_s+dx; v2z_s=v2z_s+dz
                end
                local s1,s2,s3,s4 = {v1x_s,v1y_s,v1z_s},{v2x_s,v2y_s,v2z_s},{v2x_s,nbHeight,v2z_s},{v1x_s,nbHeight,v1z_s}
                local sideVisible = projectQuadToBuf(camera,s1,s2,s3,s4,projBuf)
                if sideVisible then
                    local midx, midz = (v1x_s+v2x_s)*0.5-camX, (v1z_s+v2z_s)*0.5-camZ
                    if (midx*midx+midz*midz) <= renderDistanceSq then
                        outBuf[#outBuf+1] = {
                            verts = projBufToLuaArray(projBuf),
                            dist = midx*midx+midz*midz,
                            texture = tile.texture,
                            tile = tile,
                            uvOffset = {u=0,v=0},
                            isWater = false,
                            face = "side",
                            vRepeat = floor(max(1,topY-nbHeight))
                        }
                    end
                end
            end
        end

        ::continue::
    end

    table.sort(outBuf, function(a,b) return a.dist>b.dist end)
    return outBuf
end

function Verts.ensureAllMeshes(tiles, fallback)
    for i=1,#tiles do
        local t = tiles[i]
        if t and t.verts then
            local tex = t.texture or nil
            t.mesh = buildMesh(t.verts, t.uvOffset or {u=0,v=0}, t.vRepeat or 1, tex, fallback)
        end
    end
end

return Verts