import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACK_META = ROOT / "pack.mcmeta"
LIGHTMAP_SHADER = ROOT / "assets/minecraft/shaders/core/lightmap.fsh"
GENERAL_SHADER = ROOT / "assets/flirty_beta/shaders/include/general.glsl"


def read_text(path):
    return path.read_text(encoding="utf-8")


def compact(text):
    return re.sub(r"\s+", " ", text).strip()


class ResourcePackStructureTests(unittest.TestCase):
    def test_required_pack_files_exist(self):
        self.assertTrue(PACK_META.is_file())
        self.assertTrue((ROOT / "pack.png").is_file())
        self.assertTrue(LIGHTMAP_SHADER.is_file())
        self.assertTrue(GENERAL_SHADER.is_file())

    def test_pack_metadata_matches_current_pack(self):
        metadata = json.loads(read_text(PACK_META))

        self.assertEqual(metadata["pack"]["description"], "Flirty Beta")
        self.assertEqual(metadata["pack"]["pack_format"], 75)
        self.assertEqual(metadata["pack"]["supported_formats"], [75, 75])

    def test_lightmap_imports_flirty_beta_include(self):
        shader = read_text(LIGHTMAP_SHADER)

        self.assertIn("#moj_import <flirty_beta:general.glsl>", shader)


