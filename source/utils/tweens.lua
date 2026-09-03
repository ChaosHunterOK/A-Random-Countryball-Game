local tweens = {}

function tweens.easeLinear(t)
    return t
end

function tweens.easeInQuad(t)
    return t * t
end

function tweens.easeOutQuad(t)
    return t * (2 - t)
end

function tweens.easeInOutQuad(t)
    return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
end

function tweens.easeInCubic(t)
    return t * t * t
end

function tweens.easeOutCubic(t)
    t = t - 1
    return t * t * t + 1
end

function tweens.easeInOutCubic(t)
    if t < 0.5 then
        return 4 * t * t * t
    else
        t = t - 1
        return 1 + 4 * t * t * t
    end
end

function tweens.easeInBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return c3 * t * t * t - c1 * t * t
end

function tweens.easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

function tweens.easeInOutBack(t)
    local c1 = 1.70158
    local c2 = c1 * 1.525

    if t < 0.5 then
        return (2 * t) ^ 2 * ((c2 + 1) * 2 * t - c2) / 2
    else
        return ((2 * t - 2) ^ 2 * ((c2 + 1) * (2 * t - 2) + c2) + 2) / 2
    end
end

function tweens.easeInExpo(t)
    if t == 0 then
        return 0
    end

    return 2 ^ (20 * t - 10)
end

function tweens.easeOutExpo(t)
    if t == 1 then
        return 1
    end

    return 1 - 2 ^ (-20 * t)
end

function tweens.easeInOutExpo(t)
    if t == 0 then
        return 0
    elseif t == 1 then
        return 1
    elseif t < 0.5 then
        return 2 ^ (20 * t - 10) / 2
    else
        return (2 - 2 ^ (-20 * t + 10)) / 2
    end
end

function tweens.easeInCirc(t)
    return 1 - math.sqrt(1 - t * t)
end

function tweens.easeOutCirc(t)
    return math.sqrt(1 - (t - 1) * (t - 1))
end

function tweens.easeInOutCirc(t)
    if t < 0.5 then
        return (1 - math.sqrt(1 - (2 * t) ^ 2)) / 2
    else
        return (math.sqrt(1 - (-2 * t + 2) ^ 2) + 1) / 2
    end
end
local activeTweens = {}

function tweens.to(target, property, to, duration, ease, onComplete)
    local from = target[property]
    local tween = {
        target = target,
        property = property,
        from = from,
        to = to,
        duration = duration,
        time = 0,
        ease = ease or tweens.easeLinear,
        onComplete = onComplete,
        order = #activeTweens + 1
    }
    table.insert(activeTweens, tween)
    return tween
end

function tweens.update(dt)
    for i = #activeTweens, 1, -1 do
        local tween = activeTweens[i]
        tween.time = tween.time + dt

        local progress = tween.time / tween.duration

        if progress > 1 then
            progress = 1
        end

        local eased = tween.ease(progress)

        local value = tween.from + (tween.to - tween.from) * eased

        tween.target[tween.property] = value
        if tween.time >= tween.duration then
            tween.target[tween.property] = tween.to
            if tween.onComplete then
                tween.onComplete(tween)
            end
            table.remove(activeTweens, i)
        end
    end
end

function tweens.cancel(tween)
    for i = #activeTweens, 1, -1 do
        if activeTweens[i] == tween then
            table.remove(activeTweens, i)
            return
        end
    end
end

function tweens.cancelProperty(target, property)
    for i = #activeTweens, 1, -1 do
        local tween = activeTweens[i]

        if tween.target == target
        and tween.property == property then
            table.remove(activeTweens, i)
        end
    end
end

function tweens.cancelAll()
    activeTweens = {}
end

function tweens.expEase(current, target, speed, dt)
    return current + (target - current) * (1 - math.exp(-speed * dt))
end

return tweens