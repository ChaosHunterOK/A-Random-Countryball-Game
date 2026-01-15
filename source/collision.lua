local utils = require("source.utils")
local m = math
local floor, sqrt, min, max = m.floor, m.sqrt, m.min, m.max

local collision = {}

function collision.checkAABB(a, b)
    return not (
        a.x + a.w <= b.x or
        a.x >= b.x + b.w or
        a.y + a.h <= b.y or
        a.y >= b.y + b.h or
        a.z + a.d <= b.z or
        a.z >= b.z + b.d
    )
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
    if denom == 0 then return a[2] end

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
    if denom == 0 then return false end

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

local function safeNormalize(x,y,z)
    local len = sqrt(x*x + y*y + z*z)
    if len == 0 then return 0,1,0 end
    return x/len, y/len, z/len
end

local function triangleNormal(a, b, c)
    local ux, uy, uz = b[1]-a[1], b[2]-a[2], b[3]-a[3]
    local vx, vy, vz = c[1]-a[1], c[2]-a[2], c[3]-a[3]
    local nx, ny, nz = uy*vz - uz*vy, uz*vx - ux*vz, ux*vy - uy*vx
    return safeNormalize(nx, ny, nz)
end

local function findTileForPosition(x, z, tileGrid)
    local gx, gz = floor(x), floor(z)
    local best = nil
    for ox=-1,1 do
        local col = tileGrid[gx + ox]
        if col then
            for oz=-1,1 do
                local t = col[gz + oz]
                if t then
                    if pointInTriangle(x, z, t[1], t[2], t[3]) or pointInTriangle(x, z, t[1], t[3], t[4]) then
                        return t
                    end
                    if not best then
                        best = t
                    else
                        local cx = (t[1][1] + t[3][1]) * 0.5
                        local cz = (t[1][3] + t[3][3]) * 0.5
                        local bcx = (best[1][1] + best[3][1]) * 0.5
                        local bcz = (best[1][3] + best[3][3]) * 0.5
                        local dnew = (x-cx)*(x-cx) + (z-cz)*(z-cz)
                        local dbest = (x-bcx)*(x-bcx) + (z-bcz)*(z-bcz)
                        if dnew < dbest then best = t end
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

    local gx, gz = floor(entity.x), floor(entity.z)
    local stepHeight = 0.5
    for ox = -1, 1 do
        for oz = -1, 1 do
            if ox ~= 0 or oz ~= 0 then
                local tx, tz = gx + ox, gz + oz
                local col = tileGrid[tx]
                local neighborTile = col and col[tz]
                
                if neighborTile and neighborTile.visible ~= false then
                    local nHeight = neighborTile.height or 0
                    if nHeight > (groundHeight + stepHeight) and entity.y < nHeight then
                        local wall = {
                            x = tx, y = 0, z = tz,
                            w = 1, h = nHeight, d = 1
                        }
                        collision.resolveBlocks(entity, {wall})
                    end
                end
            end
        end
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
    local eps = 1e-3
    if (entity.y or 0) < height + eps then
        entity.y = height
        if (entity.velocityY or 0) < 0 then
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
    for _, b in ipairs(blocks) do
        if not b then goto continue end
        local eMinX, eMaxX = entity.x - ew*0.5, entity.x + ew*0.5
        local eMinY, eMaxY = entity.y, entity.y + eh
        local eMinZ, eMaxZ = entity.z - ed*0.5, entity.z + ed*0.5
        
        local bMinX, bMaxX = b.x, b.x + (b.w or 1)
        local bMinY, bMaxY = b.y, b.y + (b.h or 1)
        local bMinZ, bMaxZ = b.z, b.z + (b.d or 1)
        
        if eMaxX > bMinX and eMinX < bMaxX and
           eMaxY > bMinY and eMinY < bMaxY and
           eMaxZ > bMinZ and eMinZ < bMaxZ then
            
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
            end

            if axis == "x" then
                entity.x = (entity.x > (bMinX + bMaxX) * 0.5) and (bMaxX + ew*0.5) or (bMinX - ew*0.5)
                entity.vx = 0
            elseif axis == "z" then
                entity.z = (entity.z > (bMinZ + bMaxZ) * 0.5) and (bMaxZ + ed*0.5) or (bMinZ - ed*0.5)
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
    collision.resolveWalls(entity, tileGrid)
    collision.resolveVerts(entity, tileGrid)
    if placedBlocks then
        collision.resolveBlocks(entity, placedBlocks)
    end
end

function collision.checkEntities(entity, others)
    local ew = entity.w or 1
    local eh = entity.h or 1
    local ed = entity.d or 1
    local e = {
        x = (entity.x or 0) - ew*0.5,
        y = entity.y or 0,
        z = (entity.z or 0) - ed*0.5,
        w = ew, h = eh, d = ed
    }

    for _, o in ipairs(others) do
        local ow = o.w or 1
        local oh = o.h or 1
        local od = o.d or 1
        local obj = {
            x = (o.x or 0) - ow*0.5,
            y = o.y or 0,
            z = (o.z or 0) - od*0.5,
            w = ow, h = oh, d = od
        }
        if collision.checkAABB(e, obj) then
            return true, o
        end
    end
    return false, nil
end

return collision