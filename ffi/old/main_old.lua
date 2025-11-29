local love = require "love"

--load
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")

    love.window.setMode(1240, 760, {resizable=false})
    love.window.setTitle("A Random Countryball Game")
    icon = love.image.newImageData("icon/icon.png")
    love.window.setIcon(icon)

    menumusic = love.audio.newSource("music/menu.mp3", "stream")
    love.audio.play(menumusic)

    music = love.audio.newSource("music/music.mp3", "stream")

    rocks = {}

    flip = false
    scale = 1
    countryball = {
        x = 1500,
        y = 1500,
        health = 100,
        speed = 200,
        Idleimage1 = love.graphics.newImage("image/countryball/senegal/idle1.png"),
        Idleimage2 = love.graphics.newImage("image/countryball/senegal/idle2.png"),

        Walkimage1 = love.graphics.newImage("image/countryball/senegal/walk1.png"),
        Walkimage2 = love.graphics.newImage("image/countryball/senegal/walk2.png"),
        Walkimage3 = love.graphics.newImage("image/countryball/senegal/walk3.png"),
        Walkimage4 = love.graphics.newImage("image/countryball/senegal/walk4.png"),
        Walkimage5 = love.graphics.newImage("image/countryball/senegal/walk5.png"),
    }
    currentAnimation = "idle"
    currentFrame = 1

    animationTimings = {
        idle = {1, 2},
        walk = {1, 2, 3, 4, 5},
    }
    frameDuration = 0.1
    timeSinceLastFrame = 0

    font = love.graphics.newFont("font/font.ttf", 30)
    love.graphics.setFont(font)

    flag = love.graphics.newImage("image/flag.png")
    flagVisible = false

    flags = {}

    cameraX = 0
    cameraY = 0

    paperImage = love.graphics.newImage("image/items/paper.png")
    appleImage = love.graphics.newImage("image/items/apple.png")
    woodImage = love.graphics.newImage("image/items/wood.png")
    stoneImage = love.graphics.newImage("image/items/stone.png")
    amorphousImage = love.graphics.newImage("image/items/amorphous.png")
    snowballImage = love.graphics.newImage("image/items/snowball.png")

    GridSize = 64
    InventorySize = 5
    inventory = {}

    boatImage = love.graphics.newImage("image/boat.png")

    grassNormal  = love.graphics.newImage("image/grass_type/normal.png")
    grassHot = love.graphics.newImage("image/grass_type/hot.png")
    grassCold  = love.graphics.newImage("image/grass_type/cold.png")
    sandNormal = love.graphics.newImage("image/sand_type/normal.png")
    sandGarnet = love.graphics.newImage("image/sand_type/garnet.png")
    sandGypsum = love.graphics.newImage("image/sand_type/gypsum.png")
    sandOlivine = love.graphics.newImage("image/sand_type/olivine.png")
    snow = love.graphics.newImage("image/snow.png")
    waterSmall = love.graphics.newImage("image/water_type/type1.png")
    waterMedium = love.graphics.newImage("image/water_type/type2.png")
    waterDeep = love.graphics.newImage("image/water_type/type3.png")
    darkStone = love.graphics.newImage("image/stone_type/stone_dark.png")

    stone = love.graphics.newImage("image/stone_type/stone.png")
    rhyolite = love.graphics.newImage("image/stone_type/rhyolite.png")
    pumice = love.graphics.newImage("image/stone_type/pumice.png")
    porphyry = love.graphics.newImage("image/stone_type/porphyry.png")
    granite = love.graphics.newImage("image/stone_type/granite.png")
    gabbro = love.graphics.newImage("image/stone_type/gabbro.png")
    basalt = love.graphics.newImage("image/stone_type/basalt.png")

    treeImage = love.graphics.newImage("image/tree.png")
    rockImage = love.graphics.newImage("image/rock.png")
    IronoreImage = love.graphics.newImage("image/ore_type/iron.png")

    objectImage = love.graphics.newImage("image/ore_type/iron.png")

    tree = {x = 100, y = 100, health = 100}
    rock = {x = 200, y = 100, health = 150}
    Ironore = {x = 300, y = 100, health = 200}

    snowMessage = "Brrr, it's cold!"

    tileSize = 109
    mapWidth = 101
    mapHeight = 101

    isInBoat = false

    boatX = countryball.x + 50
    boatY = countryball.y + 50

    hunger = 100

    map = {}

    inventoryPosition = { x = 50, y = 650 }

    for x = 1, mapWidth do
        map[x] = {}
        for y = 1, mapHeight do
          local tile = math.random(1, 10)
          if tile <= 3 then
            if math.random(1, 3) == 1 then
              map[x][y] = {type = grassHot}
            elseif math.random(1, 3) == 1 then
              map[x][y] = {type = grassCold}
            else
              map[x][y] = {type = grassNormal}
            end
          elseif tile <= 6 then
            local sand_tile = math.random(1, 4)
            if sand_tile == 1 then
              map[x][y] = {type = sandGarnet}
            elseif sand_tile == 2 then
              map[x][y] = {type = sandGypsum}
            elseif sand_tile == 3 then
              map[x][y] = {type = sandNormal}
            else
              map[x][y] = {type = sandOlivine}
            end
          elseif tile == 7 then
            map[x][y] = {type = snow, message = snowMessage}
          elseif tile <= 9 then
            local water_tile = math.random(1, 3)
            if water_tile == 1 then
              map[x][y] = {type = waterSmall}
            elseif water_tile == 2 then
              map[x][y] = {type = waterMedium}
            else
              map[x][y] = {type = waterDeep}
            end
          else
            map[x][y] = {type = grassNormal}
          end
          map[x][y].temperature = temperature
        end
      end

      num_islands = 10
      island_min_size = 5
      island_max_size = 10

      for i = 1, num_islands do
        local island_size = math.random(island_min_size, island_max_size)
        local island_x = math.random(island_size, mapWidth - island_size + 1)
        local island_y = math.random(island_size, mapHeight - island_size + 1) 
        for x = island_x - island_size + 1, island_x + island_size - 1 do 
            for y = island_y - island_size + 1, island_y + island_size - 1 do 
                if math.sqrt((x - island_x) ^ 2 + (y - island_y) ^ 2) <= island_size then 
                    map[x][y] = {type = waterDeep} 
                elseif math.sqrt((x - island_x) ^ 2 + (y - island_y) ^ 2) <= island_size then
                    map[x][y] = {type = waterMedium}
                else
                    map[x][y] = {type = grassNormal}
                end 
            end 
        end 
    end

    CountryballTile = {type = grassNormal}
    in_boat = false

    maxDistance = 850
    minDistance = 355

    titleImage = love.graphics.newImage("image/menu/title.png")
    playImage = love.graphics.newImage("image/menu/play.png")
    creditsImage = love.graphics.newImage("image/menu/credits.png")

    buttonWidth = 200
    buttonHeight = 50
    playButtonPosition = { x = love.graphics.getWidth() / 2 - buttonWidth / 2, y = love.graphics.getHeight() / 2 - buttonHeight / 2 }
    creditsButtonPosition = { x = love.graphics.getWidth() / 2 - buttonWidth / 2, y = playButtonPosition.y + buttonHeight + 10 }

    gameStarted = false

    dayLength = 10
    currentTime = 0
    temperatureRange = 100
    currentTemperature = 0

    fps = 0
    timer = 0
    updateInterval = 0.5

    hunger = 100
    health = 100
    barWidth = 200
    barHeight = 20
    barPadding = 10
    barY = 680

    heartImage = love.graphics.newImage("image/bar/heart.png")
    foodImage = love.graphics.newImage("image/bar/food.png")
