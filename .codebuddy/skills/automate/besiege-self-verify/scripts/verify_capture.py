import argparse
import array
import math
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[5]
ASSET_ROOT = Path(__file__).resolve().parent.parent / "assets"
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
DIAGNOSTIC = re.compile(
    r"^\s*(?P<kind>(?:SCRIPT|COMPILE)\s+ERROR|(?:Parse|Parser|Shader)\s+Error|ERROR|WARNING)\s*:",
    re.IGNORECASE,
)
PROBE_MARKER = "SELFVERIFY_EXPECTED_ERROR_PROBE"


def scan_log(text):
    lines = ANSI.sub("", text).splitlines()
    records = []
    for line_number, line in enumerate(lines, 1):
        match = DIAGNOSTIC.match(line)
        if not match:
            continue
        records.append({
            "severity": "warning" if match.group("kind").upper() == "WARNING" else "error",
            "line": line_number,
            "message": line.strip(),
            "context": lines[line_number:min(line_number + 6, len(lines))],
        })
    return records


def analyze_audio_pcm(raw):
    samples = array.array("f")
    samples.frombytes(raw)
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples or not all(math.isfinite(sample) for sample in samples):
        return {"passed": False, "reason": "Missing or invalid decoded audio samples"}
    peak = max(abs(sample) for sample in samples)
    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
    return {"passed": rms > 0.001 and peak < 0.99, "samples": len(samples), "peak": peak, "rms": rms}


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def run_process(command, log_path, timeout):
    with log_path.open("w", encoding="utf-8") as log:
        try:
            completed = subprocess.run(
                [str(value) for value in command], stdout=log, stderr=subprocess.STDOUT,
                timeout=timeout, check=False,
            )
            return completed.returncode
        except subprocess.TimeoutExpired:
            log.write("\nERROR: acceptance process timed out\n")
            return 124


def check_single_game(project_root):
    if os.name != "nt":
        return
    command = (
        "Get-CimInstance Win32_Process | "
        "Where-Object { $_.Name -like 'Godot*.exe' -and $_.CommandLine -notmatch '--editor|-e(?:\\s|$)|--project-manager' } | "
        "Select-Object CommandLine | ConvertTo-Json -Compress"
    )
    result = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", command],
        capture_output=True, text=True, check=True, timeout=20,
    )
    normalized_root = str(project_root).replace("\\", "/").lower()
    if normalized_root in result.stdout.replace("\\\\", "/").replace("\\", "/").lower():
        raise RuntimeError("Stop this project's running game with Godot MCP stop_scene before recording; the game IPC directory is shared.")


