local camera = {
    x = 8, y = 5, z = -12,
    yaw = 0, pitch = 0.5,
    zoom = 1.6, smoothness = 5.0,
    freeLook = false, sensitivity = 1.0
}

local sqrt, sin, cos = math.sqrt, math.sin, math.cos

function camera.update(dt, player)
    local kb = love.keyboard
    if kb.isDown("a") then camera.yaw = camera.yaw + dt * 1.5 end
    if kb.isDown("d") then camera.yaw = camera.yaw - dt * 1.5 end
    if kb.isDown("w") then camera.pitch = camera.pitch + dt * 1.2 end
    if kb.isDown("s") then camera.pitch = camera.pitch - dt * 1.2 end
    camera.pitch = math.max(-1.2, math.min(1.2, camera.pitch))
    local followDist = 12 / camera.zoom
    local followHeight = 5 / camera.zoom
    local targetX = player.x - sin(camera.yaw) * followDist
    local targetZ = player.z - cos(camera.yaw) * followDist
    local targetY = player.y + followHeight
    local smooth = math.min(camera.smoothness * dt, 1)
    camera.x = camera.x + (targetX - camera.x) * smooth
    camera.y = camera.y + (targetY - camera.y) * smooth
    camera.z = camera.z + (targetZ - camera.z) * smooth
end

function camera.project(x, y, z, fov, aspect, hw, hh)
    local dx, dy, dz = x - camera.x, y - camera.y, z - camera.z
    local cy, sy = cos(-camera.yaw), sin(-camera.yaw)
    local cp, sp = cos(-camera.pitch), sin(-camera.pitch)
    local x1 = dx*cy - dz*sy
    local z1 = dx*sy + dz*cy
    local y1 = dy*cp - z1*sp
    local z2 = dy*sp + z1*cp
    if z2 <= 0.1 then return nil end
    local invZ = 1 / (z2 * math.tan(fov/2))
    return x1*invZ/aspect*hw + hw, -y1*invZ*hh + hh, z2
end

return camera