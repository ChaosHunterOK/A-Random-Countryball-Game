local lib3d = require "source.projectile.lib3d"
local lg = love.graphics

local Blocks = {}
Blocks.placed = {}
Blocks.currentBreaking = {tile = nil, progress = 0, max = 3}
_G.blockPlacables = {
    stone = true, granite = true, dirt = true, oak = true, wood_planks = true,
}

Blocks.durabilities = {stone = 5, dirt = 2, oak = 4, wood_planks = 3}
Blocks.bestTools = {stone = "pickaxe", dirt = "shovel", oak = "axe", wood_planks = "axe"}
Blocks.requiresTool = {stone = true, granite = true, dark_stone = true,}
local renderCache = {}

function Blocks.place(x, y, z, type)
    table.insert(Blocks.placed, {
        x = x, y = y, z = z,
        type = type,
        texture = _G.materials[type] or _G.materials.stone
    })
end

function Blocks.generate(camera, renderDistanceSq)
    for i = 1, #renderCache do renderCache[i] = nil end
    
    local camX, camY, camZ = camera.x, camera.y, camera.z
    local count = 0
    local s = 0.5

    for _, b in ipairs(Blocks.placed) do
        local dx, dy, dz = b.x - camX, b.y - camY, b.z - camZ
        local distSq = dx*dx + dy*dy + dz*dz
        
        if distSq < renderDistanceSq then
            count = count + 1
            local blockEntry = renderCache[count] or {}
            blockEntry.dist = distSq
            blockEntry.x, blockEntry.y, blockEntry.z = b.x, b.y, b.z
            blockEntry.type = b.type
            blockEntry.texture = b.texture
            blockEntry.faces = blockEntry.faces or {}
            local faceCount = 0
            local offsets = {
                {-s,s,-s, s,s,-s, s,s,s, -s,s,s},
                {-s,-s,-s, s,-s,-s, s,-s,s, -s,-s,s},
                {-s,-s,-s, s,-s,-s, s,s,-s, -s,s,-s},
                {-s,-s,s, s,-s,s, s,s,s, -s,s,s},
                {-s,-s,-s, -s,-s,s, -s,s,s, -s,s,-s},
                {s,-s,-s, s,-s,s, s,s,s, s,s,-s},
            }

            for i = 1, 6 do
                local o = offsets[i]
                local v1x, v1y = camera:project3D(b.x+o[1], b.y+o[2], b.z+o[3])
                local v2x, v2y = camera:project3D(b.x+o[4], b.y+o[5], b.z+o[6])
                local v3x, v3y = camera:project3D(b.x+o[7], b.y+o[8], b.z+o[9])
                local v4x, v4y = camera:project3D(b.x+o[10], b.y+o[11], b.z+o[12])

                if v1x and v2x and v3x and v4x then
                    faceCount = faceCount + 1
                    local f = blockEntry.faces[faceCount] or {}
                    f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8] = v1x, v1y, v2x, v2y, v3x, v3y, v4x, v4y
                    blockEntry.faces[faceCount] = f
                end
            end
            for i = faceCount + 1, #blockEntry.faces do blockEntry.faces[i] = nil end
            renderCache[count] = blockEntry
        end
    end

    return renderCache
end

return Blocks