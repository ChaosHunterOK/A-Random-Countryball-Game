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

local function makeCube(x, y, z, size, texture)
    local s = size / 2
    local v = {
        {x - s, y - s, z - s},
        {x + s, y - s, z - s},
        {x + s, y + s, z - s},
        {x - s, y + s, z - s},
        {x - s, y - s, z + s},
        {x + s, y - s, z + s},
        {x + s, y + s, z + s},
        {x - s, y + s, z + s},
    }
    return {
        {v[1], v[2], v[3], v[4], texture},
        {v[5], v[6], v[7], v[8], texture},
        {v[1], v[5], v[8], v[4], texture},
        {v[2], v[6], v[7], v[3], texture},
        {v[4], v[3], v[7], v[8], texture},
        {v[1], v[2], v[6], v[5], texture},
    }
end

local function getUnderlyingTile(x, z, baseTiles)
    if not baseTiles then return nil end
    for _, tile in ipairs(baseTiles) do
        local v1, v3 = tile[1], tile[3]
        local minX, maxX = math.min(v1[1], v3[1]), math.max(v1[1], v3[1])
        local minZ, maxZ = math.min(v1[3], v3[3]), math.max(v1[3], v3[3])
        if x >= minX and x <= maxX and z >= minZ and z <= maxZ then
            return tile
        end
    end
    return nil
end

function Blocks.generate(camera, renderDistanceSq)
    if not Blocks.placed then
        Blocks.placed = {}
    end
    camera:updateProjectionConstants()
    local camX, camZ = camera.x, camera.z

    local entries = {}
    local count = 0

    for _, block in ipairs(Blocks.placed) do
        local cubeFaces = makeCube(block.x, block.y, block.z, 1, Blocks.materials[block.type])
        local baseTile = getUnderlyingTile(block.x, block.z, Blocks.baseTiles)
        local blendColor = {1, 1, 1}

        if baseTile and baseTile.texture and baseTile.texture.getFilename then
            local ok, name = pcall(function() return baseTile.texture:getFilename():lower() end)
            if ok and name then
                if name:find("stone") then
                    blendColor = {0.85, 0.85, 0.9}
                elseif name:find("sand") then
                    blendColor = {1.0, 0.95, 0.85}
                elseif name:find("grass") then
                    blendColor = {0.9, 1.0, 0.9}
                end
            end
        end

        for _, face in ipairs(cubeFaces) do
            local verts, visible = {}, true
            for i = 1, 4 do
                local v = face[i]
                local sx, sy2, z2 = camera:project3D(v[1], v[2], v[3])
                if not sx then
                    visible = false
                    break
                end
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
                        color = { blendColor[1], blendColor[2], blendColor[3] }
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
    for _, t in ipairs(tbl) do
        if t and t.verts and not t.mesh then
            t.vertsMesh = makeVertsMeshFromVerts(t.verts)
            t.mesh = lg.newMesh(t.vertsMesh, "fan", "static")
            if t.texture then
                t.texture:setWrap("repeat","repeat")
                t.mesh:setTexture(t.texture)
            end
        elseif t and t.mesh and t.texture then
            pcall(function() t.texture:setWrap("repeat","repeat") end)
            t.mesh:setTexture(t.texture)
        end
    end
end

function Blocks.draw(entries)
    for _, e in ipairs(entries) do
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

        for _, block in ipairs(Blocks.placed) do
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
    table.insert(Blocks.placed, {
        x = floor(x),
        y = floor(y),
        z = floor(z),
        type = blockType
    })
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