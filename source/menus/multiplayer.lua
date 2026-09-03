local love = require"love"
local lg = love.graphics
local utils = require("source.utils.utils")

local ok_enet, enet = pcall(require, "enet")

local DEFAULT_PORT = "6789"

local MultiplayerMenu = {
    mode = "select",
    isServer = false,
    host = nil,
    peer = nil,
    peers = {},
    peerCount = 0,
    portInput = DEFAULT_PORT,
    ipInput = "127.0.0.1:"..DEFAULT_PORT,
    nextId = 1,
    peerIds = {},
    localId = nil,
    statusMessage = "",
    statusTimer = 0,
    log = {},
    localIPs = {},
    connectElapsed = 0,
    onReceive = nil,
    onPeerConnect = nil,
    onPeerDisconnect = nil,
    onDisconnected = nil,
}

local function countPeers(peers)
    local n = 0
    for _ in pairs(peers) do n = n + 1 end
    return n
end

local function isLikelyVirtualLanIP(ip)
    if ip:match("^10%.147%.") then return true end
    if ip:match("^172%.2[0-9]%.") then return true end
    if ip:match("^172%.3[01]%.") then return true end
    if ip:match("^100%.6[4-9]%.") or ip:match("^100%.[7-9][0-9]%.") or ip:match("^100%.1[01][0-9]%.") then return true end
    return false
end

local function getLocalIPs()
    local ips = {}
    local seen = {}
    local function add(ip)
        if ip and not seen[ip] and ip ~= "127.0.0.1" then
            seen[ip] = true
            table.insert(ips, { ip = ip, virtual = isLikelyVirtualLanIP(ip) })
        end
    end
    local commands
    if love and love.system and love.system.getOS() == "Windows" then
        commands = { "ipconfig" }
    else
        commands = { "ifconfig 2>/dev/null", "ip -4 addr show 2>/dev/null" }
    end

    for _, cmd in ipairs(commands) do
        local okp, handle = pcall(io.popen, cmd)
        if okp and handle then
            local out = handle:read("*a") or ""
            handle:close()
            for ip in out:gmatch("(%d+%.%d+%.%d+%.%d+)") do
                if ip ~= "255.255.255.255" and not ip:match("^0%.") then
                    add(ip)
                end
            end
            if #ips > 0 then break end
        end
    end

    return ips
end

local function serialize(t)
    if type(t) == "string" then return t end
    local parts = {}
    for k, v in pairs(t) do
        table.insert(parts, tostring(k).."="..tostring(v))
    end
    return table.concat(parts, "&")
end

local function deserialize(s)
    local t = {}
    for pair in s:gmatch("[^&]+") do
        local k, v = pair:match("^([^=]+)=(.*)$")
        if k then
            if v == "true" then
                t[k] = true
            elseif v == "false" then
                t[k] = false
            elseif tonumber(v) then
                t[k] = tonumber(v)
            else
                t[k] = v
            end
        end
    end
    return t
end

function MultiplayerMenu:addLog(msg)
    table.insert(self.log, msg)
    if #self.log > 8 then table.remove(self.log, 1) end
end

function MultiplayerMenu:setStatus(msg)
    self.statusMessage = msg
    self.statusTimer = 4
end

function MultiplayerMenu.load()
    if not ok_enet then
        MultiplayerMenu.statusMessage = "ENet not available on this system"
    end
end

function MultiplayerMenu:startHost()
    if not ok_enet then
        self:setStatus("Networking unavailable (enet failed to load)")
        return
    end
    local port = tonumber(self.portInput) or tonumber(DEFAULT_PORT)
    local ok, host = pcall(enet.host_create, "0.0.0.0:"..port, 32, 2)
    if not ok or not host then
        self:setStatus("Failed to host on port "..port)
        return
    end
    self.host = host
    self.isServer = true
    self.peers = {}
    self.peerCount = 0
    self.nextId = 1
    self.peerIds = {}
    self.localId = 0
    self.mode = "hosting"
    self.log = {}
    self:addLog("Hosting on port "..port)

    self.localIPs = getLocalIPs()
    if #self.localIPs == 0 then
        self:addLog("Share your IP (LAN, ZeroTier, etc) + port "..port)
    else
        local shownVirtual = false
        for _, entry in ipairs(self.localIPs) do
            if entry.virtual then
                self:addLog("Share (virtual LAN): "..entry.ip..":"..port)
                shownVirtual = true
            end
        end
        if not shownVirtual then
            for _, entry in ipairs(self.localIPs) do
                self:addLog("Share: "..entry.ip..":"..port)
            end
        end
    end

    self.shouldStartGame = "host"
end

