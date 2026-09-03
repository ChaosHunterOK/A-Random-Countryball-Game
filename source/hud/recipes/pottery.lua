local recipe = {}
recipe.recipes = {
    {
        name = "Clay Bowl",
        output = "clay_bowl_unfired",
        input = {
            nil,  nil, nil, nil, nil,
            nil,  nil, nil, nil, nil,
            true, nil, nil, nil, true,
            true, nil, nil, nil, true,
            nil, true, true, true, nil
        }
    },
    {
        name = "Clay Brick",
        output = "clay_brick_unfired",
        input = {
            nil, nil, nil, nil, nil,
            true, true, true, true, true,
            true, true, true, true, true,
            true, true, true, true, true,
            nil, nil, nil, nil, nil
        }
    },
    {
        name = "Clay Plate",
        output = "clay_plate_unfired",
        input = {
            nil, nil, nil, nil, nil,
            nil, nil, nil, nil, nil,
            true, true, true, true, true,
            nil, true, true, true, nil,
            nil, nil, nil, nil, nil
        }
    },
    {
        name = "Clay Cup",
        output = "clay_cup_unfired",
        input = {
            nil, nil, true, nil, nil,
            true, nil, nil, true, nil,
            true, nil, nil, true, nil,
            true, nil, nil, true, nil,
            nil, true, true, nil, nil
        }
    },
    {
        name = "Clay Pot",
        output = "clay_pot_unfired",
        input = {
            nil, true, true, true, nil,
            true, nil, nil, nil, true,
            true, nil, nil, nil, true,
            true, nil, nil, nil, true,
            nil, true, true, true, nil
        }
    },
    {
        name = "Clay Jar",
        output = "clay_jar_unfired",
        input = {
            nil, nil, true, nil, nil,
            nil, true, nil, true, nil,
            true, nil, nil, nil, true,
            true, nil, nil, nil, true,
            nil, true, true, true, nil
        }
    },
    {
        name = "Furnace Brick",
        output = "clay_furnace_brick_unfired",
        input = {
            true, true, true, true, true,
            true, nil, nil, nil, true,
            true, true, true, true, true,
            true, nil, nil, nil, true,
            true, true, true, true, true
        }
    },
}

return recipe
