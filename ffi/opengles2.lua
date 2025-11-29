local M = {}
local ok_ffi, ffi = pcall(require, "ffi")

local lg = love.graphics
local ls = love.system
local lw = love.window

local osname = ls.getOS()
local gl = nil
local using_ffi = false
local is_gles = false
local renderer_info = nil

local GL_DEPTH_TEST = 0x0B71
local GL_CULL_FACE = 0x0B44
local GL_BLEND = 0x0BE2
local GL_LEQUAL = 0x0203
local GL_SRC_ALPHA = 0x0302
local GL_ONE_MINUS_SRC_ALPHA = 0x0303
local GL_FASTEST = 0x1101
local GL_BACK = 0x0405
local GL_LINE_SMOOTH = 0x0B20
local GL_SMOOTH = 0x1D01
local GL_POLYGON_OFFSET_FILL = 0x8037
local GL_COLOR_BUFFER_BIT = 0x4000
local GL_DEPTH_BUFFER_BIT = 0x0100
local GL_HINT_TARGET_LINE_SMOOTH = 0x0C52
local GL_HINT_TARGET_POLYGON_OFFSET = 0x0A22
local GL_NICEST = 0x1102

M.GL_DEPTH_TEST = GL_DEPTH_TEST
M.GL_CULL_FACE = GL_CULL_FACE
M.GL_BLEND = GL_BLEND
M.GL_LEQUAL = GL_LEQUAL
M.GL_SRC_ALPHA = GL_SRC_ALPHA
M.GL_ONE_MINUS_SRC_ALPHA = GL_ONE_MINUS_SRC_ALPHA
M.GL_FASTEST = GL_FASTEST
M.GL_BACK = GL_BACK
M.GL_LINE_SMOOTH = GL_LINE_SMOOTH
M.GL_SMOOTH = GL_SMOOTH
M.GL_POLYGON_OFFSET_FILL = GL_POLYGON_OFFSET_FILL
M.GL_COLOR_BUFFER_BIT = GL_COLOR_BUFFER_BIT
M.GL_DEPTH_BUFFER_BIT = GL_DEPTH_BUFFER_BIT
M.GL_LINE_SMOOTH_HINT = GL_HINT_TARGET_LINE_SMOOTH
M.GL_POLYGON_SMOOTH_HINT = GL_HINT_TARGET_POLYGON_OFFSET
M.GL_NICEST = GL_NICEST

local function detect_renderer()
    local ok, info = pcall(lg.getRendererInfo)
    if ok and info then
        renderer_info = info
        local v = tostring(info.version or ""):lower()
        is_gles = (v:find("gles") ~= nil)
        return
    end
    is_gles = (osname == "Android" or osname == "iOS")
end

local function setup_ffi()
    if not ok_ffi then return end
    if osname == "Android" or osname == "iOS" then return end

    ffi.cdef[[
        typedef unsigned int GLenum;
        typedef unsigned char GLboolean;
        void glEnable(GLenum cap);
        void glDisable(GLenum cap);
        void glDepthFunc(GLenum func);
        void glDepthMask(GLboolean flag);
        void glBlendFunc(GLenum s, GLenum d);
        void glHint(GLenum target, GLenum mode);
        void glShadeModel(GLenum mode);
        void glCullFace(GLenum mode);
        void glPolygonOffset(float factor, float units);
        void glColorMask(GLboolean r, GLboolean g, GLboolean b, GLboolean a);
    ]]

    local lib
    if osname == "Windows" then
        lib = ffi.load("opengl32")
    elseif osname == "Linux" then
        lib = ffi.load("GL")
    elseif osname:find("OS X") or osname:find("macOS") then
        lib = ffi.load("/System/Library/Frameworks/OpenGL.framework/OpenGL")
    end

    if lib then
        gl = lib
        using_ffi = true
    end
end

