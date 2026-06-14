const float FLIRTY_BETA_OVERWORLD_FOG_START_SCALE = 0.25;
const float FLIRTY_BETA_SKY_FOG_END_SCALE = 0.8;
const float FLIRTY_BETA_SHORT_SKY_FOG_END = 64.0;
const float FLIRTY_BETA_ENVIRONMENT_END_CUTOFF = 96.0;
const float FLIRTY_BETA_NETHER_ENVIRONMENT_START = 10.0;
const float FLIRTY_BETA_END_BOSS_ENVIRONMENT_START = 0.0;
const vec3 FLIRTY_BETA_LAVA_FOG_THRESHOLD = vec3(0.6, 0.1, 0.0);

/*
 * Samples a texture with nearest-pixel coordinates.
 */
vec4 flirty_beta_texture(sampler2D source, vec2 uv, vec2 pixel_size) {
    vec2 pixel_uv = floor(uv * pixel_size) + 0.5;
    return texture(source, pixel_uv / pixel_size);
}

/*
 * Converts a light level and ambient value into beta-style brightness.
 */
float flirty_beta_light(float light_level, float ambient) {
    float darkness = 1.0 - light_level;
    float lit_amount = 1.0 - darkness;
    float falloff = darkness * 3.0 + 1.0;
    return lit_amount / falloff * (1.0 - ambient) + ambient;
}

/*
 * Calculates linear fog intensity between a start and end distance.
 */
float flirty_beta_linear_range_fog_factor(float vertex_distance, float fog_start, float fog_end) {
    if(vertex_distance <= fog_start) {
        return 0.0;
    }
    if(vertex_distance >= fog_end) {
        return 1.0;
    }
    return clamp((vertex_distance - fog_start) / (fog_end - fog_start), 0.0, 1.0);
}

/*
 * Calculates overworld-style linear fog intensity.
 */
float flirty_beta_linear_fog_factor(float vertex_distance, float fog_end) {
    float fog_start = fog_end * FLIRTY_BETA_OVERWORLD_FOG_START_SCALE;
    return flirty_beta_linear_range_fog_factor(vertex_distance, fog_start, fog_end);
}

/*
 * Calculates nether-style linear fog intensity.
 */
float flirty_beta_nether_fog_factor(float vertex_distance, float fog_end) {
    return flirty_beta_linear_range_fog_factor(vertex_distance, 0.0, fog_end);
}

/*
 * Calculates exponential fog intensity.
 */
float flirty_beta_exp_fog_factor(float vertex_distance, float density) {
    float visible_amount = clamp(exp(-density * vertex_distance), 0.0, 1.0);
    return 1.0 - visible_amount;
}

/*
 * Chooses the exponential fog density from the fog color.
 */
float flirty_beta_exp_fog_density(vec4 fog_color) {
    bool in_lava = fog_color.r >= FLIRTY_BETA_LAVA_FOG_THRESHOLD.r && fog_color.g <= FLIRTY_BETA_LAVA_FOG_THRESHOLD.g && fog_color.b == FLIRTY_BETA_LAVA_FOG_THRESHOLD.b;
    return in_lava ? 2.0 : 0.1;
}

/*
 * Calculates terrain fog intensity from the active environment range.
 */
float flirty_beta_terrain_fog_factor(float vertex_distance, float render_distance, float environment_start, float environment_end, vec4 fog_color) {
    if(environment_end > FLIRTY_BETA_ENVIRONMENT_END_CUTOFF) {
        return flirty_beta_linear_fog_factor(vertex_distance, render_distance);
    }
    if(environment_end == FLIRTY_BETA_ENVIRONMENT_END_CUTOFF && environment_start == FLIRTY_BETA_NETHER_ENVIRONMENT_START) {
        return flirty_beta_nether_fog_factor(vertex_distance, render_distance);
    }
    if(environment_end == FLIRTY_BETA_ENVIRONMENT_END_CUTOFF && environment_start == FLIRTY_BETA_END_BOSS_ENVIRONMENT_START) {
        return flirty_beta_linear_fog_factor(vertex_distance, render_distance);
    }

    return flirty_beta_exp_fog_factor(vertex_distance, flirty_beta_exp_fog_density(fog_color));
}

/*
 * Applies terrain fog based on the active environment range and fog color.
 */
vec4 flirty_beta_apply_fog(vec4 color, float vertex_distance, float render_distance, float environment_start, float environment_end, vec4 fog_color) {
    if(fog_color.a <= 0.0) {
        return color;
    }

    float factor = flirty_beta_terrain_fog_factor(vertex_distance, render_distance, environment_start, environment_end, fog_color);
    return vec4(mix(color.rgb, fog_color.rgb, factor), color.a);
}

/*
 * Calculates beta-style sky fog intensity.
 */
float flirty_beta_linear_sky_fog_factor(float vertex_distance, float fog_end) {
    if(fog_end <= FLIRTY_BETA_SHORT_SKY_FOG_END) {
        return 1.0;
    }

    float scaled_fog_end = fog_end * FLIRTY_BETA_SKY_FOG_END_SCALE;
    return flirty_beta_linear_range_fog_factor(vertex_distance, 0.0, scaled_fog_end);
}

/*
 * Applies sky fog using the smaller render or environment distance.
 */
vec4 flirty_beta_apply_sky_fog(vec4 color, float vertex_distance, float render_distance, float environment_distance, vec4 fog_color) {
    if(fog_color.a <= 0.0) {
        return color;
    }

    float fog_end = min(render_distance, environment_distance);
    float factor = flirty_beta_linear_sky_fog_factor(vertex_distance, fog_end);
    return vec4(mix(color.rgb, fog_color.rgb, factor), color.a);
}
