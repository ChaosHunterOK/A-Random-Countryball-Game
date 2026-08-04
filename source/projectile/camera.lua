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

local sin, cos, tan, rad = math.sin, math.cos, math.tan, math.rad
local clamp = require("source.utils").clamp

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
    self.lookX = math.sin(self.yaw)
    self.lookZ = math.cos(self.yaw)
end

function camera:isPointInFront(x, z)
    local dx, dz = x - self.x, z - self.z
    return (dx * self.lookX + dz * self.lookZ) > -1.0
end

function camera:getForward()
    if self._lastYaw ~= self.yaw or self._lastPitch ~= self.pitch then
        local cp = cos(self.pitch)
        local sp = sin(self.pitch)
        local cy = cos(self.yaw)
        local sy = sin(self.yaw)

        local f = self._forward
        f.x = sy * cp
        f.y = -sp
        f.z = cy * cp
        
        self._lastYaw = self.yaw
        self._lastPitch = self.pitch
    end
    return self._forward
end

function camera:getRight()
    local f = self:getForward()
    local worldUp = {x = 0, y = 1, z = 0}

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
    local cy, sy = cos(self.yaw), sin(self.yaw)
    local cp, sp = cos(self.pitch), sin(self.pitch)
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
    local cy, sy = cos(self.yaw), sin(self.yaw)
    local cp, sp = cos(self.pitch), sin(self.pitch)

    local dy = y1 * cp + z2 * sp
    local z1 = -y1 * sp + z2 * cp
    local dx = x1 * cy + z1 * sy
    local dz = -x1 * sy + z1 * cy

    local mag = math.sqrt(dx*dx + dy*dy + dz*dz)
    return dx / mag, dy / mag, dz / mag
end

function camera:getMVPMatrix()
    local cy, sy = cos(self.yaw), sin(self.yaw)
    local cp, sp = cos(self.pitch), sin(self.pitch)

    local v11, v12, v13 = cy, sp * sy, cp * sy
    local v21, v22, v23 = 0, cp, -sp
    local v31, v32, v33 = -sy, sp * cy, cp * cy

    local tx = -(self.x * v11 + self.y * v21 + self.z * v31)
    local ty = -(self.x * v12 + self.y * v22 + self.z * v32)
    local tz = -(self.x * v13 + self.y * v23 + self.z * v33)

    local f = 1 / tan(self.fovRad * 0.5)
    local znear, zfar = 0.1, 100
    local invRange = 1 / (znear - zfar)

    local a = f / self.aspect
    local b = f
    local c = (zfar + znear) * invRange
    local d = (2 * zfar * znear) * invRange

    return {
        a * v11, a * v12, a * v13, 0,
        b * v21, b * v22, b * v23, 0,
        c * v11 - v31, c * v12 - v32, c * v13 - v33, -1,
        d * v11 - tx,  d * v12 - ty,  d * v13 - tz, 0
    }
end

return camera