end

--update
function love.update(dt)

    boatX = countryball.x - 10
    boatY = countryball.y + 0

    timer = timer + dt
    if timer > updateInterval then
      fps = love.timer.getFPS()
      timer = timer - updateInterval
    end

    local isWalking = false

    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        countryball.x = countryball.x - countryball.speed * dt
        flip = true
        currentAnimation = "walk"
        isWalking = true
    elseif love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        countryball.x = countryball.x + countryball.speed * dt
        flip = false
        currentAnimation = "walk"
        isWalking = true
    else
        currentAnimation = "idle"
    end

    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        currentAnimation = "walk"
    elseif love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        currentAnimation = "walk"
    else
        currentAnimation = "idle"
    end

    if isWalking then
      currentAnimation = "walk"
    elseif currentAnimation == "walk" then
      currentAnimation = "idle"
    end

    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        countryball.y = countryball.y - countryball.speed * dt
        currentAnimation = "walk"
    elseif love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        countryball.y = countryball.y + countryball.speed * dt
        currentAnimation = "walk"
    else
        currentAnimation = "idle"
    end

    local blockX, blockY = math.floor(countryball.x / tileSize) + 1, math.floor(countryball.y / tileSize) + 1
    if map[blockX][blockY].type then
      if map[blockX][blockY].type == grassHot then
        temperature = math.random(30, 45)
        in_boat = false
      elseif map[blockX][blockY].type == grassCold then
        temperature = math.random(-20, 10)
        in_boat = false
      elseif map[blockX][blockY].type == grassNormal then
        temperature = math.random(11, 29)
        in_boat = false
      elseif map[blockX][blockY].type == waterDeep then
        in_boat = true
      elseif map[blockX][blockY].type == waterMedium then
        in_boat = true
      elseif map[blockX][blockY].type == waterSmall then
        in_boat = true
      elseif map[blockX][blockY].type == sandNormal then
        in_boat = false
      elseif map[blockX][blockY].type == sandGarnet then
        in_boat = false
      elseif map[blockX][blockY].type == sandOlivine then
        in_boat = false
      elseif map[blockX][blockY].type == sandGypsum then
        in_boat = false
      elseif map[blockX][blockY].type == snow then
        in_boat = false
      end
    end

    for x = 1, mapWidth do 
        for y = 1, mapHeight do 
          local blockX = (x-1)*tileSize
          local blockY = (y-1)*tileSize
          local distance = math.sqrt((blockX - countryball.x)^2 + (blockY - countryball.y)^2)
    
          if distance < minDistance then
            map[x][y].alpha = 1

          elseif distance > maxDistance then
            map[x][y].alpha = 0
          else
            map[x][y].alpha = (maxDistance - distance) / (maxDistance - minDistance)
          end
        end 
      end 

    timeSinceLastFrame = timeSinceLastFrame + dt
    if timeSinceLastFrame >= frameDuration then
      currentFrame = currentFrame + 1
      if currentFrame > #animationTimings[currentAnimation] then
         currentFrame = 1
      end
      timeSinceLastFrame = 0
    end

    if love.mouse.isDown(1) then
      checkObjectClick(tree)
      checkObjectClick(rock)
      checkObjectClick(Ironore)
    end

    currentTime = currentTime + dt

    if currentTime >= dayLength then
      currentTime = currentTime - dayLength
    end

    currentTemperature = calculateTemperature()

    cameraX = -countryball.x + love.graphics.getWidth() / 2 / scale
    cameraY = -countryball.y + love.graphics.getHeight() / 2 / scale
