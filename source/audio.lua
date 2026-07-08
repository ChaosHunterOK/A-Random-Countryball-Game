local love = require "love"

local Audio = {}

Audio.songs = {
    main = "music/music.mp3",
    menu = "music/menu.mp3",
    pause = "music/taketwo_3.mp3",
    credits = "music/takethree.mp3"
}
Audio.sources = {}

function Audio.load()
    for name, path in pairs(Audio.songs) do
        local source = love.audio.newSource(path, "stream")
        source:setLooping(true)
        source:setVolume(1)
        Audio.sources[name] = source
    end
end

function Audio.stopAll()
    for _, source in pairs(Audio.sources) do
        source:stop()
        source:setVolume(1)
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