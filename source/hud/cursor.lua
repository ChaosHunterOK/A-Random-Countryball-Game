local love = require "love"
local lg = love.graphics

local Cursor = {
    x = 0,
    y = 0,
    anim = {},
    state = { frameTimer = 0, frameIndex = 1, frameDuration = 0.5 }
}

local function getFrames(animImages, animName, dt, state)
    local frames = animImages[animName]
    if not frames then return nil end
    if type(frames) ~= "table" then
        return frames
    end

    state.frameTimer = state.frameTimer or 0
    state.frameIndex = state.frameIndex or 1
    local duration = state.frameDuration or 0.12

    state.frameTimer = state.frameTimer + dt
    if state.frameTimer >= duration then
        state.frameTimer = state.frameTimer - duration
        state.frameIndex = (state.frameIndex % #frames) + 1
    end

    return frames[state.frameIndex]
end

function Cursor.load()
    Cursor.anim["idle"] = {
        lg.newImage("image/cursor/1.png"),
        lg.newImage("image/cursor/2.png")
    }
end

function Cursor.update(dt)
    Cursor.x, Cursor.y = love.mouse.getPosition()
    Cursor.currentFrame = getFrames(Cursor.anim, "idle", dt, Cursor.state)
end

function Cursor.draw()
    if Cursor.currentFrame then
        lg.draw(Cursor.currentFrame, Cursor.x, Cursor.y)
    end
end

return Cursor
