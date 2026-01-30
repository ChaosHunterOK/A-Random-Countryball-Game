local love = require "love"
local utils = require("source.utils")
local lib3d = require "source.projectile.lib3d"
local night = require "source.projectile.night_cycle"

local lg = love.graphics
local cos, sin, floor, abs, max = math.cos, math.sin, math.floor, math.abs, math.max
local vec3Cross, vec3Normalize, vec3Dot = lib3d.vec3Cross, lib3d.vec3Normalize, lib3d.vec3Dot

local Blocks = {
    placed = {},
    materials = {},
    baseTiles = nil,
    currentBreaking = { tile = nil, progress = 0, max = 1 }
}

local MAX_QUADS = 12000
local meshFormat = {
    {"VertexPosition", "float", 2},
    {"VertexTexCoord", "float", 2},
    {"VertexColor", "byte", 4}
}

local v_cache = { {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0}, {0,0,0} }

Blocks.durabilities = {
    dirt = 2, sandNormal = 2, sandGarnet = 3, sandOlivine = 3,
    stone = 5, granite = 6, gabbro = 7, basalt = 8,
    rhyolite = 5, pumice = 4, oak = 2, lava = 9999
}

Blocks.bestTools = {
    dirt = "shovel", sandNormal = "shovel", sandGarnet = "shovel",
    sandOlivine = "shovel", stone = "pickaxe", granite = "pickaxe",
    gabbro = "pickaxe", basalt = "pickaxe", rhyolite = "pickaxe",
    pumice = "pickaxe", oak = "axe"
}

local function sampleTileHeightAt(tile, x, z)
    if not tile then return nil end
    local fx, fz = x - floor(x), z - floor(z)
    return tile[1][2] * (1-fx) * (1-fz) +
           tile[2][2] * fx * (1-fz) +
           tile[3][2] * fx * fz +
           tile[4][2] * (1-fx) * fz
end

local function getUnderlyingTile(x, z, baseTiles)
    if not baseTiles then return nil end
    for i = 1, #baseTiles do
        local tile = baseTiles[i]
        local v1, v3 = tile[1], tile[3]
        if x >= v1[1] and x <= v3[1] and z >= v1[3] and z <= v3[3] then
            return tile
        end
    end
    return nil
end

function Blocks.generate(camera, renderDistanceSq)
    camera:updateProjectionConstants()
    if #Blocks.placed > 0 then lib3d.setSpatialHash(Blocks.placed, 1) end
    
    local camX, camZ = camera.x, camera.z
    local entries, count = {}, 0
    local sunAngle = (night.time / night.dayLength) * (math.pi * 2)
    local snX, snY, snZ = vec3Normalize(cos(sunAngle), sin(sunAngle) * 0.65 + 0.35, sin(sunAngle + 0.7))
    local texMul = night.getTextureMultiplier() or {1, 1, 1}
    local ambient = 0.05 + (night.getLight and night.getLight()^2 or 1.0)

    for bi = 1, #Blocks.placed do
        local b = Blocks.placed[bi]
        local distSq = (b.x - camX)^2 + (b.z - camZ)^2
        if distSq <= renderDistanceSq then
            local tile = getUnderlyingTile(b.x, b.z, Blocks.baseTiles)
            local h00 = sampleTileHeightAt(tile, b.x - 0.5, b.z - 0.5) or b.y
            local h10 = sampleTileHeightAt(tile, b.x + 0.5, b.z - 0.5) or b.y
            local h11 = sampleTileHeightAt(tile, b.x + 0.5, b.z + 0.5) or b.y
            local h01 = sampleTileHeightAt(tile, b.x - 0.5, b.z + 0.5) or b.y
            local vs = {
                {b.x-0.5, h00, b.z-0.5}, {b.x+0.5, h10, b.z-0.5}, {b.x+0.5, h11, b.z+0.5}, {b.x-0.5, h01, b.z+0.5},
                {b.x-0.5, h00+1, b.z-0.5}, {b.x+0.5, h10+1, b.z-0.5}, {b.x+0.5, h11+1, b.z+0.5}, {b.x-0.5, h01+1, b.z+0.5}
            }

            local faces = {
                {vs[1], vs[2], vs[6], vs[5]}, {vs[3], vs[4], vs[8], vs[7]},
                {vs[4], vs[1], vs[5], vs[8]}, {vs[2], vs[3], vs[7], vs[6]},
                {vs[5], vs[6], vs[7], vs[8]}, {vs[1], vs[4], vs[3], vs[2]}
            }

            for f = 1, 6 do
                local face = faces[f]
                local ux, uy, uz = face[2][1]-face[1][1], face[2][2]-face[1][2], face[2][3]-face[1][3]
                local vx, vy, vz = face[3][1]-face[1][1], face[3][2]-face[1][2], face[3][3]-face[1][3]
                local nx, ny, nz = vec3Normalize(vec3Cross(ux, uy, uz, vx, vy, vz))
                local vcx, vcy, vcz = face[1][1] - camX, face[1][2] - camera.y, face[1][3] - camZ
                local dot = vec3Dot(nx, ny, nz, vcx, vcy, vcz)
                if dot > 0 then
                    local pVerts, visible = {}, true
                    for i = 1, 4 do
                        local sx, sy = camera:project3D(face[i][1], face[i][2], face[i][3])
                        if not sx then visible = false; break end
                        pVerts[i*2-1], pVerts[i*2] = sx, sy
                    end

                    if visible and count < MAX_QUADS then
                        local diff = max(0, vec3Dot(nx, ny, nz, snX, snY, snZ))
                        local br = max(0, shadowFactor or 1.0) * (ambient + diff * (1.0 - ambient))
                        
                        local centerxf = (face[1][1] + face[3][1]) / 2
                        local centeryf = (face[1][2] + face[3][2]) / 2
                        local centerzf = (face[1][3] + face[3][3]) / 2
                        local fDistSq = (centerxf - camX)^2 + (centeryf - camera.y)^2 + (centerzf - camZ)^2

                        count = count + 1
                        entries[count] = {
                            verts = pVerts, 
                            dist = fDistSq,
                            texture = Blocks.materials[b.type],
                            color = {texMul[1]*br, texMul[2]*br, texMul[3]*br},
                            isBlock = true
                        }
                    end
                end
            end
        end
    end

    table.sort(entries, function(a, b) return a.dist > b.dist end)
    return entries
