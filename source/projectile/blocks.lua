local ffi = require "ffi"
local love = require "love"
local lg = love.graphics
local cos, sin = math.cos, math.sin
local floor = math.floor
local Blocks = {}
Blocks.placed = {}
Blocks.materials = {}
Blocks.baseTiles = nil

Blocks.durabilities = {
    dirt = 2,
    sandNormal = 2,
    sandGarnet = 3,
    sandOlivine = 3,
    stone = 5,
    granite = 6,
    gabbro = 7,
    basalt = 8,
    rhyolite = 5,
    pumice = 4,
    oak = 2,
    lava = 9999
}

Blocks.currentBreaking = {
    tile = nil,
    progress = 0,
    max = 1,
}

local function makeCubeFaces(x, y, z, size, texture)
    local s = size / 2
    local v1 = {x - s, y - s, z - s}
    local v2 = {x + s, y - s, z - s}
    local v3 = {x + s, y + s, z - s}
    local v4 = {x - s, y + s, z - s}
    local v5 = {x - s, y - s, z + s}
    local v6 = {x + s, y - s, z + s}
    local v7 = {x + s, y + s, z + s}
    local v8 = {x - s, y + s, z + s}
    return {
        {v1, v2, v3, v4, texture},
        {v5, v6, v7, v8, texture},
        {v1, v5, v8, v4, texture},
        {v2, v6, v7, v3, texture},
        {v4, v3, v7, v8, texture},
        {v1, v2, v6, v5, texture},
    }
end

local function getUnderlyingTile(x, z, baseTiles)
    if not baseTiles then return nil end
    for i = 1, #baseTiles do
        local tile = baseTiles[i]
        local v1, v3 = tile[1], tile[3]
        local minX, maxX = v1[1] < v3[1] and v1[1] or v3[1], v1[1] < v3[1] and v3[1] or v1[1]
        local minZ, maxZ = v1[3] < v3[3] and v1[3] or v3[3], v1[3] < v3[3] and v3[3] or v1[3]
        if x >= minX and x <= maxX and z >= minZ and z <= maxZ then
            return tile
        end
    end
    return nil
end

function Blocks.generate(camera, renderDistanceSq)
    Blocks.placed = Blocks.placed or {}
    camera:updateProjectionConstants()
    local camX, camZ = camera.x, camera.z

    local entries = {}
    local count = 0

    for bi = 1, #Blocks.placed do
        local block = Blocks.placed[bi]
        local cubeFaces = makeCubeFaces(block.x, block.y, block.z, 1, Blocks.materials[block.type])
        local baseTile = getUnderlyingTile(block.x, block.z, Blocks.baseTiles)
        local blendR, blendG, blendB = 1,1,1

        if baseTile and baseTile.texture and baseTile.texture.getFilename then
            local ok, name = pcall(function() return baseTile.texture:getFilename():lower() end)
            if ok and name then
                if name:find("stone") then
                    blendR, blendG, blendB = 0.85, 0.85, 0.9
                elseif name:find("sand") then
                    blendR, blendG, blendB = 1.0, 0.95, 0.85
                elseif name:find("grass") then
                    blendR, blendG, blendB = 0.9, 1.0, 0.9
                end
            end
        end

        for fi = 1, #cubeFaces do
            local face = cubeFaces[fi]
            local verts = {}
            local visible = true
            for i = 1, 4 do
                local v = face[i]
                local sx, sy2 = camera:project3D(v[1], v[2], v[3])
                if not sx then visible = false; break end
                verts[i*2-1], verts[i*2] = sx, sy2
            end

            if visible then
                local v1, v3 = face[1], face[3]
                local cx = (v1[1] + v3[1]) * 0.5 - camX
                local cz = (v1[3] + v3[3]) * 0.5 - camZ
                local distSq = cx*cx + cz*cz
                if distSq <= renderDistanceSq then
                    count = count + 1
                    entries[count] = {
                        verts = verts,
                        dist = distSq,
                        texture = face[5],
                        color = { blendR, blendG, blendB }
                    }
                end
            end
        end
    end

    table.sort(entries, function(a, b) return a.dist > b.dist end)
    return entries
