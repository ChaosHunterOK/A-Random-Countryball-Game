local Achievement = require("source.hud.achievement")

local Progression = {}
local requirementCheckers = {
    age_unlocked = function(state, value)
        return state.ages_unlocked[value] == true
    end,
    stat_gte = function(state, value)
        -- value = {stat = "copper_smelted", amount = 1}
        local current = state.statistics[value.stat] or 0
        return current >= value.amount
    end,
}

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
            {type = "stat_gte", value = {stat = "crafted_clay_items", amount = 5}}
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
            {type = "age_unlocked", value = "pottery_age"},
            {type = "stat_gte", value = {stat = "copper_smelted", amount = 1}}
        }
    }
}

local function newState()
    return {
        current_age = "stone_age",
        ages_unlocked = {stone_age = true},
        statistics = {
            items_crafted = {},
            items_smelted = {},
            pottery_items_made = 0,
            crafted_clay_items = 0,
            copper_smelted = 0,
            total_items_crafted = 0
        }
    }
end

local progressionState = newState()

function Progression:getCurrentAge()
    return self.ages[progressionState.current_age]
end

function Progression:getAgeState()
    return progressionState
end

function Progression:trackItemCrafted(itemType, itemTypes)
    local stats = progressionState.statistics
    stats.total_items_crafted = stats.total_items_crafted + 1
    stats.items_crafted[itemType] = (stats.items_crafted[itemType] or 0) + 1

    if itemType and itemType:find("clay_") then
        stats.pottery_items_made = stats.pottery_items_made + 1
        stats.crafted_clay_items = stats.crafted_clay_items + 1
    end

    self:checkAllAgeUnlocks()
end

function Progression:trackSmelted(itemType)
    local stats = progressionState.statistics
    stats.items_smelted[itemType] = (stats.items_smelted[itemType] or 0) + 1

    if itemType == "copper_ingot" then
        stats.copper_smelted = stats.copper_smelted + 1
    end

    self:checkAllAgeUnlocks()
end

function Progression:meetsRequirements(ageName)
    local age = self.ages[ageName]
    if not age then return false end

    for _, req in ipairs(age.requirements) do
        local checker = requirementCheckers[req.type]
        if not checker or not checker(progressionState, req.value) then
            return false
        end
    end

    return true
end

function Progression:checkAgeUnlock(ageName)
    if progressionState.ages_unlocked[ageName] then
        return false
    end

    if not self.ages[ageName] then return false end

    if self:meetsRequirements(ageName) then
        progressionState.ages_unlocked[ageName] = true
        progressionState.current_age = ageName
        Achievement:trigger(ageName)
        return true
    end

    return false
end

function Progression:checkAllAgeUnlocks()
    local orderedAges = {}
    for ageName in pairs(self.ages) do
        table.insert(orderedAges, ageName)
    end
    table.sort(orderedAges, function(a, b)
        return self.ages[a].priority < self.ages[b].priority
    end)

    local unlockedAny = false
    for _, ageName in ipairs(orderedAges) do
        if self:checkAgeUnlock(ageName) then
            unlockedAny = true
        end
    end
    return unlockedAny
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
    progressionState = savedState or newState()
    local defaults = newState()
    progressionState.current_age = progressionState.current_age or defaults.current_age
    progressionState.ages_unlocked = progressionState.ages_unlocked or defaults.ages_unlocked
    progressionState.statistics = progressionState.statistics or defaults.statistics
    for key, value in pairs(defaults.statistics) do
        if progressionState.statistics[key] == nil then
            progressionState.statistics[key] = value
        end
    end
end

function Progression:resetState()
    progressionState = newState()
end

return Progression