end

--draw
function love.draw()
    love.graphics.push()
    love.graphics.translate(cameraX * scale, cameraY * scale)

    local bgColor = calculateBackgroundColor()

    love.graphics.setBackgroundColor(bgColor.r, bgColor.g, bgColor.b)

    for x = 1, mapWidth do 
        for y = 1, mapHeight do 
            if not map[x][y] then
                map[x][y] = {type = waterDeep}
            end
            if map[x][y].type then
                love.graphics.setColor(1, 1, 1, map[x][y].alpha)
                love.graphics.draw(map[x][y].type, (x-1)*tileSize, (y-1)*tileSize)
                if y > mapHeight - 10 and map[x][y].type ~= waterSmall and map[x][y].type ~= waterMedium and map[x][y].type ~= waterDeep then 
                    love.graphics.draw(stone, (x-1)*tileSize, (y-1)*tileSize) 
                end 
            end
        end 
    end

    for _, rock in ipairs(rocks) do
      love.graphics.draw(rockImage, rock.x, rock.y)
    end

    love.graphics.setColor(1, 1, 1, 1)

    if flip then
      --love.graphics.draw(countryball.Idleimage1, countryball.x + countryball.Idleimage1:getWidth() * scale, countryball.y, 0, -scale, scale)

      if currentAnimation == "idle" then
          love.graphics.draw(countryball.Idleimage1, countryball.x + countryball.Idleimage1:getWidth() * scale, countryball.y, 0, -scale, scale)
        else
          if currentFrame == 1 then
              love.graphics.draw(countryball.Walkimage1, countryball.x + countryball.Walkimage1:getWidth() * scale, countryball.y, 0, -scale, scale)
          elseif currentFrame == 2 then
              love.graphics.draw(countryball.Walkimage2, countryball.x + countryball.Walkimage2:getWidth() * scale, countryball.y, 0, -scale, scale)
          elseif currentFrame == 3 then
              love.graphics.draw(countryball.Walkimage3, countryball.x + countryball.Walkimage3:getWidth() * scale, countryball.y, 0, -scale, scale)
          elseif currentFrame == 4 then
              love.graphics.draw(countryball.Walkimage4, countryball.x + countryball.Walkimage4:getWidth() * scale, countryball.y, 0, -scale, scale)
          else
              love.graphics.draw(countryball.Walkimage5, countryball.x + countryball.Walkimage5:getWidth() * scale, countryball.y, 0, -scale, scale)
          end
      end
  else
      --love.graphics.draw(countryball.Idleimage1, countryball.x, countryball.y, 0)

      if currentAnimation == "idle" then
          love.graphics.draw(countryball.Idleimage1, countryball.x, countryball.y, 0)
        else
          if currentFrame == 1 then
              love.graphics.draw(countryball.Walkimage1, countryball.x, countryball.y, 0)
          elseif currentFrame == 2 then
              love.graphics.draw(countryball.Walkimage2, countryball.x, countryball.y, 0)
          elseif currentFrame == 3 then
              love.graphics.draw(countryball.Walkimage3, countryball.x, countryball.y, 0)
          elseif currentFrame == 4 then
              love.graphics.draw(countryball.Walkimage4, countryball.x, countryball.y, 0)
          else
              love.graphics.draw(countryball.Walkimage5, countryball.x, countryball.y, 0)
          end
      end
  end

  love.graphics.draw(treeImage, tree.x, tree.y)
  love.graphics.draw(rockImage, rock.x, rock.y)
  love.graphics.draw(IronoreImage, Ironore.x, Ironore.y)

  love.graphics.print("Tree health: " .. tree.health, tree.x, tree.y)
  love.graphics.print("Rock health: " .. rock.health, rock.x, rock.y)
  love.graphics.print("Ore health: " .. Ironore.health, Ironore.x, Ironore.y)


    for i, flag in ipairs(flags) do
        love.graphics.draw(flag.image, flag.x, flag.y)
    end

    if in_boat == true then
        love.graphics.draw(boatImage, boatX, boatY)
    end

    love.graphics.pop()
    local thermometerHeight = 300
    local thermometerWidth = 50
    local thermometerX = love.graphics.getWidth() - thermometerWidth - 10
    local thermometerY = love.graphics.getHeight() - thermometerHeight - 10
    local thermometerColor = calculateThermometerColor()
    love.graphics.setColor(255, 255, 255)
    love.graphics.rectangle("fill", thermometerX, thermometerY, thermometerWidth, thermometerHeight)
    love.graphics.setColor(thermometerColor.r, thermometerColor.g, thermometerColor.b)
    local fillHeight = thermometerHeight * ((currentTemperature + (temperatureRange / 2)) / temperatureRange)
    love.graphics.rectangle("fill", thermometerX + 2, thermometerY + 2 + (thermometerHeight - fillHeight), thermometerWidth - 4, fillHeight - 4)

    love.graphics.setColor(255, 255, 255)
    --love.graphics.print("Temperature: " .. currentTemperature .. "°F", 20, 20)
    love.graphics.print("FPS: " .. fps, 20, 20)

    love.graphics.setColor(255, 255, 255)

    if not gameStarted then
      local x = love.graphics.getWidth() / 2 - titleImage:getWidth() / 2
      local y = love.graphics.getHeight() / 4 - titleImage:getHeight() / 2
      love.graphics.draw(titleImage, x, y)
  
      love.graphics.draw(playImage, playButtonPosition.x, playButtonPosition.y)
      love.graphics.draw(creditsImage, creditsButtonPosition.x, creditsButtonPosition.y)
    end
