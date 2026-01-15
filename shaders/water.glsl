extern float time;
extern vec2 uvOffset;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 wave = vec2(sin((tc.y + time) * 6.0), cos((tc.x + time) * 6.0)) * 0.02;
    vec2 tc2 = tc + uvOffset + wave;
    vec4 pix = Texel(tex, tc2);
    return pix * color;
}
