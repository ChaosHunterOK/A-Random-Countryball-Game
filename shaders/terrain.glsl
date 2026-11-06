extern vec3 cameraPosition;
extern vec4 cameraRotation;
//xy = precomputed (f/aspect, f)
extern vec2 cameraProjection;
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

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    return Texel(tex, texture_coords) * color;
}