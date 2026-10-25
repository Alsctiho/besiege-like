import array
import unittest

from verify_capture import analyze_audio_pcm, scan_log


class LogDetectionTests(unittest.TestCase):
    def test_error_and_warning_are_separate(self):
        records = scan_log("ERROR: broken\n at: run()\nWARNING: unused\n")
        self.assertEqual([record["severity"] for record in records], ["error", "warning"])
        self.assertEqual(records[0]["line"], 1)

    def test_parser_shader_and_script_errors(self):
        records = scan_log("SCRIPT ERROR: bad call\nParse Error: invalid\nShader Error: invalid\n")
        self.assertEqual(len(records), 3)
        self.assertTrue(all(record["severity"] == "error" for record in records))

    def test_ansi_case_and_false_positives(self):
        records = scan_log("\x1b[31merror: real\x1b[0m\n[SELFVERIFY] PASS no errors\nerrors=0\n")
        self.assertEqual(len(records), 1)

    def test_reads_full_log_not_just_last_fifty_lines(self):
        records = scan_log("ERROR: first frame\n" + "ordinary output\n" * 200)
        self.assertEqual(len(records), 1)

    def test_empty_log_has_no_diagnostics(self):
        self.assertEqual(scan_log(""), [])


class AudioDetectionTests(unittest.TestCase):
    def test_missing_and_silent_audio_fail(self):
        self.assertFalse(analyze_audio_pcm(b"")["passed"])
        self.assertFalse(analyze_audio_pcm(array.array("f", [0.0] * 100).tobytes())["passed"])

    def test_real_signal_passes(self):
        self.assertTrue(analyze_audio_pcm(array.array("f", [0.1, -0.1] * 100).tobytes())["passed"])

    def test_clipped_and_invalid_audio_fail(self):
        self.assertFalse(analyze_audio_pcm(array.array("f", [1.0, -1.0] * 100).tobytes())["passed"])
        self.assertFalse(analyze_audio_pcm(array.array("f", [float("nan")]).tobytes())["passed"])


if __name__ == "__main__":
    unittest.main()
