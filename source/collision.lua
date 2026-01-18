local utils = require("source.utils")
local m = math
local floor, sqrt, min, max, abs = m.floor, m.sqrt, m.min, m.max, m.abs

local collision = {}

function collision.checkAABB(a, b)
    if a.x + a.w <= b.x or a.x >= b.x + b.w then return false end
    if a.y + a.h <= b.y or a.y >= b.y + b.h then return false end
    if a.z + a.d <= b.z or a.z >= b.z + b.d then return false end
    return true
end

local function baryHeight(px, pz, a, b, c)
    local v0x, v0z = b[1]-a[1], b[3]-a[3]
    local v1x, v1z = c[1]-a[1], c[3]-a[3]
    local v2x, v2z = px - a[1], pz - a[3]

    local d00 = v0x*v0x + v0z*v0z
    local d01 = v0x*v1x + v0z*v1z
    local d11 = v1x*v1x + v1z*v1z
    local d20 = v2x*v0x + v2z*v0z
    local d21 = v2x*v1x + v2z*v1z

    local denom = d00 * d11 - d01 * d01
    if abs(denom) < 1e-10 then return a[2] end

    local v = (d11 * d20 - d01 * d21) / denom
    local w = (d00 * d21 - d01 * d20) / denom
    local u = 1 - v - w
    return u * a[2] + v * b[2] + w * c[2]
end

local function pointInTriangle(px, pz, a, b, c)
    local v0x, v0z = c[1]-a[1], c[3]-a[3]
    local v1x, v1z = b[1]-a[1], b[3]-a[3]
    local v2x, v2z = px - a[1], pz - a[3]

    local dot00 = v0x*v0x + v0z*v0z
    local dot01 = v0x*v1x + v0z*v1z
    local dot11 = v1x*v1x + v1z*v1z
    local dot20 = v2x*v0x + v2z*v0z
    local dot21 = v2x*v1x + v2z*v1z

    local denom = dot00 * dot11 - dot01 * dot01
    if abs(denom) < 1e-10 then return false end

    local v = (dot11 * dot20 - dot01 * dot21) / denom
    local w = (dot00 * dot21 - dot01 * dot20) / denom
    local u = 1 - v - w
    return u >= 0 and v >= 0 and w >= 0
end

local function getQuadHeight(x, z, tile)
    local v1, v2, v3, v4 = tile[1], tile[2], tile[3], tile[4]
    if pointInTriangle(x, z, v1, v2, v3) then
        return baryHeight(x, z, v1, v2, v3)
    else
        return baryHeight(x, z, v1, v3, v4)
    end
end

local function safeNormalize(x, y, z)
    local lenSq = x*x + y*y + z*z
    if lenSq < 1e-10 then return 0, 1, 0 end
    local len = sqrt(lenSq)
    return x/len, y/len, z/len
end

local function findTileForPosition(x, z, tileGrid)
    local gx, gz = floor(x), floor(z)
    
    local col = tileGrid[gx]
    if col then
        local t = col[gz]
        if t and (pointInTriangle(x, z, t[1], t[2], t[3]) or pointInTriangle(x, z, t[1], t[3], t[4])) then
            return t
        end
    end
    
    local best = nil
    local bestDistSq = math.huge
    
    for ox = -1, 1 do
        local checkCol = tileGrid[gx + ox]
        if checkCol then
            for oz = -1, 1 do
                local t = checkCol[gz + oz]
                if t then
                    if pointInTriangle(x, z, t[1], t[2], t[3]) or pointInTriangle(x, z, t[1], t[3], t[4]) then
                        return t
                    end
                    local cx = (t[1][1] + t[3][1]) * 0.5
                    local cz = (t[1][3] + t[3][3]) * 0.5
                    local dx, dz = x - cx, z - cz
                    local distSq = dx*dx + dz*dz
                    if distSq < bestDistSq then
                        bestDistSq = distSq
                        best = t
                    end
                end
            end
        end
    end
    return best
end

function collision.resolveWalls(entity, tileGrid)
    if not entity or not tileGrid then return end
    
    local currentTile = findTileForPosition(entity.x, entity.z, tileGrid)
    local groundHeight = currentTile and getQuadHeight(entity.x, entity.z, currentTile) or entity.y
    local stepHeight = 0.5
    local entityCenterX = entity.x
    local entityCenterZ = entity.z
    local entityHalfW = (entity.w or 1) * 0.5
    local entityHalfD = (entity.d or 1) * 0.5
    
    local gx, gz = floor(entityCenterX), floor(entityCenterZ)
    
    for ox = -1, 1 do
        local tx = gx + ox
        local col = tileGrid[tx]
        if not col then goto nextOx end
        
        for oz = -1, 1 do
            if ox == 0 and oz == 0 then goto nextOz end
            
            local tz = gz + oz
            local neighborTile = col[tz]
            
            if neighborTile and neighborTile.visible ~= false then
                local nHeight = neighborTile.height or 0
                local stepDiff = nHeight - (groundHeight + stepHeight)
                
                if stepDiff > 0 and entity.y < nHeight then
                    local wall = {
                        x = tx, y = groundHeight, z = tz,
                        w = 1, h = stepDiff, d = 1
                    }
                    collision.resolveBlocks(entity, {wall})
                end
            end
            
            ::nextOz::
        end
        
        ::nextOx::
    end