class ShaderBehaviorTests(unittest.TestCase):
    def setUp(self):
        self.lightmap = compact(read_text(LIGHTMAP_SHADER))
        self.general = compact(read_text(GENERAL_SHADER))

    def test_helper_function_names_are_flirty_beta_prefixed(self):
        shader = read_text(GENERAL_SHADER)
        declarations = re.findall(r"^(?:float|vec4)\s+(flirty_beta_[A-Za-z0-9_]+)\(", shader, re.MULTILINE)

        self.assertEqual(
            declarations,
            [
                "flirty_beta_texture",
                "flirty_beta_light",
                "flirty_beta_linear_range_fog_factor",
                "flirty_beta_linear_fog_factor",
                "flirty_beta_nether_fog_factor",
                "flirty_beta_exp_fog_factor",
                "flirty_beta_exp_fog_density",
                "flirty_beta_terrain_fog_factor",
                "flirty_beta_apply_fog",
                "flirty_beta_linear_sky_fog_factor",
                "flirty_beta_apply_sky_fog",
            ],
        )

    def test_light_formula_is_unchanged(self):
        self.assertIn(
            compact(
                """
                float flirty_beta_light(float light_level, float ambient) {
                    float darkness = 1.0 - light_level;
                    float lit_amount = 1.0 - darkness;
                    float falloff = darkness * 3.0 + 1.0;
                    return lit_amount / falloff * (1.0 - ambient) + ambient;
                }
                """
            ),
            self.general,
        )

    def test_texture_sampling_formula_is_unchanged(self):
        self.assertIn(
            compact(
                """
                vec4 flirty_beta_texture(sampler2D source, vec2 uv, vec2 pixel_size) {
                    vec2 pixel_uv = floor(uv * pixel_size) + 0.5;
                    return texture(source, pixel_uv / pixel_size);
                }
                """
            ),
            self.general,
        )

    def test_fog_formulas_are_unchanged(self):
        expected_snippets = [
            "const float FLIRTY_BETA_OVERWORLD_FOG_START_SCALE = 0.25;",
            "const float FLIRTY_BETA_ENVIRONMENT_END_CUTOFF = 96.0;",
            "const float FLIRTY_BETA_NETHER_ENVIRONMENT_START = 10.0;",
            "const float FLIRTY_BETA_END_BOSS_ENVIRONMENT_START = 0.0;",
            "const vec3 FLIRTY_BETA_LAVA_FOG_THRESHOLD = vec3(0.6, 0.1, 0.0);",
            "return clamp((vertex_distance - fog_start) / (fog_end - fog_start), 0.0, 1.0);",
            "float fog_start = fog_end * FLIRTY_BETA_OVERWORLD_FOG_START_SCALE;",
            "return flirty_beta_linear_range_fog_factor(vertex_distance, 0.0, fog_end);",
            "float visible_amount = clamp(exp(-density * vertex_distance), 0.0, 1.0); return 1.0 - visible_amount;",
            "bool in_lava = fog_color.r >= FLIRTY_BETA_LAVA_FOG_THRESHOLD.r && fog_color.g <= FLIRTY_BETA_LAVA_FOG_THRESHOLD.g && fog_color.b == FLIRTY_BETA_LAVA_FOG_THRESHOLD.b;",
            "return in_lava ? 2.0 : 0.1;",
            "if(environment_end > FLIRTY_BETA_ENVIRONMENT_END_CUTOFF) { return flirty_beta_linear_fog_factor(vertex_distance, render_distance);",
            "if(environment_end == FLIRTY_BETA_ENVIRONMENT_END_CUTOFF && environment_start == FLIRTY_BETA_NETHER_ENVIRONMENT_START) { return flirty_beta_nether_fog_factor(vertex_distance, render_distance);",
            "if(environment_end == FLIRTY_BETA_ENVIRONMENT_END_CUTOFF && environment_start == FLIRTY_BETA_END_BOSS_ENVIRONMENT_START) { return flirty_beta_linear_fog_factor(vertex_distance, render_distance);",
            "return flirty_beta_exp_fog_factor(vertex_distance, flirty_beta_exp_fog_density(fog_color));",
        ]

        for snippet in expected_snippets:
            with self.subTest(snippet=snippet):
                self.assertIn(compact(snippet), self.general)

    def test_sky_fog_formula_is_unchanged(self):
        expected_snippets = [
            "const float FLIRTY_BETA_SKY_FOG_END_SCALE = 0.8;",
            "const float FLIRTY_BETA_SHORT_SKY_FOG_END = 64.0;",
            "if(fog_end <= FLIRTY_BETA_SHORT_SKY_FOG_END) { return 1.0; }",
            "float scaled_fog_end = fog_end * FLIRTY_BETA_SKY_FOG_END_SCALE;",
            "return flirty_beta_linear_range_fog_factor(vertex_distance, 0.0, scaled_fog_end);",
            "float fog_end = min(render_distance, environment_distance);",
            "float factor = flirty_beta_linear_sky_fog_factor(vertex_distance, fog_end);",
        ]

        for snippet in expected_snippets:
            with self.subTest(snippet=snippet):
                self.assertIn(compact(snippet), self.general)

    def test_lightmap_pipeline_is_unchanged(self):
        expected_snippets = [
            "float block_level = floor(texCoord.x * 16) / 15;",
            "float sky_level = floor(texCoord.y * 16) * lightmapInfo.SkyFactor / 15;",
            "float light_level = max(block_level, sky_level); light_level = clamp(light_level, 0.0, 1.0);",
            "light_level = floor(light_level * 15 + 0.5) / 15;",
            "float ambient = 0.05;",
            "float ambient = ((lightmapInfo.AmbientColor.r + lightmapInfo.AmbientColor.g + lightmapInfo.AmbientColor.b) / 3 + 0.01) * lightmapInfo.AmbientLightFactor;",
            "vec3 color = vec3(flirty_beta_light(light_level, max(ambient, 0.05)));",
            "color = mix(color, color * max(light_level, 0.4), lightmapInfo.DarkenWorldFactor);",
            "color = color - vec3(lightmapInfo.DarknessScale);",
            "vec3 gamma_color = notGamma(color); color = mix(color, gamma_color, lightmapInfo.BrightnessFactor);",
            "color = color + vec3(1.0) * lightmapInfo.NightVisionFactor;",
            "fragColor = vec4(color, 1.0);",
        ]

        for snippet in expected_snippets:
            with self.subTest(snippet=snippet):
                self.assertIn(compact(snippet), self.lightmap)

    def test_comment_style_only_uses_block_function_headers(self):
        for path in (LIGHTMAP_SHADER, GENERAL_SHADER):
            shader = read_text(path)

            with self.subTest(path=path):
                self.assertNotIn("//", shader)
                self.assertEqual(shader.count("/*"), shader.count("*/"))


if __name__ == "__main__":
    unittest.main()
