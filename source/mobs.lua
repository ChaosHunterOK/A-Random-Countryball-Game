local love = require "love"
local lg = love.graphics
local random, sqrt, cos, sin, floor = math.random, math.sqrt, math.cos, math.sin, math.floor
local camera = require("source.projectile.camera")

local mobs = {
    entities = {},
    types = {
        racoon_dog = {
            img = lg.newImage("image/mobs/racoon dog/idle.png"),
            speed = 1.5,
            maxHealth = 5,
            wanderRadius = 5,
            --rewards = {{item = "apple", count = {1, 2}}}
        },
    }
}

for _, t in pairs(mobs.types) do
    t.w, t.h = t.img:getDimensions()
end

function mobs.spawn(mType, x, z, getTileAt)
    local t = mobs.types[mType]
    if not t then return end
    
    local tile = getTileAt(x, z)
    local y = tile and tile.height or 0

    table.insert(mobs.entities, {
        type = mType,
        x = x, z = z, y = y,
        health = t.maxHealth,
        targetX = x, targetZ = z,
        state = "idle",
        timer = random(2, 5),
        flip = false,
        velocityV = 0
    })
end

function mobs.update(dt, getTileAt)
    for i = #mobs.entities, 1, -1 do
        local m = mobs.entities[i]
        local cfg = mobs.types[m.type]
        m.timer = m.timer - dt
        if m.timer <= 0 then
            if m.state == "idle" then
                m.state = "wander"
                m.targetX = m.x + random(-cfg.wanderRadius, cfg.wanderRadius)
                m.targetZ = m.z + random(-cfg.wanderRadius, cfg.wanderRadius)
                m.timer = random(3, 7)
            else
                m.state = "idle"
                m.timer = random(2, 4)
            end
        end
        if m.state == "wander" then
            local dx = m.targetX - m.x
            local dz = m.targetZ - m.z
            local dist = sqrt(dx*dx + dz*dz)

            if dist > 0.2 then
                local stepX = (dx / dist) * cfg.speed * dt
                local stepZ = (dz / dist) * cfg.speed * dt
                m.x = m.x + stepX
                m.z = m.z + stepZ
                m.flip = (stepX < 0)
            else
                m.state = "idle"
            end
        end
        local tile = getTileAt(m.x, m.z)
        if tile then
            local targetY = tile.height
            m.y = m.y + (targetY - m.y) * 5 * dt
        end
    end
end

function mobs.draw(drawWithStencil)
    for _, m in ipairs(mobs.entities) do
        local cfg = mobs.types[m.type]
        drawWithStencil(m.x, m.y, m.z, cfg.img, m.flip, 0, 1, -0.04)
        
        if m.health < cfg.maxHealth then
            local sx, sy, sz = camera:project3D(m.x, m.y + 0.8, m.z)
            if sx and sz > 0 then
                local scale = (1 / sz) * 6
                lg.setColor(0,0,0)
                lg.rectangle("fill", sx - 15*scale, sy, 30*scale, 4*scale)
                lg.setColor(1,0,0)
                lg.rectangle("fill", sx - 15*scale, sy, (30*scale) * (m.health/cfg.maxHealth), 4*scale)
                lg.setColor(1,1,1)
            end
        end
    end
end

function mobs.handleHit(mx, my, damage, ItemsModule)
    for i = #mobs.entities, 1, -1 do
        local m = mobs.entities[i]
        local cfg = mobs.types[m.type]
        local sx, sy, sz = camera:project3D(m.x, m.y, m.z)
        
        if sx and sz > 0 then
            local scale = (camera.hw / sz) * (camera.zoom * 0.0025) * 3.0
            local w, h = cfg.w * scale, cfg.h * scale
            
            if mx >= sx - w/2 and mx <= sx + w/2 and my >= sy - h and my <= sy then
                m.health = m.health - damage
                m.timer = 0.5
                m.state = "idle"
                
                if m.health <= 0 then
                    for _, rw in ipairs(cfg.rewards) do
                        local amt = random(rw.count[1], rw.count[2])
                        for j = 1, amt do
                            ItemsModule.dropItem(m.x, m.y + 0.5, m.z, rw.item)
                        end
                    end
                    table.remove(mobs.entities, i)
                end
                return true
            end
        end
    end
    return false
end

return mobs