--new library lol
local ffi = require "ffi"
local lib3d = {}

function lib3d.vec3Normalize(x, y, z)
    local len = math.sqrt(x*x + y*y + z*z)
    if len < 0.00001 then return 0, 0, 0 end
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
local cacheKey = ""
local matrixCache = { matrix = {}, lastParams = {} }

function lib3d.getMVPMatrix(camX, camY, camZ, yaw, pitch, fov, aspect, znear, zfar)
    local p = matrixCache.lastParams
    if p[1] == camX and p[2] == camY and p[3] == camZ and p[4] == yaw and p[5] == pitch and p[6] == fov then
        return matrixCache.matrix
    end
    local cosY, sinY = math.cos(yaw), math.sin(yaw)
    local cosP, sinP = math.cos(pitch), math.sin(pitch)
    local right = { cosY, 0, -sinY }
    local up = { sinY * sinP, cosP, cosY * sinP }
    local fwd = { sinY * cosP, -sinP, cosP * cosY }
    local tanHalfFov = math.tan(fov * 0.5)
    local m00 = 1 / (aspect * tanHalfFov)
    local m11 = 1 / tanHalfFov
    local m22 = -(zfar + znear) / (zfar - znear)
    local m23 = -1
    local m32 = -(2 * zfar * znear) / (zfar - znear)
    local m = {
        m00 * right[1], m11 * up[1], m22 * fwd[1] + m32 * 0, fwd[1],
        m00 * right[2], m11 * up[2], m22 * fwd[2] + m32 * 0, fwd[2],
        m00 * right[3], m11 * up[3], m22 * fwd[3] + m32 * 0, fwd[3],
        -lib3d.vec3Dot(right[1], right[2], right[3], camX, camY, camZ) * m00,
        -lib3d.vec3Dot(up[1], up[2], up[3], camX, camY, camZ) * m11,
        -lib3d.vec3Dot(fwd[1], fwd[2], fwd[3], camX, camY, camZ) * m22 + m32,
        -lib3d.vec3Dot(fwd[1], fwd[2], fwd[3], camX, camY, camZ)
    }

    matrixCache.matrix = m
    matrixCache.lastParams = {camX, camY, camZ, yaw, pitch, fov}
    return m
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
        local hx, hz = math.floor(item.x / hashSize), math.floor(item.z / hashSize)
        local key = hx .. "_" .. hz
        if not spatialHash[key] then spatialHash[key] = {} end
        table.insert(spatialHash[key], item)
    end
end

function lib3d.getSpatialNearby(x, z, hashSize, range)
    hashSize = hashSize or 16
    range = range or 1
    local hx = math.floor(x / hashSize)
    local hz = math.floor(z / hashSize)
    local result = {}
    local count = 0
    
    for dx = -range, range do
        local curX = (hx + dx) * 40000
        for dz = -range, range do
            local key = curX + (hz + dz)
            local cell = spatialHash[key]
            if cell then
                for i = 1, #cell do
                    count = count + 1
                    result[count] = cell[i]
                end
            end
        end
    end
    
    return result
end

function lib3d.clearSpatialHash()
    spatialHash = {}
end

function lib3d.worldToScreen(x, y, z, mvp, screenW, screenH)
    local cx = x * mvp[1] + y * mvp[5] + z * mvp[9] + mvp[13]
    local cy = x * mvp[2] + y * mvp[6] + z * mvp[10] + mvp[14]
    local cz = x * mvp[3] + y * mvp[7] + z * mvp[11] + mvp[15]
    local cw = x * mvp[4] + y * mvp[8] + z * mvp[12] + mvp[16]

    if cw < 0.1 then return nil end
    local ndcX = cx / cw
    local ndcY = cy / cw
    local screenX = (ndcX + 1) * 0.5 * screenW
    local screenY = (1 - ndcY) * 0.5 * screenH

    return screenX, screenY, cw
end

function lib3d.sortFacesByDepth(faces)
    table.sort(faces, function(a, b)
        return a.depth > b.depth
    end)
end

return lib3d
