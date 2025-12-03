local love = require("love")
local glrequire = require("ffi/opengl")
glrequire.init()

local sin, cos, tan, rad, sqrt, floor, max, min =
    math.sin, math.cos, math.tan, math.rad, math.sqrt, math.floor, math.max, math.min

local lg = love.graphics
local M = {}

local base_width, base_height = 1000, 525
local hw, hh = base_width * 0.5, base_height * 0.5
local fovRad, fovHalfTan, aspect

local camera_3d = {
    x = 8, y = 5, z = -12,
    yaw = 0.0, pitch = 0.5,
    zoom = 1.6, sensitivity = 1.2,
    smoothness = 5.0, freeLook = false
}

local preloadedTiles = {}

local function updateProjectionConstants()
    local w, h = base_width, base_height
    hw, hh = w * 0.5, h * 0.5
    aspect = w / h
    fovRad = rad(70) / (camera_3d and camera_3d.zoom or 1)
    fovHalfTan = tan(fovRad * 0.5)
end

local function project3D(x, y, z, cy, sy, cp, sp)
    local dx, dy, dz = x - camera_3d.x, y - camera_3d.y, z - camera_3d.z
    local x1 = dx * cy - dz * sy
    local z1 = dx * sy + dz * cy
    local y1 = dy * cp - z1 * sp
    local z2 = dy * sp + z1 * cp
    if z2 <= 0.1 then return nil end
    local invZ = 1 / (z2 * fovHalfTan)
    return x1 * invZ / aspect * hw + hw, -y1 * invZ * hh + hh, z2
end

local function updateTileMeshes(baseplateTiles, materials, renderDistanceSq)
    updateProjectionConstants()
    local yaw, pitch = -camera_3d.yaw, -camera_3d.pitch
    local cy, sy = cos(yaw), sin(yaw)
    local cp, sp = cos(pitch), sin(pitch)
    local n = 0
    for t = 1, #baseplateTiles do
        local tile = baseplateTiles[t]
        local poly = {}
        local visible = true
        for i = 1, 4 do
            local v = tile[i]
            local sx, sy2, z2 = project3D(v[1], v[2], v[3], cy, sy, cp, sp)
            if not sx then
                visible = false
                break
            end
            poly[i * 2 - 1], poly[i * 2] = sx, sy2
        end

        if visible then
            local v1, v3 = tile[1], tile[3]
            local cx = (v1[1] + v3[1]) * 0.5 - camera_3d.x
            local cz = (v1[3] + v3[3]) * 0.5 - camera_3d.z
            local distSq = cx * cx + cz * cz
            if distSq <= renderDistanceSq then
                n = n + 1
                preloadedTiles[n] = {
                    verts = poly,
                    dist = distSq,
                    texture = tile.texture,
                    mesh = nil
                }
            end
        end
    end

    for i = n + 1, #preloadedTiles do preloadedTiles[i] = nil end
    table.sort(preloadedTiles, function(a, b) return a.dist > b.dist end)
end

local function _ensureMeshForTile(t, materials)
    if t.mesh or not t.verts or #t.verts < 8 then return end
    local verts = {
        {t.verts[1], t.verts[2], 0, 0},
        {t.verts[3], t.verts[4], 1, 0},
        {t.verts[5], t.verts[6], 1, 1},
        {t.verts[7], t.verts[8], 0, 1},
    }
    t.mesh = lg.newMesh(verts, "fan", "static")
    t.mesh:setTexture(t.texture or materials.grassNormal)
end

local function drawBaseplate(materials)
    for i = 1, #preloadedTiles do
        local t = preloadedTiles[i]
        if t and t.verts and #t.verts >= 8 then
            _ensureMeshForTile(t, materials)
            if t.mesh then lg.draw(t.mesh) end
        end
    end
end

local function stencilBaseplate(objX, objZ, renderDistanceSq, materials)
    local objDistSq = (objX - camera_3d.x)^2 + (objZ - camera_3d.z)^2
    for i = 1, #preloadedTiles do
        local t = preloadedTiles[i]
        if not t then break end
        if t.dist <= renderDistanceSq then
            _ensureMeshForTile(t, materials)
            if t.dist <= objDistSq + 1 and t.mesh then
                lg.draw(t.mesh)
            end
        end
    end
end

