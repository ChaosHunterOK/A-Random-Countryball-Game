local love = require "love"
local Inventory = {}

function Inventory:new(size, gridSize, itemImages)
  local obj = {
      size = size,
      gridSize = gridSize,
      itemImages = itemImages,
      items = {}
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function Inventory:addItem(item)
  for i = 1, self.size do
      if not self.items[i] then
          self.items[i] = item
          break
      end
  end
end

function Inventory:removeItem(index)
  if self.items[index] then
      self.items[index] = nil
  end
end

function Inventory:draw()
  for i = 1, self.size do
      local x = (i - 1) * self.gridSize
      local y = 0
      
      love.graphics.rectangle("line", x, y, self.gridSize, self.gridSize)
      
      if self.items[i] then
          love.graphics.draw(self.itemImages[i], x, y)
          love.graphics.print(self.items[i].name, x, y + self.gridSize)
      end
  end
end

return Inventory