end

function collision.resolveVerts(entity, tileGrid)
    if not entity or not tileGrid then return end
    
    local tile = findTileForPosition(entity.x or 0, entity.z or 0, tileGrid)
    if not tile then
        entity.onGround = false
        return
    end

    local height = getQuadHeight(entity.x, entity.z, tile)
    local entityY = entity.y or 0
    local eps = 1e-3
    
    if entityY < height + eps then
        entity.y = height
        local velY = entity.velocityY or 0
        if velY < 0 then
            entity.velocityY = 0
        end
        entity.onGround = true
    else
        entity.onGround = false
    end
end

local function overlapAmount(aMin, aMax, bMin, bMax)
    return min(aMax, bMax) - max(aMin, bMin)
end

function collision.resolveBlocks(entity, blocks)
    if not blocks or #blocks == 0 then return end
    
    local ew = entity.w or 1
    local eh = entity.h or 1
    local ed = entity.d or 1
    local eHalfW = ew * 0.5
    local eHalfD = ed * 0.5
    
    for _, b in ipairs(blocks) do
        if not b then goto continue end
        
        local eMinX, eMaxX = entity.x - eHalfW, entity.x + eHalfW
        local eMinY, eMaxY = entity.y, entity.y + eh
        local eMinZ, eMaxZ = entity.z - eHalfD, entity.z + eHalfD
        
        local bw = b.w or 1
        local bh = b.h or 1
        local bd = b.d or 1
        local bMinX, bMaxX = b.x, b.x + bw
        local bMinY, bMaxY = b.y, b.y + bh
        local bMinZ, bMaxZ = b.z, b.z + bd
        
        if eMaxX <= bMinX or eMinX >= bMaxX or
           eMaxY <= bMinY or eMinY >= bMaxY or
           eMaxZ <= bMinZ or eMinZ >= bMaxZ then
            goto continue
        end
        
        local ox = overlapAmount(eMinX, eMaxX, bMinX, bMaxX)
        local oy = overlapAmount(eMinY, eMaxY, bMinY, bMaxY)
        local oz = overlapAmount(eMinZ, eMaxZ, bMinZ, bMaxZ)
        
        local axis = "x"
        local smallest = ox
        if oz < smallest then
            smallest = oz
            axis = "z"
        end
        
        if oy < smallest and oy < 0.3 then
            axis = "y"
            smallest = oy
        end

        if axis == "x" then
            if entity.x > (bMinX + bMaxX) * 0.5 then
                entity.x = bMaxX + eHalfW
            else
                entity.x = bMinX - eHalfW
            end
            entity.vx = 0
        elseif axis == "z" then
            if entity.z > (bMinZ + bMaxZ) * 0.5 then
                entity.z = bMaxZ + eHalfD
            else
                entity.z = bMinZ - eHalfD
            end
            entity.vz = 0
        elseif axis == "y" then
            if entity.y > (bMinY + bMaxY) * 0.5 then
                entity.y = bMaxY
                entity.velocityY = 0
                entity.onGround = true
            else
                entity.y = bMinY - eh
                entity.velocityY = 0
            end
        end
        
        ::continue::
    end
end

function collision.updateEntity(entity, dt, tileGrid, placedBlocks)
    if not entity then return end
    entity.velocityY = (entity.velocityY or 0) + (entity.gravity or -9.8) * dt
    entity.x = (entity.x or 0) + (entity.vx or 0) * dt
    entity.y = (entity.y or 0) + (entity.velocityY or 0) * dt
    entity.z = (entity.z or 0) + (entity.vz or 0) * dt
    if tileGrid then
        collision.resolveWalls(entity, tileGrid)
        collision.resolveVerts(entity, tileGrid)
    end
    
    if placedBlocks and #placedBlocks > 0 then
        collision.resolveBlocks(entity, placedBlocks)
    end
end

function collision.checkEntities(entity, others)
    if not entity or not others or #others == 0 then return false, nil end
    local ew = entity.w or 1
    local eh = entity.h or 1
    local ed = entity.d or 1
    local eHalfW = ew * 0.5
    local eHalfD = ed * 0.5
    
    local eMinX = (entity.x or 0) - eHalfW
    local eMaxX = (entity.x or 0) + eHalfW
    local eMinY = entity.y or 0
    local eMaxY = (entity.y or 0) + eh
    local eMinZ = (entity.z or 0) - eHalfD
    local eMaxZ = (entity.z or 0) + eHalfD

    for _, o in ipairs(others) do
        local ow = o.w or 1
        local oh = o.h or 1
        local od = o.d or 1
        local oHalfW = ow * 0.5
        local oHalfD = od * 0.5
        
        local oMinX = (o.x or 0) - oHalfW
        local oMaxX = (o.x or 0) + oHalfW
        local oMinY = o.y or 0
        local oMaxY = (o.y or 0) + oh
        local oMinZ = (o.z or 0) - oHalfD
        local oMaxZ = (o.z or 0) + oHalfD
        
        if eMaxX > oMinX and eMinX < oMaxX and
           eMaxY > oMinY and eMinY < oMaxY and
           eMaxZ > oMinZ and eMinZ < oMaxZ then
            return true, o
        end
    end
    
    return false, nil
end

return collision