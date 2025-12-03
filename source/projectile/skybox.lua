local love = require "love"
local lg = love.graphics
local camera = require("source.projectile.camera")
local countryball = require("source.countryball")

local Skybox = {}
Skybox.textures = {}
Skybox.meshes = {}
Skybox.x, Skybox.y, Skybox.z = 0, 0, 0

function Skybox.load()
    Skybox.textures.top = lg.newImage("image/skyBox/top.png")
    Skybox.textures.bottom = lg.newImage("image/skyBox/bottom.png")
    Skybox.textures.side = lg.newImage("image/skyBox/side.png")

    for _, tex in pairs(Skybox.textures) do
        tex:setWrap("repeat", "repeat")
    end
end

local function makeCubeFaces(size)
    local s = size / 2
    local faces = {}
    faces[1] = { { {-s,s,-s}, {s,s,-s}, {s,s,s}, {-s,s,s} }, Skybox.textures.top }
    faces[2] = { { {-s,-s,-s}, {s,-s,-s}, {s,-s,s}, {-s,-s,s} }, Skybox.textures.bottom }
    faces[3] = { { {-s,-s,s}, {s,-s,s}, {s,s,s}, {-s,s,s} }, Skybox.textures.side }
    faces[4] = { { {-s,-s,-s}, {s,-s,-s}, {s,s,-s}, {-s,s,-s} }, Skybox.textures.side }
    faces[5] = { { {-s,-s,-s}, {-s,-s,s}, {-s,s,s}, {-s,s,-s} }, Skybox.textures.side }
    faces[6] = { { {s,-s,-s}, {s,-s,s}, {s,s,s}, {s,s,-s} }, Skybox.textures.side }
    return faces
end

local function projectFace(face)
    local verts2D = {}
    local verts = face[1]
    for i = 1, 4 do
        local v = verts[i]
        local sx, sy = camera:project3D(
            v[1] + Skybox.x,
            v[2] + Skybox.y,
            v[3] + Skybox.z
        )
        verts2D[i*2-1], verts2D[i*2] = sx or 0, sy or 0
    end
    return verts2D
end

local function makeMeshFromVerts(verts, texture)
    local meshVerts = {
        {verts[1], verts[2], 0, 0},
        {verts[3], verts[4], 1, 0},
        {verts[5], verts[6], 1, 1},
        {verts[7], verts[8], 0, 1},
    }
    local mesh = lg.newMesh(meshVerts, "fan", "static")
    if texture then
        pcall(function()
            texture:setWrap("repeat", "repeat")
            mesh:setTexture(texture)
        end)
    end
    return mesh
end

function Skybox.draw(size)
    Skybox.x, Skybox.y, Skybox.z = countryball.x / 2, countryball.y / 2, countryball.z / 2

    size = tonumber(size) or 10000
    local faces = makeCubeFaces(size)

    for _, face in ipairs(faces) do
        local verts = projectFace(face)
        if verts then
            local mesh = makeMeshFromVerts(verts, face[2])
            lg.draw(mesh)
        end
    end
end

return Skybox