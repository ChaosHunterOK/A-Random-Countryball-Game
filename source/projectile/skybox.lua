local love = require "love"
local lg = love.graphics
local lib3d = require "source.projectile.lib3d"
local camera = require("source.projectile.camera")

local Skybox = {}
Skybox.texture = nil
Skybox.color = {1, 1, 1, 1}

local sphereVerts3D = {}
local skyMesh = nil
local verts2DCache = {}

local function makeSphere(radius, rings, segments)
    local verts = {}

    for r = 0, rings - 1 do
        local v1 = r / rings
        local v2 = (r + 1) / rings

        local phi1 = v1 * math.pi
        local phi2 = v2 * math.pi

        for s = 0, segments - 1 do
            local u1 = s / segments
            local u2 = (s + 1) / segments

            local theta1 = u1 * math.pi * 2
            local theta2 = u2 * math.pi * 2
            local function point(theta, phi, u, v)
                return {
                    math.cos(theta) * math.sin(phi) * radius,
                    math.cos(phi) * radius,
                    math.sin(theta) * math.sin(phi) * radius,
                    u, v
                }
            end

            local p1 = point(theta1, phi1, u1, v1)
            local p2 = point(theta1, phi2, u1, v2)
            local p3 = point(theta2, phi2, u2, v2)
            local p4 = point(theta2, phi1, u2, v1)
            table.insert(verts, p1)
            table.insert(verts, p2)
            table.insert(verts, p3)

            table.insert(verts, p1)
            table.insert(verts, p3)
            table.insert(verts, p4)
        end
    end

    return verts
end

function Skybox.load()
    Skybox.texture = lg.newImage("image/skyBox/top.png")
    Skybox.texture:setWrap("repeat", "repeat")

    sphereVerts3D = makeSphere(400, 50, 48)

    local dummy = {}
    for i = 1, #sphereVerts3D do
        dummy[i] = {0, 0, 0, 0, 1, 1, 1, 1}
    end

    skyMesh = lg.newMesh(
        {
            {"VertexPosition", "float", 2},
            {"VertexTexCoord", "float", 2},
            {"VertexColor", "float", 4},
        },
        dummy,
        "triangles",
        "dynamic"
    )

    skyMesh:setTexture(Skybox.texture)
end

function Skybox.setColor(r, g, b, a)
    Skybox.color = {r or 1, g or 1, b or 1, a or 1}
end

function Skybox.draw()
    if not skyMesh then return end

    lib3d.resetTempPool()

    local cx, cy, cz = camera.x, camera.y, camera.z
    local count = #sphereVerts3D

    if #verts2DCache < count then
        for i = #verts2DCache + 1, count do
            verts2DCache[i] = {0, 0, 0, 0, 1, 1, 1, 1}
        end
    end

    local cr, cg, cb, ca = unpack(Skybox.color)

    for i = 1, count do
        local v = sphereVerts3D[i]
        local sx, sy = camera:project3D(v[1], v[2], v[3])

        local vert = verts2DCache[i]
        if sx and sy then
            vert[1] = sx
            vert[2] = sy
        else
            vert[1] = 0
            vert[2] = 0
        end
        vert[3] = v[4]
        vert[4] = v[5]
        vert[5] = cr
        vert[6] = cg
        vert[7] = cb
        vert[8] = ca
    end

    skyMesh:setVertices(verts2DCache)

    lg.setDepthMode("lequal", false)
    lg.draw(skyMesh)
end

return Skybox