def verify(args):
    project_root = args.project.resolve()
    output_dir = args.output.resolve() if args.output else project_root / "recordings" / "self_verify" / datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    output_dir.mkdir(parents=True, exist_ok=False)
    report_path = output_dir / "report.json"
    report = {"all_passed": False, "visual_review": "pending", "output_dir": str(output_dir), "failures": []}
    try:
        for executable in [args.godot, args.ffmpeg, args.ffprobe]:
            if not executable.is_file():
                raise RuntimeError(f"Executable missing: {executable}")
        if not (project_root / ".godot" / "global_script_class_cache.cfg").is_file():
            raise RuntimeError("Open and import project.godot in Godot once before running acceptance.")
        check_single_game(project_root)
        probe_engine_log = output_dir / "probe-engine.log"
        probe_code = run_process([
            args.godot, "--headless", "--path", project_root,
            "--log-file", probe_engine_log, "--script", ASSET_ROOT / "error_probe.gd",
        ], output_dir / "probe-console.log", 30)
        probe_text = probe_engine_log.read_text(encoding="utf-8", errors="replace")
        probe_records = scan_log(probe_text)
        detector_passed = probe_code == 0 and any(
            record["severity"] == "error" and PROBE_MARKER in record["message"] for record in probe_records
        )
        report["detector_probe"] = {
            "passed": detector_passed, "process_exit_code": probe_code,
            "expected_error": PROBE_MARKER, "diagnostics": probe_records,
        }
        if not detector_passed:
            raise RuntimeError("Live error detector negative control failed.")

        engine_log = output_dir / "godot.log"
        movie_path = output_dir / "acceptance.avi"
        scene_path = "res://tests/journey_acceptance.tscn"
        report["suite"] = "adventure"
        user_args = [f"--verify-output={output_dir.as_posix()}", "--journey-verify"]
        engine_code = run_process([
            args.godot, "--path", project_root, "--scene", scene_path,
            "--resolution", "1152x648", "--fixed-fps", str(args.fps),
            "--disable-vsync", "--write-movie", movie_path, "--quit-after", str(args.fps * 100),
            "--log-file", engine_log, "--", *user_args,
        ], output_dir / "godot-console.log", args.timeout)
        report["engine_exit_code"] = engine_code
        if not engine_log.is_file() or engine_log.stat().st_size == 0:
            raise RuntimeError("Engine log missing or empty; cannot establish an error-free run.")
        report["diagnostics"] = []
        for log_path in [engine_log, output_dir / "godot-console.log"]:
            if not log_path.is_file() or log_path.stat().st_size == 0:
                raise RuntimeError(f"Required complete log missing or empty: {log_path}")
            for record in scan_log(log_path.read_text(encoding="utf-8", errors="replace")):
                record["source"] = log_path.name
                report["diagnostics"].append(record)
        if engine_code != 0:
            report["failures"].append(f"Godot exited with code {engine_code}")
        errors = [record for record in report["diagnostics"] if record["severity"] == "error"]
        warnings = [record for record in report["diagnostics"] if record["severity"] == "warning"]
        report["error_count"] = len(errors)
        report["warning_count"] = len(warnings)
        if errors or warnings:
            report["failures"].append("Engine errors or warnings detected in the full per-run log")
        game_report_path = output_dir / "game-report.json"
        if not game_report_path.is_file():
            raise RuntimeError("Game acceptance report missing; the run may have stalled or crashed.")
        report["game"] = json.loads(game_report_path.read_text(encoding="utf-8"))
        if not report["game"].get("all_passed"):
            report["failures"].append("One or more game assertions failed")
        for screenshot in report["game"].get("screenshots", []):
            path = output_dir / screenshot
            if not path.is_file() or path.stat().st_size == 0:
                report["failures"].append(f"Screenshot missing or empty: {screenshot}")
        if len(report["game"].get("screenshots", [])) != 6:
            report["failures"].append("Expected all six acceptance screenshots")
        if not movie_path.is_file() or movie_path.stat().st_size == 0:
            raise RuntimeError("Movie Maker AVI missing or empty")

        mp4_path = output_dir / "acceptance.mp4"
        encode_code = run_process([
            args.ffmpeg, "-nostdin", "-n", "-hide_banner", "-loglevel", "error",
            "-i", movie_path, "-c:v", "libx264", "-preset", "fast", "-crf", "20",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-c:a", "aac", "-b:a", "192k", mp4_path,
        ], output_dir / "ffmpeg.log", args.timeout)
        if encode_code != 0:
            raise RuntimeError(f"Video encoding failed with code {encode_code}")
        metadata = subprocess.run([
            str(args.ffprobe), "-v", "error", "-show_streams", "-show_format", "-of", "json", str(mp4_path),
        ], capture_output=True, text=True, check=True, timeout=30)
        report["video"] = json.loads(metadata.stdout)
        write_json(output_dir / "video-metadata.json", report["video"])
        videos = [stream for stream in report["video"]["streams"] if stream.get("codec_type") == "video"]
        duration = float(report["video"]["format"].get("duration", 0))
        if len(videos) != 1 or duration < 5 or videos[0].get("width") != 1152 or videos[0].get("height") != 648:
            report["failures"].append("Encoded video has unexpected stream, duration or dimensions")
        if args.suite == "adventure":
            audio_streams = [stream for stream in report["video"]["streams"] if stream.get("codec_type") == "audio"]
            if len(audio_streams) != 1:
                report["failures"].append("Adventure recording must contain one audio stream")
            else:
                decoded = subprocess.run([
                    str(args.ffmpeg), "-nostdin", "-v", "error", "-i", str(mp4_path),
                    "-vn", "-ac", "1", "-ar", "24000", "-f", "f32le", "pipe:1",
                ], capture_output=True, check=True, timeout=30)
                report["audio"] = analyze_audio_pcm(decoded.stdout)
                write_json(output_dir / "audio-validation.json", report["audio"])
                if not report["audio"]["passed"]:
                    report["failures"].append("Recorded audio is silent, clipped or invalid")
        sample_code = run_process([
            args.ffmpeg, "-nostdin", "-n", "-hide_banner", "-loglevel", "error",
            "-i", mp4_path, "-vf", f"fps={12 / duration:.8f},scale=384:216,tile=4x3", "-frames:v", "1", output_dir / "video-contact-sheet.png",
        ], output_dir / "video-samples.log", 30)
        if sample_code != 0:
            report["failures"].append("Could not extract review frames from the encoded MP4")
        report["all_passed"] = not report["failures"]
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        report["failures"].append(str(error))
    write_json(report_path, report)
    print(json.dumps({
        "all_passed": report["all_passed"], "visual_review": report["visual_review"],
        "report": str(report_path), "failures": report["failures"],
    }, ensure_ascii=False, indent=2))
    return 0 if report["all_passed"] else 1


def main():
    parser = argparse.ArgumentParser(description="BesiegeLike real-render acceptance, Movie Maker video and screenshots")
    parser.add_argument("--project", type=Path, default=PROJECT_ROOT)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--godot", type=Path, default=Path("E:/Godot/Godot_v4.7.2-stable_win64.exe"))
    parser.add_argument("--ffmpeg", type=Path, default=Path("E:/Tools/ffmpeg-9.0.1-essentials_build/bin/ffmpeg.exe"))
    parser.add_argument("--ffprobe", type=Path, default=Path("E:/Tools/ffmpeg-9.0.1-essentials_build/bin/ffprobe.exe"))
    parser.add_argument("--suite", choices=["adventure"], default="adventure")
    parser.add_argument("--fps", type=int, choices=[30, 60], default=30)
    parser.add_argument("--timeout", type=int, default=240)
    return verify(parser.parse_args())


if __name__ == "__main__":
    sys.exit(main())
