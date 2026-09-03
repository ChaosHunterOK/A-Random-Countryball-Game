vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords) * color;
    float luma = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
    return vec4(vec3(luma), pixel.a);
}