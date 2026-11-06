local Cave = {}

function Cave.isCaveTile(tile)
    return (tile.isAir and tile.cave) and true or false
end

function Cave.getFloorHeight(tile)
    return tile.cave.floorHeight
end

function Cave.beginFrame(ctx)
end

function Cave.emit(tile, ctx)
end

return Cave
