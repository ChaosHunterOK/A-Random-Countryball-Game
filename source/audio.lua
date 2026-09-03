local love = require "love"

local Audio = {}

Audio.songs = {
    main = "music/walking forward.mp3",
    music = "music/music.mp3",
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
Audio.currentTrack = nil

function Audio.load()
    Audio.currentTrack = nil
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
    Audio.updateVolumes()
end

function Audio.switchSong(name)
    local source = Audio.music[name]
    if not source then return end

    if Audio.currentTrack == name and source:isPlaying() then
        return
    end

    Audio.stopMusic()
    Audio.currentTrack = name
    source:seek(0)
    source:setVolume(Audio.masterVolume * Audio.musicVolume)
    source:play()
end

function Audio.playMusic(name)
    Audio.switchSong(name)
end

function Audio.stopMusic()
    for _, source in pairs(Audio.music) do
        source:stop()
    end
    Audio.currentTrack = nil
end

function Audio.playSound(name)
    local source = Audio.sfx[name]
    if not source then return end

    local clone = source:clone()
    clone:setVolume(Audio.masterVolume * Audio.soundVolume)
    love.audio.play(clone)
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

Audio.masterVolume = 0.5
Audio.musicVolume = 1
Audio.soundVolume = 1

function Audio.updateVolumes()
    for _, source in pairs(Audio.music) do
        source:setVolume(Audio.masterVolume * Audio.musicVolume)
    end

    for _, source in pairs(Audio.sfx) do
        source:setVolume(Audio.masterVolume * Audio.soundVolume)
    end
end

function Audio.getCurrentTrack()
    return Audio.currentTrack
end

function Audio.setMasterVolume(v)
    Audio.masterVolume = v
    Audio.updateVolumes()
end

function Audio.setMusicVolume(v)
    Audio.musicVolume = v
    Audio.updateVolumes()
end

function Audio.setSoundVolume(v)
    Audio.soundVolume = v
    Audio.updateVolumes()
end

return Audio