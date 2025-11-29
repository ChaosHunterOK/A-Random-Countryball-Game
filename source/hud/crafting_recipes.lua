local recipe = {}

recipe.recipes = {
    { 
        input = { "apple", nil, nil, nil },
        output = "paper"
    },
    {
        input = {"stone", nil, "stick", nil},
        output = "stone_tool"
    },
    {
        input = {"wood", "wood", nil, nil},
        output = "stick"
    },
    {
        input = {"bituminous_coal", "iron_raw", nil, nil},
        output = "anthracite_coal"
    },
}

return recipe