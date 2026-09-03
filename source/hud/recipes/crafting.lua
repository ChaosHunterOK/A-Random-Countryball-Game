local recipe = {}

recipe.recipes = {
    --[[{ 
        input = { "apple", nil, nil, nil },
        output = "paper"
    },]] --will let this here
    {
        input = {"stone", nil, "stick", nil},
        output = {type = "stone_tool", count = 1}
    },
    {
        input = {"stick", nil, nil, "stick"},
        output = {type = "firestarter", count = 1}
    },
    {
        input = {"stone_shovel_head", nil, "stick", nil},
        output = {type = "stone_shovel", count = 1}
    },
    {
        input = {"stone_hoe_head", nil, "stick", nil},
        output = {type = "stone_hoe", count = 1}
    },
    {
        input = {"stone_hammer_head", nil, "stick", nil},
        output = {type = "stone_hammer", count = 1}
    },
    {
        input = {"stone_pick_head", nil, "stick", nil},
        output = {type = "stone_pickaxe", count = 1}
    },
    {
        input = {"stone_knife_head", nil, "stick", nil},
        output = {type = "stone_knife", count = 1}
    },
    {
        input = {"green_apple", nil, nil, nil},
        output = {type = "apple_seed", count = 4}
    },
    {
        input = {"apple", nil, nil, nil},
        output = {type = "apple_seed", count = 4}
    },
    {
        input = {"copper_shovel_head", nil, "stick", nil},
        output = {type = "copper_shovel", count = 1}
    },
    {
        input = {"copper_hoe_head", nil, "stick", nil},
        output = {type = "copper_hoe", count = 1}
    },
    {
        input = {"copper_hammer_head", nil, "stick", nil},
        output = {type = "copper_hammer", count = 1}
    },
    {
        input = {"copper_pick_head", nil, "stick", nil},
        output = {type = "copper_pickaxe", count = 1}
    },
    {
        input = {"copper_knife_head", nil, "stick", nil},
        output = {type = "copper_knife", count = 1}
    },
    {
        input = {"stone_axe_head", nil, "stick", nil},
        output = {type = "stone_axe", count = 1}
    },
    {
        input = {"copper_axe_head", nil, "stick", nil},
        output = {type = "copper_axe", count = 1}
    },
    {
        input = {"iron_axe_head", nil, "stick", nil},
        output = {type = "iron_axe", count = 1}
    },
    {
        input = {"oak", "oak", nil, nil},
        output = {type = "wood_planks", count = 4}
    },
    {
        input = {"stick", "stone", "stick", "stone"},
        output = {type = "fire_pit", count = 1}
    },
    {
        input = {"dirt", "clay", "dirt", nil},
        output = {type = "pit_kiln", count = 1}
    },
}

return recipe