local function drawWithStencil(objX, objY, objZ, img, flip, render_chunk_radius, chunk_size, renderDistanceSq, materials)
    local function worldToChunkCoord(v) return floor(v / chunk_size) end
    local objChunkX = worldToChunkCoord(objX)
    local objChunkZ = worldToChunkCoord(objZ)
    local camChunkX = worldToChunkCoord(camera_3d.x)
    local camChunkZ = worldToChunkCoord(camera_3d.z)
    local dxChunks = objChunkX - camChunkX
    local dzChunks = objChunkZ - camChunkZ
    if dxChunks * dxChunks + dzChunks * dzChunks > render_chunk_radius * render_chunk_radius then return end

    local yaw, pitch = -camera_3d.yaw, -camera_3d.pitch
    local cy, sy = cos(yaw), sin(yaw)
    local cp, sp = cos(pitch), sin(pitch)
    local sx, sy2, z2 = project3D(objX, objY, objZ, cy, sy, cp, sp)
    if not sx or z2 <= 0 then return end

    local fadeMargin = 5
    if sx < -fadeMargin or sx > base_width + fadeMargin or sy2 < -fadeMargin or sy2 > base_height + fadeMargin then return end

    local alpha = 1
    if sx < fadeMargin then alpha = max(0, (sx + fadeMargin) / fadeMargin) end
    if sx > base_width - fadeMargin then alpha = max(0, (base_width + fadeMargin - sx) / fadeMargin) end
    if sy2 < fadeMargin then alpha = max(alpha, (sy2 + fadeMargin) / fadeMargin) end
    if sy2 > base_height - fadeMargin then alpha = max(alpha, (base_height + fadeMargin - sy2) / fadeMargin) end
    if alpha <= 0 then return end

    local scale = (1 / z2) * 6
    local w, h = img:getWidth(), img:getHeight()

    lg.stencil(function()
        stencilBaseplate(objX, objZ, renderDistanceSq, materials)
    end, "replace", 1)
    lg.setStencilTest("equal", -1)
    lg.setColor(1, 1, 1, alpha)
    lg.draw(img, sx, sy2, 0, (flip and -scale or scale), scale, w / 2, h)
    lg.setColor(1, 1, 1, 1)
    lg.setStencilTest()
end

local function smth()
    for i = #preloadedTiles, 1, -1 do
        if not preloadedTiles[i] then table.remove(preloadedTiles, i) end
    end
end

local function cameraFollow(dt, target)
    local followDistance = 12 / camera_3d.zoom
    local followHeight = 5 / camera_3d.zoom
    local tx = target.x - sin(camera_3d.yaw) * followDistance
    local tz = target.z - cos(camera_3d.yaw) * followDistance
    local ty = target.y + followHeight
    local smooth = camera_3d.smoothness * dt
    camera_3d.x = camera_3d.x + (tx - camera_3d.x) * smooth
    camera_3d.y = camera_3d.y + (ty - camera_3d.y) * smooth
    camera_3d.z = camera_3d.z + (tz - camera_3d.z) * smooth

    if love.keyboard.isDown("a") then camera_3d.yaw = camera_3d.yaw + dt * 1.5 end
    if love.keyboard.isDown("d") then camera_3d.yaw = camera_3d.yaw - dt * 1.5 end
    if love.keyboard.isDown("w") then camera_3d.pitch = camera_3d.pitch + dt * 1.2 end
    if love.keyboard.isDown("s") then camera_3d.pitch = camera_3d.pitch - dt * 1.2 end
    if camera_3d.pitch < -1.2 then camera_3d.pitch = -1.2 end
    if camera_3d.pitch > 1.2 then camera_3d.pitch = 1.2 end
end

local function wheelmovedCamera(x, y)
    camera_3d.zoom = camera_3d.zoom - y * 0.1
    if camera_3d.zoom < 0.5 then camera_3d.zoom = 0.5 end
    if camera_3d.zoom > 2.5 then camera_3d.zoom = 2.5 end
end

local function mousemovedCamera(x, y, dx, dy)
    if camera_3d.freeLook then
        camera_3d.yaw = camera_3d.yaw - dx * 0.005 * camera_3d.sensitivity
        camera_3d.pitch = camera_3d.pitch - dy * 0.003 * camera_3d.sensitivity
        if camera_3d.pitch < -1.2 then camera_3d.pitch = -1.2 end
        if camera_3d.pitch > 1.2 then camera_3d.pitch = 1.2 end
    end
end

local function keypressedCamera(key)
    if key == "tab" then
        camera_3d.freeLook = not camera_3d.freeLook
        love.mouse.setRelativeMode(camera_3d.freeLook)
    end
end

M.camera = camera_3d
M.project3D = project3D
M.updateTileMeshes = updateTileMeshes
M.drawBaseplate = drawBaseplate
M.cameraFollow = cameraFollow
M.preloadedTiles = preloadedTiles
M.smth = smth
M.updateProjectionConstants = updateProjectionConstants
M.wheelmovedCamera = wheelmovedCamera
M.mousemovedCamera = mousemovedCamera
M.keypressedCamera = keypressedCamera
M.stencilBaseplate = stencilBaseplate
M.drawWithStencil = drawWithStencil

return M