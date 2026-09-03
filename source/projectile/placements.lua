local lg = love.graphics
local abs = math.abs

local Placements = {}
Placements.placed = {}
Placements.currentBreaking = {tile = nil, progress = 0, max = 3}
_G.placementPlacables = {
    stone = true, granite = true, dirt = true, oak = true, wood_planks = true,
}
_G.blockPlacables = _G.placementPlacables

Placements.durabilities = {stone = 5, dirt = 2, oak = 4, wood_planks = 3}
Placements.bestTools = {stone = "pickaxe", dirt = "shovel", oak = "axe", wood_planks = "axe"}
Placements.requiresTool = {stone = true, granite = true, dark_stone = true,}
local renderCache = {}

Placements.pendingMode = "floor"
Placements.pendingYaw = 0

Placements.attachRadius = 0.75
function Placements.rotateMode()
    Placements.pendingMode = (Placements.pendingMode == "floor") and "wall" or "floor"
end

function Placements.rotateYaw()
    Placements.pendingYaw = (Placements.pendingYaw + 1) % 4
end

local function getPanelCorners(x, y, z, mode, yaw)
    local s = 0.5
    if mode == "floor" then
        return {
            {x - s, y, z - s},
            {x + s, y, z - s},
            {x + s, y, z + s},
            {x - s, y, z + s},
        }
    else
        if (yaw or 0) % 2 == 0 then
            return {
                {x - s, y, z},
                {x + s, y, z},
                {x + s, y + 1, z},
                {x - s, y + 1, z},
            }
        else
            return {
                {x, y, z - s},
                {x, y, z + s},
                {x, y + 1, z + s},
                {x, y + 1, z - s},
            }
        end
    end
end
Placements.getPanelCorners = getPanelCorners
function Placements.findAttachment(x, y, z)
    local best, bestDistSq = nil, Placements.attachRadius * Placements.attachRadius

    for i = 1, #Placements.placed do
        local p = Placements.placed[i]
        local dx, dy, dz = x - p.x, y - p.y, z - p.z
        local distSq = dx*dx + dy*dy + dz*dz
        if distSq < bestDistSq then
            bestDistSq = distSq
            best = p
        end
    end

    if not best then return nil end

    local dx, dy, dz = x - best.x, y - best.y, z - best.z
    local ax, ay, az = abs(dx), abs(dy), abs(dz)

    local snapX, snapY, snapZ = best.x, best.y, best.z
    if ay >= ax and ay >= az then
        snapY = best.y + (dy >= 0 and 1 or -1)
    elseif ax >= az then
        snapX = best.x + (dx >= 0 and 1 or -1)
    else
        snapZ = best.z + (dz >= 0 and 1 or -1)
    end

    return snapX, snapY, snapZ, best.mode, best.yaw
end

function Placements.resolvePlacement(hitX, hitY, hitZ)
    local ax, ay, az, aMode, aYaw = Placements.findAttachment(hitX, hitY, hitZ)
    if ax then
        return ax, ay, az, aMode, aYaw, true
    end
    return hitX, hitY, hitZ, Placements.pendingMode, Placements.pendingYaw, false
end

function Placements.place(x, y, z, type, mode, yaw)
    table.insert(Placements.placed, {
        x = x, y = y, z = z,
        type = type,
        mode = mode or Placements.pendingMode,
        yaw = yaw or Placements.pendingYaw,
        texture = _G.materials[type] or _G.materials.stone
    })
end

function Placements.generate(camera, renderDistanceSq)
    for i = 1, #renderCache do renderCache[i] = nil end
    
    local camX, camY, camZ = camera.x, camera.y, camera.z
    local count = 0

    for _, b in ipairs(Placements.placed) do
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

            local corners = getPanelCorners(b.x, b.y, b.z, b.mode or "floor", b.yaw or 0)
            local c1, c2, c3, c4 = corners[1], corners[2], corners[3], corners[4]

            local v1x, v1y = camera:project3D(c1[1], c1[2], c1[3])
            local v2x, v2y = camera:project3D(c2[1], c2[2], c2[3])
            local v3x, v3y = camera:project3D(c3[1], c3[2], c3[3])
            local v4x, v4y = camera:project3D(c4[1], c4[2], c4[3])

            local faceCount = 0
            if v1x and v2x and v3x and v4x then
                faceCount = faceCount + 1
                local f = blockEntry.faces[faceCount] or {}
                f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8] = v1x, v1y, v2x, v2y, v3x, v3y, v4x, v4y
                blockEntry.faces[faceCount] = f
                faceCount = faceCount + 1
                local fb = blockEntry.faces[faceCount] or {}
                fb[1], fb[2], fb[3], fb[4], fb[5], fb[6], fb[7], fb[8] = v4x, v4y, v3x, v3y, v2x, v2y, v1x, v1y
                blockEntry.faces[faceCount] = fb
            end
            for i = faceCount + 1, #blockEntry.faces do blockEntry.faces[i] = nil end
            renderCache[count] = blockEntry
        end
    end

    return renderCache
end

return Placements