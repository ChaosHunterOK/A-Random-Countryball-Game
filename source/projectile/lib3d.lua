--new library lol
local ffi = require "ffi"
local lib3d = {}

function lib3d.vec3Normalize(x, y, z)
    local len = math.sqrt(x*x + y*y + z*z)
    if len == 0 then return x, y, z end
    return x/len, y/len, z/len
end

function lib3d.vec3Dot(ax, ay, az, bx, by, bz)
    return ax*bx + ay*by + az*bz
end

function lib3d.vec3Cross(ax, ay, az, bx, by, bz)
    return ay*bz - az*by, az*bx - ax*bz, ax*by - ay*bx
end

function lib3d.vec3LenSq(x, y, z)
    return x*x + y*y + z*z
end

function lib3d.vec3Len(x, y, z)
    return math.sqrt(x*x + y*y + z*z)
end

function lib3d.vec3Dist(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1-x2, y1-y2, z1-z2
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function lib3d.vec3DistSq(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1-x2, y1-y2, z1-z2
    return dx*dx + dy*dy + dz*dz
end
function lib3d.rotateYawPitch(x, y, z, yaw, pitch)
    local cy, sy = math.cos(yaw), math.sin(yaw)
    local cp, sp = math.cos(pitch), math.sin(pitch)
    
    local x1 = x * cy - z * sy
    local z1 = x * sy + z * cy
    local y1 = y * cp - z1 * sp
    local z2 = y * sp + z1 * cp
    
    return x1, y1, z2
end

function lib3d.getForwardVector(yaw, pitch)
    local cp = math.cos(pitch)
    local sp = math.sin(pitch)
    local cy = math.cos(yaw)
    local sy = math.sin(yaw)
    return sy * cp, -sp, cy * cp
end

function lib3d.getRightVector(yaw)
    local cy = math.cos(yaw)
    local sy = math.sin(yaw)
    return cy, 0, -sy
end

local matrixCache = {}
local cacheKey = ""

function lib3d.getMVPMatrix(x, y, z, yaw, pitch, fov, aspect, znear, zfar)
    local key = string.format("%.2f_%.2f_%.2f_%.4f_%.4f", x, y, z, yaw, pitch)
    if matrixCache.lastKey == key then
        return matrixCache.matrix
    end
    
    local cy, sy = math.cos(yaw), math.sin(yaw)
    local cp, sp = math.cos(pitch), math.sin(pitch)

    local v11, v12, v13 = cy, sp * sy, cp * sy
    local v21, v22, v23 = 0, cp, -sp
    local v31, v32, v33 = -sy, sp * cy, cp * cy

    local tx = -(x * v11 + y * v21 + z * v31)
    local ty = -(x * v12 + y * v22 + z * v32)
    local tz = -(x * v13 + y * v23 + z * v33)

    local f = 1 / math.tan(fov * 0.5)
    local invRange = 1 / (znear - zfar)
    local a = f / aspect
    local b = f
    local c = (zfar + znear) * invRange
    local d = (2 * zfar * znear) * invRange

    local matrix = {
        a * v11, a * v12, a * v13, 0,
        b * v21, b * v22, b * v23, 0,
        c * v11 - v31, c * v12 - v32, c * v13 - v33, -1,
        d * v11 - tx,  d * v12 - ty,  d * v13 - tz, 0
    }
    
    matrixCache.matrix = matrix
    matrixCache.lastKey = key
    
    return matrix
end

function lib3d.clearMatrixCache()
    matrixCache = {}
end


local tempPool = {
    vec3 = {},
    vec2 = {},
    mat4 = {},
}

local poolSizes = {
    vec3 = 100,
    vec2 = 100,
    mat4 = 10,
}

for i = 1, poolSizes.vec3 do
    tempPool.vec3[i] = {0, 0, 0}
end
for i = 1, poolSizes.vec2 do
    tempPool.vec2[i] = {0, 0}
end
for i = 1, poolSizes.mat4 do
    tempPool.mat4[i] = {}
end

local poolIndices = {vec3 = 1, vec2 = 1, mat4 = 1}

function lib3d.getTempVec3(x, y, z)
    local idx = poolIndices.vec3
    local v = tempPool.vec3[idx]
    if not v then
        v = {0, 0, 0}
        tempPool.vec3[idx] = v
    end
    v[1], v[2], v[3] = x or 0, y or 0, z or 0
    poolIndices.vec3 = idx % poolSizes.vec3 + 1
    return v
end

function lib3d.getTempVec2(x, y)
    local idx = poolIndices.vec2
    local v = tempPool.vec2[idx]
    if not v then
        v = {0, 0}
        tempPool.vec2[idx] = v
    end
    v[1], v[2] = x or 0, y or 0
    poolIndices.vec2 = idx % poolSizes.vec2 + 1
    return v
end

function lib3d.resetTempPool()
    poolIndices = {vec3 = 1, vec2 = 1, mat4 = 1}
end


function lib3d.computeFaceNormal(v1, v2, v3)
    local ux, uy, uz = v2[1]-v1[1], v2[2]-v1[2], v2[3]-v1[3]
    local vx, vy, vz = v3[1]-v1[1], v3[2]-v1[2], v3[3]-v1[3]
    local nx, ny, nz = uy*vz - uz*vy, uz*vx - ux*vz, ux*vy - uy*vx
    return lib3d.vec3Normalize(nx, ny, nz)
end

function lib3d.computeTriangleArea(v1, v2, v3)
    local ux, uy, uz = v2[1]-v1[1], v2[2]-v1[2], v2[3]-v1[3]
    local vx, vy, vz = v3[1]-v1[1], v3[2]-v1[2], v3[3]-v1[3]
    local cx, cy, cz = uy*vz - uz*vy, uz*vx - ux*vz, ux*vy - uy*vx
    return 0.5 * math.sqrt(cx*cx + cy*cy + cz*cz)
end

function lib3d.pointInAABB(px, py, pz, minX, minY, minZ, maxX, maxY, maxZ)
    return px >= minX and px <= maxX and py >= minY and py <= maxY and pz >= minZ and pz <= maxZ
end

function lib3d.pointInSphere(px, py, pz, cx, cy, cz, radiusSq)
    local dx, dy, dz = px-cx, py-cy, pz-cz
    return dx*dx + dy*dy + dz*dz <= radiusSq
end

function lib3d.rayAABBIntersect(rayX, rayY, rayZ, dirX, dirY, dirZ, minX, minY, minZ, maxX, maxY, maxZ, maxDist)
    local tmin, tmax = 0, maxDist or 1000
    
    -- x slab
    if dirX ~= 0 then
        local tx1, tx2 = (minX - rayX) / dirX, (maxX - rayX) / dirX
        if tx1 > tx2 then tx1, tx2 = tx2, tx1 end
        tmin = math.max(tmin, tx1)
        tmax = math.min(tmax, tx2)
        if tmin > tmax then return false end
    end
    
    -- y slab
    if dirY ~= 0 then
        local ty1, ty2 = (minY - rayY) / dirY, (maxY - rayY) / dirY
        if ty1 > ty2 then ty1, ty2 = ty2, ty1 end
        tmin = math.max(tmin, ty1)
        tmax = math.min(tmax, ty2)
        if tmin > tmax then return false end
    end
    
    -- z slab
    if dirZ ~= 0 then
        local tz1, tz2 = (minZ - rayZ) / dirZ, (maxZ - rayZ) / dirZ
        if tz1 > tz2 then tz1, tz2 = tz2, tz1 end
        tmin = math.max(tmin, tz1)
        tmax = math.min(tmax, tz2)
        if tmin > tmax then return false end
    end
    
    return tmin >= 0, tmin, tmax
end

function lib3d.bilinearInterpolate(v00, v10, v01, v11, fx, fy)
    local v0 = v00 * (1-fx) + v10 * fx
    local v1 = v01 * (1-fx) + v11 * fx
    return v0 * (1-fy) + v1 * fy
end

function lib3d.trilinearInterpolate(v000, v100, v010, v110, v001, v101, v011, v111, fx, fy, fz)
    local v00 = v000 * (1-fx) + v100 * fx
    local v01 = v010 * (1-fx) + v110 * fx
    local v10 = v001 * (1-fx) + v101 * fx
    local v11 = v011 * (1-fx) + v111 * fx
    local v0 = v00 * (1-fy) + v01 * fy
    local v1 = v10 * (1-fy) + v11 * fy
    return v0 * (1-fz) + v1 * fz
end

local spatialHash = {}

function lib3d.setSpatialHash(items, hashSize)
    spatialHash = {}
    hashSize = hashSize or 16
    for i = 1, #items do
        local item = items[i]
        local hx = math.floor(item.x / hashSize)
        local hz = math.floor(item.z / hashSize)
        local key = hx .. "_" .. hz
        if not spatialHash[key] then
            spatialHash[key] = {}
        end
        table.insert(spatialHash[key], item)
    end
end

function lib3d.getSpatialNearby(x, z, hashSize, range)
    hashSize = hashSize or 16
    range = range or 1
    local hx = math.floor(x / hashSize)
    local hz = math.floor(z / hashSize)
    local result = {}
    
    for dx = -range, range do
        for dz = -range, range do
            local key = (hx + dx) .. "_" .. (hz + dz)
            if spatialHash[key] then
                for i = 1, #spatialHash[key] do
                    table.insert(result, spatialHash[key][i])
                end
            end
        end
    end
    
    return result
end

function lib3d.clearSpatialHash()
    spatialHash = {}
end

return lib3d
