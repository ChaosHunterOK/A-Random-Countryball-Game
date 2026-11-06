local sin, floor = math.sin, math.floor

local proj = (...) and (...):match("^(.*%.)[^%.]*$") or "source.projectile.map.generation."
local Verts = require("source.projectile.verts")
local utils = require("source.utils.utils")
local Water = require(proj .. "water")

local Underwater = {}
Underwater.enabled = true

Underwater.depths = {small = 0.75, medium = 1.5, deep = 3.0}
Underwater.defaultDepth = 1.0

Underwater.bedMaterials = {small = "sandWet", medium = "gravel", deep = "stone"}
Underwater.fallbackMaterial = "dirt"

local TINT_FULL_DEPTH = 3.0
local TINT_NEAR = {0.85, 0.95, 1.00}
local TINT_FAR  = {0.30, 0.52, 0.70}
local SHIMMER = 0.06
local MIN_STEP = 0.05

local pushQuad, isFull = Verts.pushQuad, Verts.isFull
local QUAD = Verts.QUAD
local NEIGHBORS = Verts.NEIGHBORS
local NEIGHBOR_CORNERS = {
    {4, 3},
    {1, 4},
    {2, 1},
    {3, 2},
}

function Underwater.isWaterTile(tile)
    return tile ~= nil and Water.getKind(tile.texture) ~= nil
end

function Underwater.getSurfaceHeight(tile)
    return (tile[1][2] + tile[2][2] + tile[3][2] + tile[4][2]) * 0.25
end

function Underwater.getDepth(tile)
    return tile.depth
        or Underwater.depths[Water.getKind(tile.texture)]
        or Underwater.defaultDepth
end

function Underwater.getBedHeight(tile)
    return Underwater.getSurfaceHeight(tile) - Underwater.getDepth(tile)
end

function Underwater.tint(depthBelowSurface, tr, tg, tb)
    local t = depthBelowSurface / TINT_FULL_DEPTH
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return tr * (TINT_NEAR[1] + (TINT_FAR[1] - TINT_NEAR[1]) * t),
           tg * (TINT_NEAR[2] + (TINT_FAR[2] - TINT_NEAR[2]) * t),
           tb * (TINT_NEAR[3] + (TINT_FAR[3] - TINT_NEAR[3]) * t)
end

local function bedTexture(tile, materials)
    local name = tile.bed or Underwater.bedMaterials[Water.getKind(tile.texture)]
    return (name and materials[name])
        or materials[Underwater.fallbackMaterial]
        or tile.texture
end

function Underwater.emit(tile, ctx, dx, dy, dz)
    local camera = ctx.camera
    local c1, c2, c3, c4 = tile[1], tile[2], tile[3], tile[4]

    local surfaceY = Underwater.getSurfaceHeight(tile)
    local depth = Underwater.getDepth(tile)
    local tex = bedTexture(tile, ctx.materials)
    local shimmer = 1 - SHIMMER * (0.5 + 0.5 * sin(ctx.time * 1.7 + (c1[1] + c1[3]) * 0.9))
    local r, g, b = Underwater.tint(depth, ctx.tr, ctx.tg, ctx.tb)

    utils.setQuadVerts(QUAD, 
        {c1[1], c1[2] - depth, c1[3]}, 
        {c2[1], c2[2] - depth, c2[3]}, 
        {c3[1], c3[2] - depth, c3[3]}, 
        {c4[1], c4[2] - depth, c4[3]}
    )

    local bdy = surfaceY - depth - ctx.camY
    pushQuad(camera, QUAD[1], QUAD[2], QUAD[3], QUAD[4],
        tex, "top", dx * dx + bdy * bdy + dz * dz,
        r * shimmer, g * shimmer, b * shimmer,
        1.0, false, 0, 0, 1)

    local tileGrid = ctx.tileGrid
    local gridX, gridZ = floor(c1[1]), floor(c1[3])
    for oi = 1, 4 do
        if isFull() then break end
        local off = NEIGHBORS[oi]
        local row = tileGrid[gridX + off.nx]
        local nb = row and row[gridZ + off.nz]

        if nb and Underwater.isWaterTile(nb) then
            local neighborCorners = NEIGHBOR_CORNERS[oi]
            local bedY1 = tile[off.i1][2] - depth
            local bedY2 = tile[off.i2][2] - depth
            local neighborDepth = Underwater.getDepth(nb)
            local neighborBedY1 = nb[neighborCorners[1]][2] - neighborDepth
            local neighborBedY2 = nb[neighborCorners[2]][2] - neighborDepth
            local h1 = bedY1 - neighborBedY1
            local h2 = bedY2 - neighborBedY2
            if h1 >= MIN_STEP or h2 >= MIN_STEP then
                local sideHeight = math.max(h1, h2)
                local s1, s2 = tile[off.i1], tile[off.i2]
                utils.setQuadVerts(QUAD, 
                    {s1[1], bedY1, s1[3]}, 
                    {s2[1], bedY2, s2[3]}, 
                    {s2[1], neighborBedY2, s2[3]}, 
                    {s1[1], neighborBedY1, s1[3]}
                )

                local wx, wy, wz = (s1[1] + s2[1]) * 0.5 - ctx.camX,
                                   (bedY1 + bedY2 + neighborBedY1 + neighborBedY2) * 0.25 - ctx.camY,
                                   (s1[3] + s2[3]) * 0.5 - ctx.camZ
                local wr, wg, wb = Underwater.tint(surfaceY - (bedY1 + bedY2 + neighborBedY1 + neighborBedY2) * 0.25,
                                                   ctx.tr, ctx.tg, ctx.tb)
                pushQuad(camera, QUAD[1], QUAD[2], QUAD[3], QUAD[4],
                    tex, "side", wx * wx + wy * wy + wz * wz,
                    wr, wg, wb,
                    1.0, false, 0, 0, sideHeight)
            end
        end
    end
end

return Underwater