local utils = require("source.utils")
local m = math
local floor, max, min, abs = m.floor, m.max, m.min, m.abs

local collision = {}
function collision.resolveTerrain(entity, heights)
    local groundY = utils.getHeightAt(entity.x, entity.z, heights)
    if entity.y < groundY + (entity.h or 1) then
        entity.y = groundY + (entity.h or 1)
        entity.velocityY = 0
        entity.onGround = true
    else
        entity.onGround = false
    end
end

function collision.checkAABB(a, b)
    local ax, ay, az = a.x or 0, a.y or 0, a.z or 0
    local aw, ah, ad = a.w or 1, a.h or 1, a.d or 1
    local bx, by, bz = b.x or 0, b.y or 0, b.z or 0
    local bw, bh, bd = b.w or 1, b.h or 1, b.d or 1

    return not (
        ax + aw <= bx or ax >= bx + bw or
        ay + ah <= by or ay >= by + bh or
        az + ad <= bz or az >= bz + bd
    )
end

local function getQuadHeight(x, z, tile)
    local v1, v2, v3, v4 = tile[1], tile[2], tile[3], tile[4]
    local function baryHeight(px, pz, a, b, c)
        local v0x = b[1] - a[1]
        local v0z = b[3] - a[3]
        local v1x = c[1] - a[1]
        local v1z = c[3] - a[3]
        local v2x = px  - a[1]
        local v2z = pz  - a[3]

        local d00 = v0x*v0x + v0z*v0z
        local d01 = v0x*v1x + v0z*v1z
        local d11 = v1x*v1x + v1z*v1z
        local d20 = v2x*v0x + v2z*v0z
        local d21 = v2x*v1x + v2z*v1z

        local denom = d00*d11 - d01*d01
        if denom == 0 then return a[2] end

        local v = (d11*d20 - d01*d21) / denom
        local w = (d00*d21 - d01*d20) / denom
        local u = 1 - v - w

        return u*a[2] + v*b[2] + w*c[2]
    end
    local function pointInTriangle(px, pz, a, b, c)
        local as_x = px - a[1]
        local as_z = pz - a[3]
        
        local ab_x = b[1] - a[1]
        local ab_z = b[3] - a[3]
        local ac_x = c[1] - a[1]
        local ac_z = c[3] - a[3]

        local cross1 = ab_x * as_z - ab_z * as_x
        local cross2 = ac_x * as_z - ac_z * as_x

        return (cross1 >= 0 and cross2 <= 0)
    end

    if pointInTriangle(x, z, v1, v2, v3) then
        return baryHeight(x, z, v1, v2, v3)
    else
        return baryHeight(x, z, v1, v3, v4)
    end
end


function collision.resolveVerts(entity, tileGrid)
    local gx = math.floor(entity.x)
    local gz = math.floor(entity.z)

    local colX = tileGrid[gx]
    if not colX then return end

    local tile = colX[gz]
    if not tile then return end

    local height = getQuadHeight(entity.x, entity.z, tile)

    if entity.y < height then
        entity.y = height
        entity.velocityY = 0
        entity.onGround = true
    else
        entity.onGround = false
    end
end

function collision.resolveBlocks(entity, blocks)
    if not blocks or #blocks == 0 then return end

    local e = {
        x = (entity.x or 0) - (entity.w or 1)/2,
        y = entity.y or 0,
        z = (entity.z or 0) - (entity.d or 1)/2,
        w = entity.w or 1,
        h = entity.h or 1,
        d = entity.d or 1
    }

    for _, block in ipairs(blocks) do
        if not block then goto continue end

        local b = {
            x = block.x or 0,
            y = block.y or 0,
            z = block.z or 0,
            w = block.w or 1,
            h = block.h or 1,
            d = block.d or 1
        }

        if collision.checkAABB(e, b) then
            local overlapX1 = (b.x + b.w) - e.x
            local overlapX2 = (e.x + e.w) - b.x
            local overlapY1 = (b.y + b.h) - e.y
            local overlapY2 = (e.y + e.h) - b.y
            local overlapZ1 = (b.z + b.d) - e.z
            local overlapZ2 = (e.z + e.d) - b.z
            local minOverlap = math.min(overlapX1, overlapX2, overlapY1, overlapY2, overlapZ1, overlapZ2)

            if minOverlap == overlapY1 then
                entity.y = b.y + b.h
                entity.velocityY = 0
                entity.onGround = true
            elseif minOverlap == overlapY2 then
                entity.y = b.y - e.h
                entity.velocityY = 0
            elseif minOverlap == overlapX1 then
                entity.x = b.x + b.w + e.w/2
            elseif minOverlap == overlapX2 then
                entity.x = b.x - e.w/2
            elseif minOverlap == overlapZ1 then
                entity.z = b.z + b.d + e.d/2
            elseif minOverlap == overlapZ2 then
                entity.z = b.z - e.d/2
            end
            e.x = (entity.x or 0) - e.w/2
            e.y = entity.y or 0
            e.z = (entity.z or 0) - e.d/2
        end

        ::continue::
    end
end

function collision.updateEntity(entity, dt, heights, placedBlocks,tileGrid)
    entity.velocityY = (entity.velocityY or 0) + (entity.gravity or -9.8) * dt
    entity.x = entity.x + (entity.vx or 0) * dt
    entity.y = entity.y + entity.velocityY * dt
    entity.z = entity.z + (entity.vz or 0) * dt

    --no longer based on resolveTerrain
    --collision.resolveTerrain(entity, heights)
    collision.resolveVerts(entity, tileGrid)
    if placedBlocks then
        collision.resolveBlocks(entity, placedBlocks)
    end
end

function collision.checkEntities(entity, others)
    local e = {
        x = entity.x - (entity.w or 1)/2,
        y = entity.y,
        z = entity.z - (entity.d or 1)/2,
        w = entity.w or 1,
        h = entity.h or 1,
        d = entity.d or 1
    }

    for _, obj in ipairs(others) do
        local o = {
            x = obj.x - (obj.w or 1)/2,
            y = obj.y,
            z = obj.z - (obj.d or 1)/2,
            w = obj.w or 1,
            h = obj.h or 1,
            d = obj.d or 1
        }

        if collision.checkAABB(e, o) then
            return true, obj
        end
    end

    return false, nil
end

return collision