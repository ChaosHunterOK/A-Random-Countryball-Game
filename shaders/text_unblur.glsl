uniform float threshold;
uniform float softness;
uniform vec4 tintColor;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px)
{
    vec4 texColor = Texel(tex, uv);
    if (texColor.a <= 0.001)
        return vec4(0.0);
    if (texColor.a >= 0.999)
        return texColor * color;
    float alpha = smoothstep(threshold - softness, threshold + softness, texColor.a);
    vec3 rgb = mix(texColor.rgb, tintColor.rgb, alpha);
    return vec4(rgb, alpha) * color;
}
