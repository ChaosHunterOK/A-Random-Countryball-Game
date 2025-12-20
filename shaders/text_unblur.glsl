uniform float threshold;
uniform vec4 tintColor;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px)
{
    vec4 texColor = Texel(tex, uv);
    float alpha = clamp(sign(texColor.a - threshold) + 1.0, 0.0, 1.0);
    return vec4(tintColor.rgb, alpha) * color;
}