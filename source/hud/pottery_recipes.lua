local recipe = {}
recipe.recipes = {
    {
        name = "Clay Bowl",
        output = "clay_bowl",
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
        output = "clay_brick",
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
        output = "clay_plate",
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
        output = "clay_cup",
        input = {
            nil, nil, true, nil, nil,
            true, nil, nil, true, nil,
            true, nil, nil, true, nil,
            true, nil, nil, true, nil,
            nil, true, true, nil, nil
        }
    },
}

return recipe