function MultiplayerMenu:startJoin()
    if not ok_enet then
        self:setStatus("Networking unavailable (enet failed to load)")
        return
    end
    local address = self.ipInput:match("^%s*(.-)%s*$") -- trim
    if address == "" then
        self:setStatus("Enter an address to connect to")
        return
    end
    if not address:find(":") then
        address = address..":"..DEFAULT_PORT
    end
    local ok, host = pcall(enet.host_create, nil, 1, 2)
    if not ok or not host then
        self:setStatus("Failed to create client host")
        return
    end
    local okc, peer = pcall(host.connect, host, address, 2)
    if not okc or not peer then
        self:setStatus("Failed to connect to "..address)
        return
    end
    self.host = host
    self.peer = peer
    self.isServer = false
    self.localId = nil
    self.mode = "connecting"
    self.connectElapsed = 0
    self.log = {}
    self:addLog("Connecting to "..address.."...")
    self:addLog("(Make sure both sides are on the same ZeroTier network")
    self:addLog(" and the host's port is reachable/allowed.)")
end

function MultiplayerMenu:disconnect()
    if self.onDisconnected then self.onDisconnected() end
    if self.peer then
        pcall(self.peer.disconnect_now, self.peer)
    end
    if self.isServer and self.peers then
        for p in pairs(self.peers) do
            pcall(p.disconnect_now, p)
        end
    end
    self.host = nil
    self.peer = nil
    self.peers = {}
    self.peerCount = 0
    self.peerIds = {}
    self.nextId = 1
    self.localId = nil
    self.isServer = false
    self.mode = "select"
    self.log = {}
    self.localIPs = {}
    self.connectElapsed = 0
end

function MultiplayerMenu:shutdown()
    if self.host then
        self:disconnect()
    end
end

function MultiplayerMenu:isActive()
    return self.host ~= nil
end

function MultiplayerMenu:isConnected()
    return self.mode == "connected" or (self.isServer and self.peerCount > 0)
end

function MultiplayerMenu:send(data, reliable)
    if not self.host then return end
    local payload = serialize(data)
    local flag = (reliable == false) and "unsequenced" or "reliable"
    local channel = (reliable == false) and 1 or 0
    if self.isServer then
        for p in pairs(self.peers) do
            p:send(payload, channel, flag)
        end
    elseif self.peer then
        self.peer:send(payload, channel, flag)
    end
end

function MultiplayerMenu:relay(excludePeer, data, reliable)
    local payload = serialize(data)
    local flag = (reliable == false) and "unsequenced" or "reliable"
    local channel = (reliable == false) and 1 or 0
    for p in pairs(self.peers) do
        if p ~= excludePeer then
            p:send(payload, channel, flag)
        end
    end
end

function MultiplayerMenu:update(dt)
    if self.statusTimer > 0 then
        self.statusTimer = self.statusTimer - dt
        if self.statusTimer <= 0 then self.statusMessage = "" end
    end

    if not self.host then return end

    if self.mode == "connecting" then
        self.connectElapsed = (self.connectElapsed or 0) + dt
        if self.connectElapsed > 10 then
            self:setStatus("Connection timed out. Check the IP/port, that the host is running, and any firewall (ZeroTier/router) blocking UDP.")
            self:disconnect()
            return
        end
    end

    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            if self.isServer then
                local id = self.nextId
                self.nextId = self.nextId + 1
                self.peerIds[event.peer] = id
                self.peers[event.peer] = event.peer
                self.peerCount = countPeers(self.peers)
                event.peer:send(serialize({sys = "assign_id", id = id, seed = self.mapSeed}), 0, "reliable")
                self:addLog("Player connected ("..self.peerCount.." total)")
                if self.onPeerConnect then self.onPeerConnect(event.peer, id) end
            else
                self.mode = "connected"
                self:addLog("Connected to host!")
            end
        elseif event.type == "receive" then
            local data = deserialize(event.data)
            if self.isServer then
                data.id = self.peerIds[event.peer]
                self:relay(event.peer, data, false)
                if self.onReceive then self.onReceive(data, event.peer) end
            else
                if data.sys == "assign_id" then
                    self.localId = data.id
                    self.receivedSeed = data.seed
                    self.shouldStartGame = "client"
                else
                    if self.onReceive then self.onReceive(data, event.peer) end
                end
            end
        elseif event.type == "disconnect" then
            if self.isServer then
                local id = self.peerIds[event.peer]
                self.peers[event.peer] = nil
                self.peerIds[event.peer] = nil
                self.peerCount = countPeers(self.peers)
                self:addLog("Player disconnected ("..self.peerCount.." total)")
                self:relay(event.peer, {sys = "leave", id = id}, true)
                if self.onReceive then self.onReceive({sys = "leave", id = id}) end
                if self.onPeerDisconnect then self.onPeerDisconnect(event.peer, id) end
            else
                self:addLog("Disconnected from host")
                self:disconnect()
            end
        end
        event = self.host and self.host:service(0) or nil
    end