end

function Blocks.ensureAllMeshes(tbl)
    for i = 1, #tbl do
        local t = tbl[i]
        if t and t.verts and not t.mesh then
            local r, g, b = floor(t.color[1]*255), floor(t.color[2]*255), floor(t.color[3]*255)
            local vMesh = {
                {t.verts[1], t.verts[2], 0, 0, r, g, b, 255},
                {t.verts[3], t.verts[4], 1, 0, r, g, b, 255},
                {t.verts[5], t.verts[6], 1, 1, r, g, b, 255},
                {t.verts[7], t.verts[8], 0, 1, r, g, b, 255}
            }
            t.mesh = lg.newMesh(meshFormat, vMesh, "fan", "static")
            if t.texture then 
                t.texture:setWrap("repeat", "repeat")
                t.mesh:setTexture(t.texture) 
            end
        end
    end
end

function Blocks.draw(entries)
    for i = 1, #entries do
        local e = entries[i]
        lg.setColor(e.color[1], e.color[2], e.color[3], 1)
        if e.mesh then lg.draw(e.mesh) else lg.polygon("fill", e.verts) end
    end
    lg.setColor(1, 1, 1, 1)
end

function Blocks.raycast(camera, mx, my, maxDistance)
    local w, h = lg.getDimensions()
    local dx, dy, dz = camera:getRay(mx, my, w, h)
    local lastEmpty = {x=camera.x, y=camera.y, z=camera.z}

    for d = 0, maxDistance, 0.1 do
        local rx, ry, rz = camera.x + dx*d, camera.y + dy*d, camera.z + dz*d
        local nearby = lib3d.getSpatialNearby(rx, rz, 1, 1)
        
        for i = 1, #nearby do
            local b = nearby[i]
            if abs(rx-b.x) <= 0.5 and abs(ry-b.y) <= 0.5 and abs(rz-b.z) <= 0.5 then
                local offX, offY, offZ = rx-b.x, ry-b.y, rz-b.z
                local ax, ay, az = abs(offX), abs(offY), abs(offZ)
                local norm = {nx=0, ny=0, nz=0}
                if ax > ay and ax > az then norm.nx = offX > 0 and 1 or -1
                elseif ay > ax and ay > az then norm.ny = offY > 0 and 1 or -1
                else norm.nz = offZ > 0 and 1 or -1 end
                return b, norm, lastEmpty
            end
        end
        lastEmpty.x, lastEmpty.y, lastEmpty.z = rx, ry, rz
    end
    return nil, nil, lastEmpty
end

function Blocks.getPlacementPosition(hitBlock, normal)
    return hitBlock.x + normal.nx, hitBlock.y + normal.ny, hitBlock.z + normal.nz
end

function Blocks.place(x, y, z, blockType)
    table.insert(Blocks.placed, {
        x = floor(x) + 0.5, y = floor(y), z = floor(z) + 0.5,
        type = blockType
    })
end

function Blocks.load(m)
    Blocks.materials = {
        oak = m.oak, stone = m.stone,
        stone_dark = m.stone_dark or m.stone,
        granite = m.granite or m.phenocryst
    }
end

return Blocks