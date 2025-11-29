local love = require "love"
local lg = love.graphics
local m = math
local sqrt, sin, cos, pi, max, floor = m.sqrt, m.sin, m.cos, m.pi, m.max, m.floor

local Verts = {}
local time = 0

local waves = {
    {dir={1,0.3}, amplitude=0.12, wavelength=6, speed=1.2, steepness=0.9, uvSpeed=0.08},
    {dir={0.6,0.8}, amplitude=0.08, wavelength=3.5, speed=1.6, steepness=0.6, uvSpeed=0.12},
    {dir={0.2,-1}, amplitude=0.04, wavelength=1.8, speed=2.4, steepness=0.45, uvSpeed=0.18},
}

for _, w in ipairs(waves) do
    local dx, dz = w.dir[1], w.dir[2]
    local len = sqrt(dx*dx + dz*dz)
    if len > 0 then
        w.dir[1], w.dir[2] = dx / len, dz / len
    end
    w.k = 2 * pi / w.wavelength
end

function Verts.setTime(t) time = t or 0 end

local function gerstner(x, z)
    local y, ox, oz = 0, 0, 0
    for _, w in ipairs(waves) do
        local phase = w.k * (w.dir[1]*x + w.dir[2]*z) - w.speed * time
        local s, c = sin(phase), cos(phase)
        local a = w.steepness * w.amplitude
        y  = y + w.amplitude * s
        ox = ox + a * w.dir[1] * c
        oz = oz + a * w.dir[2] * c
    end
    return y, ox, oz
end

local function buildMesh(vertices, uvOffset, vRepeat, texture, fallback)
    local u, v = uvOffset.u or 0, uvOffset.v or 0
    local verts = {
        {vertices[1], vertices[2], 0+u, 0+v},
        {vertices[3], vertices[4], 1+u, 0+v},
        {vertices[5], vertices[6], 1+u, (vRepeat or 1)+v},
        {vertices[7], vertices[8], 0+u, (vRepeat or 1)+v},
    }
    local mesh = lg.newMesh(verts, "fan", "static")
    local tex = texture or fallback
    if tex then
        if tex.setWrap then tex:setWrap("repeat","repeat") end
        mesh:setTexture(tex)
    end
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

function Verts.generate(tiles, camera, renderDistanceSq, tileGrid, materials)
    if not tiles or not camera then return {} end
    camera:updateProjectionConstants()
    local camX, camZ = camera.x, camera.z
    local out, n = {}, 0
    local uvU, uvV = 0, 0
    for _, w in ipairs(waves) do
        uvU = uvU + w.uvSpeed * w.dir[1]
        uvV = uvV + w.uvSpeed * w.dir[2]
    end
    uvU, uvV = (uvU*time)%1, (uvV*time)%1

    local safeVert = function(v, water)
        if water then
            local dy, dx, dz = gerstner(v[1], v[3])
            return v[1]+dx, v[2]+dy, v[3]+dz
        else
            return v[1], v[2], v[3]
        end
    end

    for _, tile in ipairs(tiles) do
        local water = isWater(tile, materials)
        local uvOffset = water and {u=uvU,v=uvV} or {u=0,v=0}
        local topVerts, visible = {}, true
        for j=1,4 do
            local vx, vy, vz = safeVert(tile[j], water)
            local sx, sy = camera:project3D(vx, vy, vz)
            if not sx then visible=false; break end
            topVerts[(j-1)*2+1] = sx
            topVerts[(j-1)*2+2] = sy
        end

        if visible then
            local cx = (tile[1][1]+tile[3][1])*0.5 - camX
            local cz = (tile[1][3]+tile[3][3])*0.5 - camZ
            if (cx*cx + cz*cz) <= renderDistanceSq then
                n=n+1
                out[n]={verts=topVerts, dist=cx*cx+cz*cz, texture=tile.texture, tile=tile, uvOffset=uvOffset, isWater=water, face="top"}
            end
        end

        local tx, tz = floor(tile[1][1]), floor(tile[1][3])
        local topY = tile.height or ((tile[1][2]+tile[2][2]+tile[3][2]+tile[4][2])*0.25)
        for _, off in ipairs(neighborOffsets) do
            local nb = tileGrid[tx+off.nx] and tileGrid[tx+off.nx][tz+off.nz]
            local nbHeight = nb and nb.height or 0
            if not nb or (topY - nbHeight > 1) then
                local v1x,v1y,v1z = safeVert(tile[off.i1], water)
                local v2x,v2y,v2z = safeVert(tile[off.i2], water)
                local h = nbHeight
                local sideVerts3D = {
                    {v1x,v1y,v1z},{v2x,v2y,v2z},{v2x,h,v2z},{v1x,h,v1z}
                }

                local sideVerts2D, sideVisible = {}, true
                for j=1,4 do
                    local sx, sy = camera:project3D(sideVerts3D[j][1], sideVerts3D[j][2], sideVerts3D[j][3])
                    if not sx then sideVisible=false; break end
                    sideVerts2D[(j-1)*2+1] = sx
                    sideVerts2D[(j-1)*2+2] = sy
                end

                if sideVisible then
                    local midx = (v1x+v2x)*0.5 - camX
                    local midz = (v1z+v2z)*0.5 - camZ
                    if (midx*midx + midz*midz) <= renderDistanceSq then
                        n=n+1
                        out[n] = {
                            verts = sideVerts2D,
                            dist = midx*midx+midz*midz,
                            texture = tile.texture,
                            tile = tile,
                            uvOffset = {u=0,v=0},
                            isWater = false,
                            face = "side",
                            vRepeat = max(1, topY-nbHeight)
                        }
                    end
                end
            end
        end
    end

    table.sort(out, function(a,b) return a.dist>b.dist end)
    return out
end

function Verts.ensureAllMeshes(tiles, fallback)
    for _, t in ipairs(tiles or {}) do
        if t and t.verts then
            t.mesh = buildMesh(t.verts, t.uvOffset or {u=0,v=0}, t.vRepeat or 1, t.texture, fallback)
        end
    end
end

return Verts