local ffi = require("ffi")
local discord = {}

discord.C = ffi.load("discord-rpc")

ffi.cdef[[
    typedef struct DiscordRichPresence {
        const char* state;
        const char* details;
        int64_t startTimestamp;
        int64_t endTimestamp;
        const char* largeImageKey;
        const char* largeImageText;
        const char* smallImageKey;
        const char* smallImageText;
        const char* partyId;
        int partySize;
        int partyMax;
        const char* matchSecret;
        const char* joinSecret;
        const char* spectateSecret;
        unsigned int instance;
    } DiscordRichPresence;

    void Discord_Initialize(const char* applicationId, void* handlers, int autoRegister, const char* optionalSteamId);
    void Discord_Shutdown();
    void Discord_UpdatePresence(const DiscordRichPresence* presence);
    void Discord_RunCallbacks();
]]

function discord.initialize(appId)
    discord.C.Discord_Initialize(appId, nil, 1, nil)
end

function discord.updatePresence(presenceData)
    local presence = ffi.new("DiscordRichPresence")
    presence.state = presenceData.state
    presence.details = presenceData.details
    presence.startTimestamp = presenceData.startTimestamp or 0
    presence.endTimestamp = presenceData.endTimestamp or 0
    presence.largeImageKey = presenceData.largeImageKey or nil
    presence.largeImageText = presenceData.largeImageText or nil
    presence.smallImageKey = presenceData.smallImageKey or nil
    presence.smallImageText = presenceData.smallImageText or nil
    presence.partyId = presenceData.partyId or nil
    presence.partySize = presenceData.partySize or 0
    presence.partyMax = presenceData.partyMax or 0
    presence.matchSecret = presenceData.matchSecret or nil
    presence.joinSecret = presenceData.joinSecret or nil
    presence.spectateSecret = presenceData.spectateSecret or nil
    presence.instance = presenceData.instance or 0

    discord.C.Discord_UpdatePresence(presence)
end

function discord.runCallbacks()
    discord.C.Discord_RunCallbacks()
end

function discord.shutdown()
    discord.C.Discord_Shutdown()
end

return discord