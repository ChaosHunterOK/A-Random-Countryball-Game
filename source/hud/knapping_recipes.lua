local knapping_recipes = {}

--[[
format:
{
    input = {
        --  1  2  3  4  5
        --  6  7  8  9  10
        --  11 12 13 14 15
        --  16 17 18 19 20
        --  21 22 23 24 25
    },
    output = "item_name",
}
]]

knapping_recipes.recipes = {
        {
        input = {
            nil,  nil, nil,   nil, nil,
            "stone","stone", "stone","stone", nil,
            "stone","stone", "stone", "stone", "stone",
            nil,   nil,     nil,     nil,    nil,
            nil,   nil,     nil,     nil,    nil,
        },
        output = "stone_hoe_head"
    },
    --[[{
        input = {
            nil,   "stone", nil,   "stone", nil,
            nil,   "stone", "stone","stone", nil,
            nil,   nil,     "stone", nil,    nil,
            nil,   nil,     nil,     nil,    nil,
            nil,   nil,     nil,     nil,    nil,
        },
        output = "sharp_stone"
    },
    {
        input = {
            "stone", "stone", "stone", nil,     nil,
            nil,      "stone", nil,    nil,     nil,
            nil,      "stone", nil,    nil,     nil,
            nil,      "stone", nil,    nil,     nil,
            "stone",  "stone", "stone", nil,    nil,
        },
        output = "stone_blade"
    },
    {
        input = {
            nil,     "stone", "stone", "stone", nil,
            nil,     "stone", nil,     nil,     nil,
            nil,     "stone", "stone", nil,     nil,
            nil,     nil,     "stone", nil,     nil,
            nil,     nil,     nil,     nil,     nil,
        },
        output = "stone_axe_head"
    },]]
}

return knapping_recipes