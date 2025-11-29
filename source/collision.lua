local utils = require("source.utils")
local m = math
local floor, sqrt, min = m.floor, m.sqrt, m.min

local collision = {}

function collision.checkAABB(a, b)
    return not (
        (a.x or 0) + (a.w or 1) <= (b.x or 0) or
        (a.x or 0) >= (b.x or 0) + (b.w or 1) or
        (a.y or 0) + (a.h or 1) <= (b.y or 0) or
        (a.y or 0) >= (b.y or 0) + (b.h or 1) or
        (a.z or 0) + (a.d or 1) <= (b.z or 0) or
        (a.z or 0) >= (b.z or 0) + (b.d or 1)
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

    local denom = d00*d11 - d01*d01
    if denom == 0 then return a[2] end

    local v = (d11*d20 - d01*d21) / denom
    local w = (d00*d21 - d01*d20) / denom
    local u = 1 - v - w
    return u*a[2] + v*b[2] + w*c[2]
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

    local denom = dot00*dot11 - dot01*dot01
    if denom == 0 then return false end

    local v = (dot11*dot20 - dot01*dot21)/denom
    local w = (dot00*dot21 - dot01*dot20)/denom
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

local function triangleNormal(a, b, c)
    local ux, uy, uz = b[1]-a[1], b[2]-a[2], b[3]-a[3]
    local vx, vy, vz = c[1]-a[1], c[2]-a[2], c[3]-a[3]
    local nx, ny, nz = uy*vz - uz*vy, uz*vx - ux*vz, ux*vy - uy*vx
    local len = sqrt(nx*nx + ny*ny + nz*nz)
    return nx/len, ny/len, nz/len
end

function collision.resolveVerts(entity, tileGrid)
    local gx, gz = floor(entity.x), floor(entity.z)
    local colX = tileGrid[gx]
    if not colX then return end
    local tile = colX[gz]
    if not tile then return end

    local height = getQuadHeight(entity.x, entity.z, tile)
    if entity.y < height then
        entity.y = height
        entity.velocityY = 0
        entity.onGround = true

        local vx, vy, vz = entity.vx or 0, entity.velocityY, entity.vz or 0
        if vx ~= 0 or vz ~= 0 then
            local v1, v2, v3, v4 = tile[1], tile[2], tile[3], tile[4]
            local nx, ny, nz
            if pointInTriangle(entity.x, entity.z, v1, v2, v3) then
                nx, ny, nz = triangleNormal(v1, v2, v3)
            else
                nx, ny, nz = triangleNormal(v1, v3, v4)
            end
            local dot = vx*nx + vy*ny + vz*nz
            entity.vx = vx - dot*nx
            entity.velocityY = vy - dot*ny
            entity.vz = vz - dot*nz
        end
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

    for _, b in ipairs(blocks) do
        if not b then goto continue end
        if collision.checkAABB(e, b) then
            local ox1 = (b.x+b.w)-e.x
            local ox2 = (e.x+e.w)-b.x
            local oy1 = (b.y+b.h)-e.y
            local oy2 = (e.y+e.h)-b.y
            local oz1 = (b.z+b.d)-e.z
            local oz2 = (e.z+e.d)-b.z
            local minOverlap = min(ox1, ox2, oy1, oy2, oz1, oz2)

            if minOverlap == oy1 then
                entity.y = b.y + b.h
                entity.velocityY = 0
                entity.onGround = true
            elseif minOverlap == oy2 then
                entity.y = b.y - e.h
                entity.velocityY = 0
            elseif minOverlap == ox1 then
                entity.x = b.x + b.w + e.w/2
            elseif minOverlap == ox2 then
                entity.x = b.x - e.w/2
            elseif minOverlap == oz1 then
                entity.z = b.z + b.d + e.d/2
            elseif minOverlap == oz2 then
                entity.z = b.z - e.d/2
            end

            e.x = (entity.x or 0) - e.w/2
            e.y = entity.y or 0
            e.z = (entity.z or 0) - e.d/2
        end
        ::continue::
    end
end

function collision.updateEntity(entity, dt, tileGrid, placedBlocks)
    entity.velocityY = (entity.velocityY or 0) + (entity.gravity or -9.8) * dt
    entity.x = (entity.x or 0) + (entity.vx or 0) * dt
    entity.y = (entity.y or 0) + entity.velocityY * dt
    entity.z = (entity.z or 0) + (entity.vz or 0) * dt

    collision.resolveVerts(entity, tileGrid)
    if placedBlocks then
        collision.resolveBlocks(entity, placedBlocks)
    end
end

function collision.checkEntities(entity, others)
    local e = {
        x = (entity.x or 0) - (entity.w or 1)/2,
        y = entity.y or 0,
        z = (entity.z or 0) - (entity.d or 1)/2,
        w = entity.w or 1,
        h = entity.h or 1,
        d = entity.d or 1
    }

    for _, o in ipairs(others) do
        local obj = {
            x = (o.x or 0) - (o.w or 1)/2,
            y = o.y or 0,
            z = (o.z or 0) - (o.d or 1)/2,
            w = o.w or 1,
            h = o.h or 1,
            d = o.d or 1
        }
        if collision.checkAABB(e, obj) then
            return true, o
        end
    end
    return false, nil
end

return collision