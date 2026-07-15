local love = require "love"

local Audio = {}

Audio.songs = {
    main = "music/music.mp3",
    menu = "music/menu.mp3",
    pause = "music/taketwo_3.mp3",
    credits = "music/takethree.mp3",
    windy = "music/windy2.mp3",
}

Audio.sounds = {
    craft = "sounds/craft.ogg"
}

Audio.music = {}
Audio.sfx = {}

function Audio.load()
    for name, path in pairs(Audio.songs) do
        local source = love.audio.newSource(path, "stream")
        source:setLooping(true)
        source:setVolume(1)
        Audio.music[name] = source
    end
    for name, path in pairs(Audio.sounds) do
        local source = love.audio.newSource(path, "static")
        source:setVolume(1)
        Audio.sfx[name] = source
    end
end

function Audio.playMusic(name)
    local source = Audio.music[name]
    if not source then return end

    Audio.stopMusic()
    source:play()
end

function Audio.stopMusic()
    for _, source in pairs(Audio.music) do
        source:stop()
    end
end

function Audio.playSound(name)
    local source = Audio.sfx[name]
    if not source then return end
    love.audio.play(source:clone())
end

function Audio.getMusic(name)
    return Audio.music[name]
end

function Audio.getSound(name)
    return Audio.sfx[name]
end

function Audio.pauseAll()
    love.audio.pause()
end

function Audio.resumeAll()
    love.audio.play()
end

function Audio.stopAll()
    love.audio.stop()
end

return Audio