local love = require "love"
local lg = love.graphics
local lib3d = require "source.projectile.lib3d"
local camera = require("source.projectile.camera")

local Skybox = {}
Skybox.texture = nil

local domeVerts3D = {}
local skyMesh = nil
local verts2DCache = {}

local function makeSkyDome(radius, rings, segments)
    local verts = {}
    local vertCount = 0

    for r = 0, rings - 1 do
        local v1 = r / rings
        local v2 = (r + 1) / rings

        local phi1 = v1 * math.pi * 0.5
        local phi2 = v2 * math.pi * 0.5

        for s = 0, segments do
            local u = s / segments
            local theta = u * math.pi * 2

            local x1 = math.cos(theta) * math.cos(phi1) * radius
            local y1 = math.sin(phi1) * radius
            local z1 = math.sin(theta) * math.cos(phi1) * radius

            local x2 = math.cos(theta) * math.cos(phi2) * radius
            local y2 = math.sin(phi2) * radius
            local z2 = math.sin(theta) * math.cos(phi2) * radius

            vertCount = vertCount + 1
            verts[vertCount] = {x1, y1, z1, u, v1}
            vertCount = vertCount + 1
            verts[vertCount] = {x2, y2, z2, u, v2}
        end
    end

    return verts
end

function Skybox.load()
    Skybox.texture = lg.newImage("image/skyBox/top.png")
    Skybox.texture:setWrap("repeat", "clamp")

    domeVerts3D = makeSkyDome(400, 50, 48)

    local dummy = {}
    for i = 1, #domeVerts3D do
        dummy[i] = {0, 0, 0, 0}
    end

    skyMesh = lg.newMesh(
        {
            {"VertexPosition", "float", 2},
            {"VertexTexCoord", "float", 2},
        },
        dummy,
        "strip",
        "dynamic"
    )

    skyMesh:setTexture(Skybox.texture)
end

function Skybox.draw()
    if not skyMesh then return end

    lib3d.resetTempPool()
    
    local cx, cy, cz = camera.x, camera.y, camera.z
    local skyVertCount = #domeVerts3D
    if #verts2DCache < skyVertCount then
        for i = #verts2DCache + 1, skyVertCount do
            verts2DCache[i] = {0, 0, 0, 0}
        end
    end

    for i = 1, skyVertCount do
        local v = domeVerts3D[i]
        local sx, sy, sz = camera:project3D(v[1] + cx, v[2] + cy, v[3] + cz)
        
        local vert = verts2DCache[i]
        vert[1], vert[2], vert[3], vert[4] = sx, sy, v[4], v[5]
    end

    skyMesh:setVertices(verts2DCache)

    lg.setDepthMode(nil)
    lg.setColor(1, 1, 1)
    lg.draw(skyMesh)
end

return Skybox