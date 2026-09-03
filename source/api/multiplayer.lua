local MultiplayerAPI = {}

local config = {}

function MultiplayerAPI.init(cfg)
    config = cfg or {}
    config.MultiplayerMenu.onReceive = function(data)
        MultiplayerAPI.onNetworkData(data)
    end
    
    config.MultiplayerMenu.onDisconnected = function()
        config.countryball.clearRemotePlayers()
    end
end

function MultiplayerAPI.sendTileBreak(tileX, tileZ, isAir, matName, height)
    if config.MultiplayerMenu and config.MultiplayerMenu:isActive() then
        config.MultiplayerMenu:send({
            sys = "tile_break", 
            x = tileX, 
            z = tileZ,
            air = isAir and 1 or 0,
            mat = matName or "",
            h = height,
        })
    end
end

function MultiplayerAPI.sendPlacementBreak(x, y, z)
    if config.MultiplayerMenu and config.MultiplayerMenu:isActive() then
        config.MultiplayerMenu:send({
            sys = "block_break",
            x = x,
            y = y,
            z = z
        })
    end
end

function MultiplayerAPI.sendPlacementPlace(x, y, z, matType)
    if config.MultiplayerMenu and config.MultiplayerMenu:isActive() then
        config.MultiplayerMenu:send({
            sys = "block_place",
            x = x,
            y = y,
            z = z,
            mat = matType
        })
    end
end

function MultiplayerAPI.sendBlockBreak(x, y, z)
    return MultiplayerAPI.sendPlacementBreak(x, y, z)
end

function MultiplayerAPI.sendBlockPlace(x, y, z, matType)
    return MultiplayerAPI.sendPlacementPlace(x, y, z, matType)
end

function MultiplayerAPI.sendPropPlant(x, z)
    if config.MultiplayerMenu and config.MultiplayerMenu:isActive() then
        config.MultiplayerMenu:send({
            sys = "prop_plant", 
            x = x, 
            z = z
        })
    end
end

function MultiplayerAPI.applyNetworkTileBreak(data)
    local col = config.Map.tileGrid[data.x]
    if not col then return end
    local tile = col[data.z]
    if not tile then return end

    tile.height = data.h
    for i = 1, 4 do
        tile[i][2] = data.h
    end

    if data.air == 1 then
        tile.isAir = true
        tile.texture = nil
        tile.textureName = nil
        tile.subsurface = nil
    else
        tile.isAir = false
        local matName = data.mat
        if matName and matName ~= "" and config.materials and config.materials[matName] then
            tile.texture = config.materials[matName]
            tile.textureName = matName
        end
    end
    tile.showSide = true
    if config.updateTileMeshes then
        config.updateTileMeshes(true)
    end
end

function MultiplayerAPI.removePlacementAt(x, y, z)
    local placements = config.Placements or config.Blocks
    if not placements or not placements.placed then return end
    for idx = #placements.placed, 1, -1 do
        local b = placements.placed[idx]
        if b.x == x and b.y == y and b.z == z then
            table.remove(placements.placed, idx)
            break
        end
    end
end

function MultiplayerAPI.removeBlockAt(x, y, z)
    return MultiplayerAPI.removePlacementAt(x, y, z)
end

function MultiplayerAPI.onNetworkData(data)
    if data.sys == "tile_break" then
        MultiplayerAPI.applyNetworkTileBreak(data)
    elseif data.sys == "block_place" then
        local placements = config.Placements or config.Blocks
        if placements then
            placements.place(data.x, data.y, data.z, data.mat)
        end
    elseif data.sys == "block_break" then
        MultiplayerAPI.removePlacementAt(data.x, data.y, data.z)
    elseif data.sys == "prop_hit" then
        if config.Props then
            config.Props.applyNetworkHit(data.id, data.health, data.cut == 1)
        end
    elseif data.sys == "prop_remove" then
        if config.Props then
            config.Props.applyNetworkRemove(data.id)
        end
    elseif data.sys == "prop_plant" then
        if config.Props and config.Map then
            local tile = config.Map.getTileAt(data.x, data.z)
            if tile then config.Props.plantAppleSeed(tile, data.x, data.z) end
        end
    else
        if config.countryball then
            config.countryball.onNetworkData(data)
        end
    end
end

function MultiplayerAPI.startClientGame()
    if not config.MultiplayerMenu then return end
    config.MultiplayerMenu.shouldStartGame = nil

    local seed = config.MultiplayerMenu.receivedSeed or os.time()
    config.Map.mapSeed = seed

    if config.regenerateMap then
        config.regenerateMap(config.bw, config.bh, seed)
    end

    if config.Placements or config.Blocks then
        local placements = config.Placements or config.Blocks
        placements.placed = {}
    end
    if config.Props then
        config.Props.clearProps()
        config.Props.spawnProps(550, config.bw, config.bh, config.Map.getTileAt)
    end

    local sx, sz = math.floor(config.bw / 2), math.floor(config.bh / 2)

    if config.countryball then
        config.countryball.x = sx
        config.countryball.z = sz
        config.countryball.y = config.getSafeSpawnY(sx, sz)
        config.countryball.health = config.countryball.maxHealth
        config.countryball.hunger = config.countryball.maxHunger
    end

    if config.setGamestate then
        config.setGamestate("game")
    end
end

function MultiplayerAPI.startHostGame()
    if not config.MultiplayerMenu then return end
    config.MultiplayerMenu.shouldStartGame = nil
    
    if config.refreshWorldList then
        config.refreshWorldList()
    end
    
    local mpWorldName = "MP_Host_World"
    local worldExists = false
    if config.worldList then
        for _, name in ipairs(config.worldList) do
            if name == mpWorldName then worldExists = true break end
        end
    end

    if worldExists then
        if config.loadWorld then
            config.loadWorld(mpWorldName)
        end
    else
        if config.createNewWorld then
            config.createNewWorld(mpWorldName)
        end
    end
    
    if config.MultiplayerMenu then
        config.MultiplayerMenu.mapSeed = config.Map.mapSeed
    end
end

return MultiplayerAPI