end

function MultiplayerMenu:keypressed(key)
    if self.mode == "select" then
        if key == "h" then
            self.mode = "host_setup"
        elseif key == "j" then
            self.mode = "join_setup"
        end
    elseif self.mode == "host_setup" then
        if key == "return" then
            self:startHost()
        elseif key == "backspace" then
            self.portInput = self.portInput:sub(1, -2)
        elseif key == "escape" then
            self.mode = "select"
        end
    elseif self.mode == "join_setup" then
        if key == "return" then
            self:startJoin()
        elseif key == "backspace" then
            self.ipInput = self.ipInput:sub(1, -2)
        elseif key == "escape" then
            self.mode = "select"
        end
    elseif self.mode == "hosting" or self.mode == "connecting" or self.mode == "connected" then
        if key == "escape" then
            self:disconnect()
        end
    end
end

function MultiplayerMenu:textinput(t)
    if self.mode == "host_setup" then
        if t:match("%d") and #self.portInput < 5 then
            self.portInput = self.portInput..t
        end
    elseif self.mode == "join_setup" then
        if t:match("[%w%.:%-]") and #self.ipInput < 48 then
            self.ipInput = self.ipInput..t
        end
    end
end

function MultiplayerMenu:handlesEscape()
    return self.mode ~= "select"
end

function MultiplayerMenu:draw()
    local w, h = lg.getDimensions()
    lg.setColor(0, 0, 0, 0.55)
    lg.rectangle("fill", 0, 0, w, h)
    lg.setColor(1, 1, 1, 1)

    utils.drawTextWithBorder("Multiplayer", w / 2 - 100, 40)

    if self.mode == "select" then
        utils.drawTextWithBorder("[H] Host a Game", w / 2 - 100, h / 2 - 50)
        utils.drawTextWithBorder("[J] Join a Game", w / 2 - 100, h / 2 - 10)
        utils.drawTextWithBorder("[Esc] Back", w / 2 - 100, h / 2 + 50)
    elseif self.mode == "host_setup" then
        utils.drawTextWithBorder("Port: "..self.portInput.."_", w / 2 - 100, h / 2 - 20)
        utils.drawTextWithBorder("[Enter] Start Hosting   [Esc] Back", w / 2 - 160, h / 2 + 40)
    elseif self.mode == "join_setup" then
        utils.drawTextWithBorder("Address: "..self.ipInput.."_", w / 2 - 130, h / 2 - 20)
        utils.drawTextWithBorder("[Enter] Connect   [Esc] Back", w / 2 - 140, h / 2 + 40)
    elseif self.mode == "hosting" then
        utils.drawTextWithBorder("Hosting on port "..self.portInput, w / 2 - 120, h / 2 - 50)
        utils.drawTextWithBorder("Players connected: "..self.peerCount, w / 2 - 120, h / 2 - 20)
        utils.drawTextWithBorder("[Esc] Stop Hosting", w / 2 - 100, h / 2 + 40)
        if self.localIPs and #self.localIPs > 0 then
            local y = h / 2 + 80
            utils.drawTextWithBorder("Share one of these with friends:", w / 2 - 140, y)
            for _, entry in ipairs(self.localIPs) do
                y = y + 22
                local label = entry.ip..":"..self.portInput
                if entry.virtual then label = label.." (virtual LAN)" end
                utils.drawTextWithBorder(label, w / 2 - 140, y)
            end
        end
    elseif self.mode == "connecting" then
        utils.drawTextWithBorder("Connecting to "..self.ipInput.."...", w / 2 - 130, h / 2 - 20)
        utils.drawTextWithBorder("[Esc] Cancel", w / 2 - 70, h / 2 + 40)
    elseif self.mode == "connected" then
        utils.drawTextWithBorder("Connected!", w / 2 - 60, h / 2 - 20)
        utils.drawTextWithBorder("[Esc] Disconnect", w / 2 - 100, h / 2 + 40)
    end

    if self.statusMessage ~= "" then
        lg.setColor(1, 0.4, 0.4, 1)
        utils.drawTextWithBorder(self.statusMessage, w / 2 - 180, h - 110)
        lg.setColor(1, 1, 1, 1)
    end

    for i, msg in ipairs(self.log) do
        utils.drawTextWithBorder(msg, 20, h - 40 - (#self.log - i) * 22)
    end
end

return MultiplayerMenu