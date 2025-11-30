local recipe = {}

recipe.recipes = {
    --[[{ 
        input = { "apple", nil, nil, nil },
        output = "paper"
    },]] --will let this here
    {
        input = {"stone", nil, "stick", nil},
        output = "stone_tool"
    },
    {
        input = {"stone_shovel_head", nil, "stick", nil},
        output = "stone_shovel"
    },
    {
        input = {"stone_hoe_head", nil, "stick", nil},
        output = "stone_hoe"
    },
    {
        input = {"stone_hammer_head", nil, "stick", nil},
        output = "stone_hammer"
    },
}

return recipe