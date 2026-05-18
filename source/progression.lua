local Progression = {}

Progression.ages = {
    stone_age = {
        name = "Stone Age",
        description = "Basic stone tools and survival",
        priority = 1,
        unlocks = {
            items = {"stone_shovel", "stone_hoe", "stone_hammer", "stone_pickaxe", "stone_knife"},
            crafting = {"basic_crafting"}
        },
        requirements = {}
    },
    pottery_age = {
        name = "Pottery Age",
        description = "Discover ceramics and pottery",
        priority = 2,
        unlocks = {
            items = {"clay_bowl", "clay_pot", "clay_brick", "clay_furnace_brick"},
            crafting = {"pottery_crafting"}
        },
        requirements = {
            crafted_clay_items = 5
        }
    },
    copper_age = {
        name = "Copper Age",
        description = "Smelt copper ore for advanced tools",
        priority = 3,
        unlocks = {
            items = {"copper_ingot", "copper_shovel", "copper_hoe", "copper_hammer", "copper_pickaxe", "copper_knife", "copper_ore"},
            crafting = {"smelting"}
        },
        requirements = {
            pottery_age = true,
            smelted_copper = 1
        }
    }
}

local progressionState = {
    current_age = "stone_age",
    ages_unlocked = {stone_age = true},
    statistics = {
        items_crafted = {},
        items_smelted = {},
        pottery_items_made = 0,
        copper_smelted = 0,
        total_items_crafted = 0
    }
}

function Progression:getCurrentAge()
    return self.ages[progressionState.current_age]
end

function Progression:getAgeState()
    return progressionState
end

function Progression:trackItemCrafted(itemType, itemTypes)
    progressionState.statistics.total_items_crafted = progressionState.statistics.total_items_crafted + 1
    progressionState.statistics.items_crafted[itemType] = (progressionState.statistics.items_crafted[itemType] or 0) + 1
    
    -- Check for pottery age unlock
    if itemType and itemType:find("clay_") then
        progressionState.statistics.pottery_items_made = progressionState.statistics.pottery_items_made + 1
        self:checkAgeUnlock("pottery_age")
    end
end

function Progression:trackSmelted(itemType)
    progressionState.statistics.items_smelted[itemType] = (progressionState.statistics.items_smelted[itemType] or 0) + 1
    
    if itemType == "copper_ingot" then
        progressionState.statistics.copper_smelted = progressionState.statistics.copper_smelted + 1
        self:checkAgeUnlock("copper_age")
    end
end

function Progression:checkAgeUnlock(ageName)
    if progressionState.ages_unlocked[ageName] then
        return
    end
    
    local age = self.ages[ageName]
    if not age then return end
    local canUnlock = true
    for req, value in pairs(age.requirements) do
        if req == "pottery_age" and value == true then
            if not progressionState.ages_unlocked["pottery_age"] then
                canUnlock = false
                break
            end
        elseif req == "crafted_clay_items" then
            if progressionState.statistics.pottery_items_made < value then
                canUnlock = false
                break
            end
        elseif req == "smelted_copper" then
            if progressionState.statistics.copper_smelted < value then
                canUnlock = false
                break
            end
        end
    end
    
    if canUnlock then
        progressionState.ages_unlocked[ageName] = true
        progressionState.current_age = ageName
        return true
    end
    
    return false
end

function Progression:isAgeUnlocked(ageName)
    return progressionState.ages_unlocked[ageName] or false
end

function Progression:canCraftItem(itemType, itemTypes)
    if not itemTypes or not itemTypes[itemType] then
        return true
    end
    for ageName, ageData in pairs(self.ages) do
        if ageData.unlocks.items then
            for _, item in ipairs(ageData.unlocks.items) do
                if item == itemType then
                    return self:isAgeUnlocked(ageName)
                end
            end
        end
    end
    
    return true
end

function Progression:saveState()
    return progressionState
end

function Progression:loadState(savedState)
    progressionState = savedState
end

function Progression:resetState()
    progressionState = {
        current_age = "stone_age",
        ages_unlocked = {stone_age = true},
        statistics = {
            items_crafted = {},
            items_smelted = {},
            pottery_items_made = 0,
            copper_smelted = 0,
            total_items_crafted = 0
        }
    }
end

return Progression
