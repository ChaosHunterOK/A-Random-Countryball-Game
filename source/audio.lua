local love = require "love"

local Audio = {}

Audio.songs = {
    main = "music/music.mp3",
    menu = "music/menu.mp3"
}

Audio.sources = {}

function Audio.load()
    for name, path in pairs(Audio.songs) do
        Audio.sources[name] = love.audio.newSource(path, "stream")
        Audio.sources[name]:setLooping(true)
    end
end

function Audio.switchSong(name)
    for _, source in pairs(Audio.sources) do
        source:stop()
    end
    if Audio.sources[name] then
        Audio.sources[name]:setLooping(true)
        Audio.sources[name]:play()
    end
end

function Audio.stopAll()
    for _, source in pairs(Audio.sources) do
        source:stop()
    end
end

function Audio.pauseAll()
    for _, source in pairs(Audio.sources) do
        if source:isPlaying() then
            source:pause()
        end
    end
end

function Audio.resumeAll()
    for _, source in pairs(Audio.sources) do
        if not source:isPlaying() then
            source:play()
        end
    end
end

function Audio.getSource(name)
    return Audio.sources[name]
end

return Audio
