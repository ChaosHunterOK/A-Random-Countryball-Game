extern vec3 cameraPosition;
extern vec4 cameraRotation;
extern vec2 cameraProjection;
extern float time;
extern vec2 uvOffset;

const float NEAR = 0.1;
const float FAR = 100.0;
const float CLIP_A = (FAR + NEAR) / (FAR - NEAR);
const float CLIP_B = (2.0 * FAR * NEAR) / (FAR - NEAR);

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec3 delta = vertex_position.xyz - cameraPosition;
    float x1 = delta.x * cameraRotation.x - delta.z * cameraRotation.y;
    float z1 = delta.x * cameraRotation.y + delta.z * cameraRotation.x;
    float y1 = delta.y * cameraRotation.z - z1 * cameraRotation.w;
    float z2 = delta.y * cameraRotation.w + z1 * cameraRotation.z;
    float clipZ = CLIP_A * z2 - CLIP_B;
    return vec4(
        x1 * cameraProjection.x,
        y1 * cameraProjection.y,
        clipZ,
        z2
    );
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 wave = vec2(sin((tc.y + time) * 6.0), cos((tc.x + time) * 6.0)) * 0.02;
    vec2 tc2 = tc + uvOffset + wave;
    vec4 pix = Texel(tex, tc2);
    return pix * color;
}