end

local function makeVertsMeshFromVerts(verts)
    return {
        {verts[1], verts[2], 0, 0},
        {verts[3], verts[4], 1, 0},
        {verts[5], verts[6], 1, 1},
        {verts[7], verts[8], 0, 1},
    }
end

function Blocks.ensureAllMeshes(tbl)
    for i = 1, #tbl do
        local t = tbl[i]
        if t and t.verts and not t.mesh then
            t.vertsMesh = makeVertsMeshFromVerts(t.verts)
            t.mesh = lg.newMesh(t.vertsMesh, "fan", "static")
            if t.texture then
                pcall(function() t.texture:setWrap("repeat","repeat") end)
                t.mesh:setTexture(t.texture)
            end
        elseif t and t.mesh and t.texture then
            pcall(function() t.texture:setWrap("repeat","repeat") end)
            t.mesh:setTexture(t.texture)
        end
    end
end

function Blocks.draw(entries)
    for i = 1, #entries do
        local e = entries[i]
        lg.setColor(e.color or {1,1,1})
        if e.mesh then
            lg.draw(e.mesh)
        else
            lg.polygon("fill", e.verts)
        end
    end
    lg.setColor(1,1,1,1)
end

function Blocks.raycast(camera, mx, my, maxDistance)
    local width, height = love.graphics.getWidth(), love.graphics.getHeight()
    local nx = (mx / width - 0.5) * 2
    local ny = (my / height - 0.5) * -2

    local cp = math.cos(camera.pitch)
    local sp = math.sin(camera.pitch)
    local cy = math.cos(camera.yaw)
    local sy = math.sin(camera.yaw)

    local dirX = sy * cp
    local dirY = -sp
    local dirZ = cy * cp

    local step = 0.05
    local lastEmpty = { x=camera.x, y=camera.y, z=camera.z }

    for d = 0, maxDistance, step do
        local rx = camera.x + dirX * d
        local ry = camera.y + dirY * d
        local rz = camera.z + dirZ * d
        lastEmpty.x, lastEmpty.y, lastEmpty.z = rx, ry, rz

        for i = 1, #Blocks.placed do
            local block = Blocks.placed[i]
            local bx, by, bz = block.x, block.y, block.z

            if math.abs(rx - bx) <= 0.5
            and math.abs(ry - by) <= 0.5
            and math.abs(rz - bz) <= 0.5 then
                local dx = rx - bx
                local dy = ry - by
                local dz = rz - bz
                local ax, ay, az = math.abs(dx), math.abs(dy), math.abs(dz)

                local nx, ny, nz = 0, 0, 0
                if ax > ay and ax > az then
                    nx = (dx > 0) and 1 or -1
                elseif ay > ax and ay > az then
                    ny = (dy > 0) and 1 or -1
                else
                    nz = (dz > 0) and 1 or -1
                end

                return block, {nx=nx, ny=ny, nz=nz}, lastEmpty
            end
        end
    end

    return nil, nil, lastEmpty
end

function Blocks.getPlacementPosition(hitBlock, normal)
    return
        hitBlock.x + normal.nx,
        hitBlock.y + normal.ny,
        hitBlock.z + normal.nz
end

function Blocks.place(x, y, z, blockType)
    Blocks.placed[#Blocks.placed+1] = {
        x = floor(x),
        y = floor(y),
        z = floor(z),
        type = blockType
    }
end

function Blocks.load(materials)
    Blocks.materials = {
        oak = materials.oak,
        stone = materials.stone,
        stone_dark = materials.stone_dark or materials.stone,
        granite = materials.granite or materials.phenocryst
    }
end

return Blocks