local setBlendMode = lg.setBlendMode
local setDepthMode = lg.setDepthMode
local setFrontFaceWinding = lg.setFrontFaceWinding

local function fallback_enable(cap)
    if cap == GL_BLEND then
        setBlendMode("alpha")
    elseif cap == GL_CULL_FACE then
        setFrontFaceWinding("ccw")
    elseif cap == GL_DEPTH_TEST then
        setDepthMode("lequal", true)
    elseif cap == GL_LINE_SMOOTH then
    elseif cap == GL_POLYGON_OFFSET_FILL then

    end
end

local function fallback_disable(cap)
    if cap == GL_DEPTH_TEST then
        setDepthMode("less", false)
    end
end

local function gl_enable(cap)
    if using_ffi then gl.glEnable(cap) else fallback_enable(cap) end
end

local function gl_disable(cap)
    if using_ffi then gl.glDisable(cap) else fallback_disable(cap) end
end

local function gl_blend(s, d)
    if using_ffi then gl.glBlendFunc(s, d) end
end

local function gl_depthfunc(f)
    if using_ffi then gl.glDepthFunc(f)
    else setDepthMode(f == GL_LEQUAL and "lequal" or "less", true) end
end

local function gl_depthmask(flag)
    if using_ffi then gl.glDepthMask(flag and 1 or 0)
    else setDepthMode("lequal", flag) end
end

local function gl_hint(t, m)
    if using_ffi then gl.glHint(t, m) end
end

local function gl_shademodel(mode)
    if using_ffi then gl.glShadeModel(mode) end
end

local function gl_cullface(mode)
    if using_ffi then gl.glCullFace(mode) end
end

local function gl_polygonoffset(factor, units)
    if using_ffi then
        gl.glPolygonOffset(factor, units)
    end
end

local function gl_colormask(r, g, b, a)
    if using_ffi then
        gl.glColorMask(
            r and 1 or 0,
            g and 1 or 0,
            b and 1 or 0,
            a and 1 or 0
        )
    end
end

function M.init(opts)
    opts = opts or {}

    detect_renderer()
    setup_ffi()
    gl_enable(GL_DEPTH_TEST)
    gl_depthfunc(GL_LEQUAL)
    gl_depthmask(true)

    gl_enable(GL_CULL_FACE)
    gl_cullface(GL_BACK)

    gl_enable(GL_BLEND)
    gl_blend(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    gl_enable(GL_LINE_SMOOTH)
    gl_hint(GL_LINE_SMOOTH, GL_FASTEST)

    gl_enable(GL_POLYGON_OFFSET_FILL)
    gl_hint(0x8037, GL_FASTEST)

    gl_shademodel(GL_SMOOTH)

    lw.setMode(0, 0, {
        vsync = opts.vsync or 1,
        msaa = opts.msaa or 0,
        depth = opts.depth or 24,
        stencil = opts.stencil ~= false,
        highdpi = (osname == "OS X" or osname == "macOS")
    })

    collectgarbage("setpause", opts.gc_pause or 110)
    collectgarbage("setstepmul", opts.gc_stepmul or 200)

    print("[glcompat] init: os="..osname.." ffi="..tostring(using_ffi) ..
        " gles="..tostring(is_gles) ..
        " renderer="..tostring(renderer_info and renderer_info.renderer or "unknown"))
end

M.enable = gl_enable
M.disable = gl_disable
M.blendFunc = gl_blend
M.depthFunc = gl_depthfunc
M.depthMask = gl_depthmask
M.hint = gl_hint
M.shadeModel = gl_shademodel
M.cullFace = gl_cullface
M.polygonOffset = gl_polygonoffset
M.colorMask = gl_colormask

function M.isGLES() return is_gles end
function M.usingFFI() return using_ffi end
function M.info()
    return {
        os = osname,
        using_ffi = using_ffi,
        is_gles = is_gles,
        renderer_info = renderer_info
    }
end

M._gl = gl
M._ffi = ffi

return M