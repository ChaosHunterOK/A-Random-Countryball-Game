local lg = love.graphics
local Transition = {}

Transition.state = {
    mode = nil, -- "fadeOut", "fadeIn", "idle"
    duration = 0.5,
    progress = 0,
    callback = nil,
    alpha = 0
}

Transition.slide = {
    duration = 0.6,
    progress = 0,
    active = false,
    callback = nil,
    direction = "left",
    distance = 100
}

local function safeDuration(d)
    return (d and d > 0) and d or 0.001
end

local function easeInOut(t)
    return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
end
function Transition.startFade(duration, callback)
    Transition.state.mode = "fadeOut"
    Transition.state.duration = duration or 0.5
    Transition.state.progress = 0
    Transition.state.callback = callback
    Transition.state.alpha = 0
end
function Transition.startSlide(direction, duration, callback)
    Transition.slide.direction = direction or "left"
    Transition.slide.duration = duration or 0.6
    Transition.slide.progress = 0
    Transition.slide.active = true
    Transition.slide.callback = callback
end

function Transition.update(dt)
    local st = Transition.state
    if st.mode == "fadeOut" then
        st.progress = st.progress + dt / safeDuration(st.duration)

        if st.progress >= 1 then
            st.progress = 1
            st.alpha = 1

            if st.callback then
                st.callback()
            end

            -- immediately go into fade in
            st.mode = "fadeIn"
            st.progress = 0
        else
            st.alpha = easeInOut(st.progress)
        end

    elseif st.mode == "fadeIn" then
        st.progress = st.progress + dt / safeDuration(st.duration)

        if st.progress >= 1 then
            st.progress = 1
            st.alpha = 0
            st.mode = "idle"
        else
            st.alpha = 1 - easeInOut(st.progress)
        end
    end
    if Transition.slide.active then
        local s = Transition.slide
        s.progress = s.progress + dt / safeDuration(s.duration)

        if s.progress >= 1 then
            s.progress = 1
            s.active = false
            if s.callback then s.callback() end
        end
    end
end

function Transition.draw(width, height)
    local st = Transition.state

    if st.mode == "fadeOut" or st.mode == "fadeIn" then
        lg.setColor(0, 0, 0, st.alpha)
        lg.rectangle("fill", 0, 0, width, height)
        lg.setColor(1, 1, 1, 1)
    end
    if Transition.slide.active then
        local s = Transition.slide
        local t = easeInOut(s.progress)

        local dir = (s.direction == "left") and -1 or 1
        local offset = s.distance * (1 - t) * dir

        lg.push()
        lg.translate(offset, 0)

        lg.setColor(0, 0, 0, t * 0.5)
        lg.rectangle("fill", -offset, 0, width, height)

        lg.pop()
        lg.setColor(1, 1, 1, 1)
    end
end

function Transition.isTransitioning()
    return Transition.state.mode ~= "idle"
        or Transition.slide.active
end

function Transition.reset()
    Transition.state.mode = "idle"
    Transition.state.progress = 0
    Transition.state.alpha = 0
    Transition.state.callback = nil

    Transition.slide.progress = 0
    Transition.slide.active = false
    Transition.slide.callback = nil
end

return Transition