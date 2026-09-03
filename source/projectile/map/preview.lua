local love = require("love")
local lg = love.graphics
local Preview = {}

local floor, abs = math.floor, math.abs
local leSize = 14
local worldPreviewCache = {}
local previewCamera

function Preview:configure(config)
	self.mapsave = config.mapsave
	self.camera = config.camera
	self.verts = config.verts
	self.materials = config.materials
end

function Preview:clearCache()
	for name, preview in pairs(worldPreviewCache) do
		if preview.canvas then preview.canvas:release() end
		worldPreviewCache[name] = nil
	end
end

function Preview:get(name)
	local cached = worldPreviewCache[name]
	if cached then return cached end
	self:clearCache()

	local loaded, tileGrid = self.mapsave.load(self.materials, nil, name)
	if not loaded then return nil end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, tile in ipairs(loaded) do
		local x = tile.x or tile[1][1]
		local z = tile.z or tile[1][3]
		minX, maxX = math.min(minX, x), math.max(maxX, x)
		minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
	end

	local centerX, centerZ = (minX + maxX) * 0.5, (minZ + maxZ) * 0.5
	local selected = {}
	for _, tile in ipairs(loaded) do
		local x = tile.x or tile[1][1]
		local z = tile.z or tile[1][3]
		if abs(x - centerX) <= leSize * 0.5 and abs(z - centerZ) <= leSize * 0.5 then
			selected[#selected + 1] = tile
		end
	end

	local centerY = 0
	for _, tile in ipairs(selected) do
		centerY = centerY + (tile[1][2] + tile[2][2] + tile[3][2] + tile[4][2]) * 0.25
	end
	centerY = (#selected > 0) and (centerY / #selected) or 0
	local preview = {tiles = selected, tileGrid = tileGrid, centerX = centerX, centerZ = centerZ, centerY = centerY}
	worldPreviewCache[name] = preview
	return preview
end

function Preview:draw(name, x, y, width, height)
	local preview = self:get(name)
	if not preview or #preview.tiles == 0 then return end
	width, height = floor(width), floor(height)
	if not preview.canvas or preview.canvas:getWidth() ~= width or preview.canvas:getHeight() ~= height then
		if preview.canvas then preview.canvas:release() end
		preview.canvas = lg.newCanvas(width, height)
		preview.canvas:setFilter("nearest", "nearest")

		previewCamera = previewCamera or setmetatable({}, {__index = self.camera})
		previewCamera.screenW, previewCamera.screenH = width, height
		local yaw, pitch, distance = math.rad(25), math.rad(-45), 24
		previewCamera.yaw, previewCamera.pitch, previewCamera.zoom = yaw, pitch, 1.6
		previewCamera.x = preview.centerX - math.sin(yaw) * math.cos(pitch) * distance
		previewCamera.y = preview.centerY - math.sin(pitch) * distance
		previewCamera.z = preview.centerZ - math.cos(yaw) * math.cos(pitch) * distance
		previewCamera:updateProjectionConstants(width, height)

		local quads = self.verts.generate(preview.tiles, previewCamera, 1000000, preview.tileGrid, self.materials)
		local transparent, transparentCount, terrainBatches, terrainBatchCount = self.verts.buildBatches(quads, self.materials.stone)
		lg.push("all")
		lg.setCanvas(preview.canvas)
		lg.setScissor(0, 0, width, height)
		lg.clear(0, 0, 0, 0)
		lg.setColor(1, 1, 1, 1)
		for i = 1, terrainBatchCount do self.verts.drawTerrainMesh(terrainBatches[i].mesh) end
		for i = 1, transparentCount do
			if transparent[i].mesh then lg.draw(transparent[i].mesh) end
		end
		lg.setCanvas()
		lg.pop()
	end
	lg.setColor(1, 1, 1, 1)
	lg.draw(preview.canvas, x, y)
end

return Preview