end

function love.keypressed(key)
    if key == "f" then

    end

    if key == "e" then

    end
end

function love.mousepressed(x, y, button)
  if not gameStarted and
     x > playButtonPosition.x and x < playButtonPosition.x + buttonWidth and
     y > playButtonPosition.y and y < playButtonPosition.y + buttonHeight then
    gameStarted = true
    love.loadGame()
  end
  
  if not gameStarted and
     x > creditsButtonPosition.x and x < creditsButtonPosition.x + buttonWidth and
     y > creditsButtonPosition.y and y < creditsButtonPosition.y + buttonHeight then
    love.showCredits()
  end
end


function love.mousemoved(x, y)

end

function decreaseHunger(dt)
    hunger = hunger - dt*0.2
end

function increaseHunger(amount)
    hunger = hunger + amount
    if hunger > 100 then
        hunger = 100
    end
end

function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 < x2 + w2 and
         x2 < x1 + w1 and
         y1 < y2 + h2 and
         y2 < y1 + h1
end

function love.loadGame()
  titleImage = nil
  playImage = nil
  creditsImage = nil
  love.audio.stop(menumusic)
  love.audio.play(music)
end

function love.showCredits()
  love.graphics.draw(darkStone, creditsButtonPosition.x, creditsButtonPosition.y)
