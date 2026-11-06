local camera = {}
camera.x, camera.y, camera.z = 10, 5, 10
camera.yaw, camera.pitch = 0, -0.3
camera.zoom = 1.6
camera.free = false
camera.speed = 10
camera.sensitivity = 0.002
camera.fov = 70
camera.aspect = 1
camera.smoothness = 5.0
camera.hw, camera.hh = 500, 262
camera.fovRad = 0
camera.fovHalfTan = 0
camera.lookX = 0
camera.lookZ = 0

camera._forward = {x=0, y=0, z=0}
camera._right = {x=0, y=0, z=0}
camera._cached = false
camera._lastYaw = -1
camera._lastPitch = -1
camera._cosYaw, camera._sinYaw = 1, 0
camera._cosPitch, camera._sinPitch = 1, 0

local sin, cos, tan, rad, atan, sqrt = math.sin, math.cos, math.tan, math.rad, math.atan, math.sqrt

camera._cullCosHalfFov = -1
local base_width, base_height = 1000, 525

function camera:updateProjectionConstants(w, h)
    w = w or self.screenW or base_width
    h = h or self.screenH or base_height
    self.screenW, self.screenH = w, h
    self.hw, self.hh = w * 0.5, h * 0.5
    self.aspect = w / h
    self.fovRad = math.rad(self.fov)
    self.fovHalfTan = math.tan(self.fovRad * 0.5) / self.zoom
    self._f = 1 / self.fovHalfTan
    self._fx = self._f / self.aspect
    self._fy = self._f
    self._cosYaw, self._sinYaw = cos(self.yaw), sin(self.yaw)
    self._cosPitch, self._sinPitch = cos(self.pitch), sin(self.pitch)
    self.lookX = math.sin(self.yaw)
    self.lookZ = math.cos(self.yaw)
    local halfFovV = self.fovRad * 0.5
    local halfFovH = atan(tan(halfFovV) * self.aspect / self.zoom)
    local padding = rad(15)
    self._cullCosHalfFov = cos(halfFovH + padding)
end

function camera:isPointInFront(x, z)
    local dx, dz = x - self.x, z - self.z
    return (dx * self.lookX + dz * self.lookZ) > -1.0
end

function camera:isInViewFrustum(x, z, radius)
    local dx, dz = x - self.x, z - self.z
    local distSq = dx * dx + dz * dz
    if distSq < 0.0001 then return true end

    local dist = sqrt(distSq)
    local cosAngle = (dx * self.lookX + dz * self.lookZ) / dist

    local threshold = self._cullCosHalfFov
    if radius and radius > 0 then
        threshold = threshold - (radius / dist)
    end

    return cosAngle > threshold
end

function camera:getForward()
    if self._lastYaw ~= self.yaw or self._lastPitch ~= self.pitch then
        local cp, sp = cos(self.pitch), sin(self.pitch)
        local cy, sy = cos(self.yaw), sin(self.yaw)

        local f = self._forward
        f.x = sy * cp
        f.y = -sp
        f.z = cy * cp
        self._cosYaw, self._sinYaw = cy, sy
        self._cosPitch, self._sinPitch = cp, sp
        
        self._lastYaw = self.yaw
        self._lastPitch = self.pitch
    end
    return self._forward
end

local worldUp = {x = 0, y = 1, z = 0}

function camera:getRight()
    local f = self:getForward()

    local r = self._right
    r.x = f.y * worldUp.z - f.z * worldUp.y
    r.y = f.z * worldUp.x - f.x * worldUp.z
    r.z = f.x * worldUp.y - f.y * worldUp.x

    local mag = math.sqrt(r.x*r.x + r.y*r.y + r.z*r.z)
    r.x, r.y, r.z = r.x/mag, r.y/mag, r.z/mag

    return r
end

function camera:project3D(x, y, z)
    local dx, dy, dz = x - self.x, y - self.y, z - self.z
    local cy, sy = self._cosYaw, self._sinYaw
    local cp, sp = self._cosPitch, self._sinPitch
    local x1 = dx * cy - dz * sy
    local z1 = dx * sy + dz * cy
    local y1 = dy * cp - z1 * sp
    local z2 = dy * sp + z1 * cp
    if z2 <= 0.001 then return nil end
    local inv = self._f / z2
    local screenX = (x1 * inv / self.aspect) * self.hw + self.hw
    local screenY = (-y1 * inv) * self.hh + self.hh
    return screenX, screenY, z2
end

function camera:getRay(mx, my, w, h)
    local nx = (mx / w - 0.5) * 2
    local ny = (0.5 - my / h) * 2
    local aspect = self.aspect
    local tanFOV = self.fovHalfTan
    local x1 = nx * aspect * tanFOV
    local y1 = ny * tanFOV
    local z2 = 1
    self:getForward()
    local cy, sy = self._cosYaw, self._sinYaw
    local cp, sp = self._cosPitch, self._sinPitch

    local dy = y1 * cp + z2 * sp
    local z1 = -y1 * sp + z2 * cp
    local dx = x1 * cy + z1 * sy
    local dz = -x1 * sy + z1 * cy

    local mag = math.sqrt(dx*dx + dy*dy + dz*dz)
    return dx / mag, dy / mag, dz / mag
end

local NEAR, FAR = 0.1, 100.0
local CLIP_A = (FAR + NEAR) / (FAR - NEAR)
local CLIP_B = (2 * FAR * NEAR) / (FAR - NEAR)

function camera:getViewProjectionMatrix()
    self:getForward()
    local cy, sy = self._cosYaw, self._sinYaw
    local cp, sp = self._cosPitch, self._sinPitch
    local fx, fy = self._fx, self._fy
    local camX, camY, camZ = self.x, self.y, self.z

    local Tx1 = -cy * camX + sy * camZ
    local Tz1 = -sy * camX - cy * camZ

    local rXx, rXy, rXz, rXw = fx * cy, 0, -fx * sy, fx * Tx1
    local rYx, rYy, rYz, rYw = fy * (-sp * sy), fy * cp, fy * (-sp * cy), fy * (-cp * camY - sp * Tz1)
    local wx, wy, wz, ww = cp * sy, sp, cp * cy, cp * Tz1 - sp * camY
    local rZx, rZy, rZz, rZw = CLIP_A * wx, CLIP_A * wy, CLIP_A * wz, CLIP_A * ww - CLIP_B

    return {
        rXx, rYx, rZx, wx,
        rXy, rYy, rZy, wy,
        rXz, rYz, rZz, wz,
        rXw, rYw, rZw, ww,
    }
end

return camera