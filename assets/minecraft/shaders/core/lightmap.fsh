#version 330

#define QUANTIZE_LIGHT 0
#define OVERRIDE_AMBIENT 0

#moj_import <flirty_beta:general.glsl>

layout(std140) uniform LightmapInfo {
    float AmbientLightFactor;
    float SkyFactor;
    float BlockFactor;
    float NightVisionFactor;
    float DarknessScale;
    float DarkenWorldFactor;
    float BrightnessFactor;
    vec3 SkyLightColor;
    vec3 AmbientColor;
} lightmapInfo;

in vec2 texCoord;

out vec4 fragColor;

/*
 * Returns squared brightness for a light level.
 */
float get_brightness(float level) {
    return pow(level, 2);
}

/*
 * Applies the cubic brightness curve used for gamma adjustment.
 */
vec3 notGamma(vec3 color) {
    float max_component = max(max(color.x, color.y), color.z);
    float max_inverted = 1.0f - max_component;
    float max_scaled = 1.0f - max_inverted * max_inverted * max_inverted;
    return color * (max_scaled / max_component);
}

/*
 * Returns a parabolic blend factor for a light level.
 */
float parabolicMixFactor(float level) {
    return (2.0 * level - 1.0) * (2.0 * level - 1.0);
}

/*
 * Builds the final lightmap color from block light, sky light, and visual effects.
 */
void main() {
    float block_level = floor(texCoord.x * 16) / 15;
    float sky_level = floor(texCoord.y * 16) * lightmapInfo.SkyFactor / 15;

    float light_level = max(block_level, sky_level);
    light_level = clamp(light_level, 0.0, 1.0);

    #if QUANTIZE_LIGHT == 1
        light_level = floor(light_level * 15 + 0.5) / 15;
    #endif

    #if OVERRIDE_AMBIENT == 1
        float ambient = 0.05;
    #else
        float ambient = ((lightmapInfo.AmbientColor.r + lightmapInfo.AmbientColor.g + lightmapInfo.AmbientColor.b) / 3 + 0.01) * lightmapInfo.AmbientLightFactor;
    #endif

    vec3 color = vec3(flirty_beta_light(light_level, max(ambient, 0.05)));

    color = mix(color, color * max(light_level, 0.4), lightmapInfo.DarkenWorldFactor);

    color = color - vec3(lightmapInfo.DarknessScale);

    color = clamp(color, 0.0, 1.0);
    vec3 gamma_color = notGamma(color);
    color = mix(color, gamma_color, lightmapInfo.BrightnessFactor);

    if (lightmapInfo.NightVisionFactor > 0.0) {
        color = color + vec3(1.0) * lightmapInfo.NightVisionFactor;
    }

    fragColor = vec4(color, 1.0);
    return;
}