end

function checkObjectClick(object)
  local mouseX, mouseY = love.mouse.getPosition()

  if mouseX > object.x and mouseX < object.x + objectImage:getWidth() and
     mouseY > object.y and mouseY < object.y + objectImage:getHeight() then

    object.health = object.health - 10

    if object.health <= 0 then
      object.health = 0
    end
  end
end

function calculateTemperature()
  local temperatureAmplitude = 50
  local temperatureOffset = 25
  local temperatureMultiplier = math.sin((currentTime / dayLength) * (2 * math.pi))
  return (temperatureMultiplier * temperatureAmplitude) + temperatureOffset
end

function calculateBackgroundColor()
  local color = {}
  if currentTime <= dayLength / 2 then
    color.r = 0 * (currentTime / (dayLength / 2))
    color.g = 75 * (currentTime / (dayLength / 2))
    color.b = 255
  else
    color.r = 0
    color.g = 0 * ((dayLength - currentTime) / (dayLength / 2))
    color.b = 0 * ((dayLength - currentTime) / (dayLength / 2))
  end
  return color
end

function calculateThermometerColor()
  local color = {}

  if currentTemperature < -20 then
    color.r = 0
    color.g = 0
    color.b = 255
  elseif currentTemperature < 0 then
    color.r = 0
    color.g = 255 * ((currentTemperature + 20) / 20)
    color.b = 255
  elseif currentTemperature < 20 then
    color.r = 255 * ((currentTemperature + 20) / 20)
    color.g = 255
    color.b = 0
  elseif currentTemperature < 40 then
    color.r = 255
    color.g = 255 * ((currentTemperature - 20) / 20)
    color.b = 0
  else
    color.r = 255
    color.g = 0
    color.b = 0
  end
  return color
end