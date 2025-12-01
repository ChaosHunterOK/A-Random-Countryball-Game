local camera = {}
camera.x, camera.y, camera.z = 8, 5, -12
camera.yaw, camera.pitch = 0, -0.3
camera.zoom = 1.6
camera.sensitivity = 0.002
camera.fov = 70
camera.aspect = 1
camera.smoothness = 5.0
camera.hw, camera.hh = 1000, 525
camera.fovRad = 0
camera.fovHalfTan = 0

camera._forward = {x=0, y=0, z=0}
camera._right = {x=0, y=0, z=0}

local sin, cos, tan, rad = math.sin, math.cos, math.tan, math.rad
local clamp = require("source.utils").clamp

function camera:updateProjectionConstants(w, h)
    w = w or love.graphics.getWidth()
    h = h or love.graphics.getHeight()
    
    self.hw, self.hh = w * 0.5, h * 0.5
    self.aspect = w / h
    self.fovRad = rad(self.fov) / self.zoom
    self.fovHalfTan = tan(self.fovRad * 0.5)
    self._f = 1 / self.fovHalfTan
end

function camera:rotate(dx, dy)
    local s = self.sensitivity
    self.yaw = self.yaw - dx * s
    self.pitch = clamp(self.pitch - dy * s, -1.56, 1.56)
end

function camera:getForward()
    local cp = cos(self.pitch)
    local sp = sin(self.pitch)
    local cy = cos(self.yaw)
    local sy = sin(self.yaw)

    local f = self._forward
    f.x = sy * cp
    f.y = -sp
    f.z = cy * cp
    return f
end

function camera:getRight()
    local r = self._right
    local yaw90 = self.yaw - 1.57079632679
    r.x = sin(yaw90)
    r.y = 0
    r.z = cos(yaw90)
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

    if z2 <= 0.01 then return nil end

    local inv = 1 / (z2 * self.fovHalfTan)
    return (x1 * inv / self.aspect) * self.hw + self.hw, (-y1 * inv) * self.hh + self.hh, z2
end

function camera:isVisible(x, y, z, radius, renderDistanceSq)
    local dx, dz = x - self.x, z - self.z
    return (dx*dx + dz*dz) <= renderDistanceSq
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