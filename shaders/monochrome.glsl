extern vec3 cameraPosition;
extern vec4 cameraRotation;
extern vec2 cameraProjection;
extern bool useTerrainProjection;

const float NEAR = 0.1;
const float FAR = 100.0;
const float CLIP_A = (FAR + NEAR) / (FAR - NEAR);
const float CLIP_B = (2.0 * FAR * NEAR) / (FAR - NEAR);

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    if (!useTerrainProjection) {
        return transform_projection * vertex_position;
    }

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

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords) * color;
    float luma = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
    return vec4(vec3(luma), pixel.a);
}