local ffi = pcall(require, "ffi") and require("ffi") or nil
local osname = love.system.getOS()
local gl = nil

if ffi then
    ffi.cdef[[
        typedef unsigned int GLenum;
        typedef unsigned char GLboolean;
        typedef unsigned int GLbitfield;
        typedef void GLvoid;
        typedef signed int GLint;
        typedef unsigned int GLuint;
        typedef int GLsizei;
        typedef float GLfloat;
        typedef double GLdouble;
        typedef unsigned char GLubyte;

        void glEnable(GLenum cap);
        void glDisable(GLenum cap);
        void glHint(GLenum target, GLenum mode);
        void glDepthMask(GLboolean flag);
        void glDepthFunc(GLenum func);
        void glBlendFunc(GLenum sfactor, GLenum dfactor);
        void glClear(GLbitfield mask);
        void glClearColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);

        void glBegin(GLenum mode);
        void glEnd(void);
        void glVertex2f(GLfloat x, GLfloat y);
        void glVertex3f(GLfloat x, GLfloat y, GLfloat z);
        void glColor3f(GLfloat r, GLfloat g, GLfloat b);
        void glColor4f(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
        void glTexCoord2f(GLfloat s, GLfloat t);

        void glMatrixMode(GLenum mode);
        void glLoadIdentity(void);
        void glTranslatef(GLfloat x, GLfloat y, GLfloat z);
        void glRotatef(GLfloat angle, GLfloat x, GLfloat y, GLfloat z);
        void glScalef(GLfloat x, GLfloat y, GLfloat z);

        void glGenTextures(GLsizei n, GLuint *textures);
        void glBindTexture(GLenum target, GLuint texture);
        void glTexParameteri(GLenum target, GLenum pname, GLint param);
        void glTexImage2D(GLenum target, GLint level, GLint internalformat,
                          GLsizei width, GLsizei height, GLint border,
                          GLenum format, GLenum type, const GLvoid *pixels);
        void glDeleteTextures(GLsizei n, const GLuint *textures);
        void glViewport(GLint x, GLint y, GLsizei width, GLsizei height);

        void glGenBuffers(GLsizei n, GLuint *buffers);
        void glBindBuffer(GLenum target, GLuint buffer);
        void glBufferData(GLenum target, GLsizei size, const GLvoid *data, GLenum usage);
        void glDeleteBuffers(GLsizei n, const GLuint *buffers);

        void glEnableVertexAttribArray(GLuint index);
        void glDisableVertexAttribArray(GLuint index);
        void glVertexAttribPointer(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const GLvoid *pointer);

        void glGenVertexArrays(GLsizei n, GLuint *arrays);
        void glBindVertexArray(GLuint array);

        void glCullFace(GLenum mode);
        void glFrontFace(GLenum mode);
    ]]

    local function tryLoadLib(lib)
        local ok, handle = pcall(ffi.load, lib)
        return ok and handle or nil
    end

    if osname == "Windows" then
        gl = tryLoadLib("opengl32")
    elseif osname == "OS X" or osname == "macOS" then
        gl = tryLoadLib("/System/Library/Frameworks/OpenGL.framework/OpenGL")
    elseif osname == "Linux" then
        gl = tryLoadLib("GL") or tryLoadLib("libGL.so.1")
    end

    if gl and not pcall(function() return gl.glEnable end) then
        print("[OpenGL] Warning: glEnable not found, fallback to LÖVE renderer.")
        gl = nil
    end
else
    print("[OpenGL] FFI not available; using LÖVE renderer.")
end

local GL = {
    DEPTH_TEST = 0x0B71,
    CULL_FACE = 0x0B44,
    FRONT = 0x0404,
    BACK = 0x0405,
    FRONT_AND_BACK = 0x0408,
    CCW = 0x0901,
    CW = 0x0900,

    BLEND = 0x0BE2,
    LEQUAL = 0x0203,
    SRC_ALPHA = 0x0302,
    ONE_MINUS_SRC_ALPHA = 0x0303,
    FASTEST = 0x1101,
    COLOR_BUFFER_BIT = 0x00004000,
    DEPTH_BUFFER_BIT = 0x00000100,
    TRIANGLES = 0x0004,
    QUADS = 0x0007,
    MODELVIEW = 0x1700,
    PROJECTION = 0x1701,
    TEXTURE_2D = 0x0DE1,
    TEXTURE_MIN_FILTER = 0x2801,
    TEXTURE_MAG_FILTER = 0x2800,
    TEXTURE_WRAP_S = 0x2802,
    TEXTURE_WRAP_T = 0x2803,
    REPEAT = 0x2901,
    CLAMP = 0x2900,
    LINEAR = 0x2601,
    NEAREST = 0x2600,
    RGBA = 0x1908,
    UNSIGNED_BYTE = 0x1401,
    ARRAY_BUFFER = 0x8892,
    ELEMENT_ARRAY_BUFFER = 0x8893,
    STATIC_DRAW = 0x88E4,
    DYNAMIC_DRAW = 0x88E8
}

local function initGL()
    love.window.setMode(0, 0, {
        vsync = 1,
        msaa = 0,
        depth = 24,
        stencil = true,
        resizable = false,
        highdpi = (osname == "OS X" or osname == "macOS"),
    })

    if gl then
        pcall(gl.glEnable, GL.DEPTH_TEST)
        pcall(gl.glDepthFunc, GL.LEQUAL)
        pcall(gl.glDepthMask, true)
        pcall(gl.glEnable, GL.CULL_FACE)
        pcall(gl.glCullFace, GL.BACK)
        pcall(gl.glFrontFace, GL.CCW)
        pcall(gl.glEnable, GL.BLEND)
        pcall(gl.glBlendFunc, GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
        for i = 0x0C50, 0x0C54 do
            pcall(gl.glHint, i, GL.FASTEST)
        end

        print(string.format("[OpenGL] Native OpenGL context active (%s) with CULL_FACE (GL_BACK)", osname))
    else
        love.graphics.setDepthMode("lequal", true)
        love.graphics.setFrontFaceWinding("ccw")
        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.setDefaultFilter("nearest", "nearest")
        print(string.format("[OpenGL] Using fallback Love2D renderer (%s)", osname))
    end

    collectgarbage("setpause", 110)
    collectgarbage("setstepmul", 200)
end

return {
    init = initGL,
    gl = gl,
    GL = GL
}