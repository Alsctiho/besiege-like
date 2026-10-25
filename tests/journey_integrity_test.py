from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CurrentProjectIntegrityTests(unittest.TestCase):
    def test_entry_and_autoloads_exist(self):
        config = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn('run/main_scene="res://scenes/core_journey.tscn"', config)
        self.assertNotRegex(config, r"(?m)^Game=")
        for target in re.findall(r'res://([A-Za-z0-9_./-]+)', config):
            self.assertTrue((ROOT / target).exists(), target)

    def test_current_resource_paths_exist(self):
        files = list((ROOT / "scripts/adventure").glob("*.gd"))
        files += list((ROOT / "scenes").glob("*.tscn"))
        files += list((ROOT / "tests").glob("journey*.gd"))
        for source in files:
            for line in source.read_text(encoding="utf-8").splitlines():
                if line.lstrip().startswith("#"):
                    continue
                for target in re.findall(r'res://([A-Za-z0-9_./-]+)', line):
                    self.assertTrue((ROOT / target).exists(), f"{source.relative_to(ROOT)} -> {target}")

    def test_removed_sandbox_is_not_a_second_runtime(self):
        scenes = sorted(path.name for path in (ROOT / "scenes").glob("*.tscn"))
        self.assertEqual(scenes, ["core_journey.tscn"])
        for folder in ["scripts/core", "scripts/blocks", "scripts/world", "scripts/ui", "assets/models", "shaders", "docs/design/v0.1", "generated-images"]:
            self.assertFalse((ROOT / folder).exists(), folder)
        self.assertTrue(all(path.name.startswith("journey") for path in (ROOT / "tests").glob("*.gd")))

    def test_current_source_assets_and_plugin_preserved(self):
        for target in ["generated-assets/core-robot/core_robot.blend", "generated-assets/core-robot/adventure_components.blend", "generated-assets/audio-sample-v01/build_audio.py", "assets/adventure/models/core.glb", "assets/adventure/audio/music/windworn_viaduct.ogg", "addons/godot_mcp/LICENSE", ".codebuddy/skills/automate/besiege-self-verify/SKILL.md"]:
            self.assertTrue((ROOT / target).is_file(), target)

    def test_readme_links_still_resolve(self):
        source = ROOT / "README.md"
        for target in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', source.read_text(encoding="utf-8")):
            if target.startswith(("https://", "http://", "#")):
                continue
            self.assertTrue((source.parent / target).exists(), target)


if __name__ == "__main__":
    unittest.main()
