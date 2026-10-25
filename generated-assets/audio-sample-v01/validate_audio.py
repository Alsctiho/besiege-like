from __future__ import annotations

import json
import math
import re
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent
FFMPEG = Path("E:/Tools/ffmpeg-9.0.1-essentials_build/bin/ffmpeg.exe")
FFPROBE = FFMPEG.with_name("ffprobe.exe")


def main() -> None:
    metrics = json.loads((ROOT / "audio_metrics.json").read_text(encoding="utf-8"))
    failures = []
    results = []
    for relative, record in metrics["files"].items():
        path = ROOT / relative
        with wave.open(str(path), "rb") as audio:
            channels = audio.getnchannels()
            rate = audio.getframerate()
            sample_width = audio.getsampwidth()
            count = audio.getnframes()
            samples = np.frombuffer(audio.readframes(count), dtype="<i2").astype(np.float64) / 32768
        rms = float(np.sqrt(np.mean(samples ** 2)))
        peak = float(np.max(np.abs(samples)))
        valid = rate == 48000 and sample_width == 2 and channels == record["channels"] and peak < 0.9 and rms > 0.001
        boundary = None
        if record["loop"]:
            frames = samples.reshape(-1, channels)
            boundary = float(np.max(np.abs(frames[-1] - frames[0])))
            natural_step = float(np.quantile(np.abs(np.diff(frames, axis=0)), 0.99))
            valid = valid and boundary <= max(0.008, natural_step * 2)
        if not valid:
            failures.append(relative)
        results.append({"file": relative, "passed": bool(valid), "duration_seconds": round(count / rate, 5), "peak_dbfs": round(20 * math.log10(max(peak, 1e-12)), 2), "rms_dbfs": round(20 * math.log10(max(rms, 1e-12)), 2), "loop_boundary_delta": boundary})
    decoded = []
    compressed_files = sorted(ROOT.glob("sfx/*.ogg")) + sorted(ROOT.glob("music/*.ogg")) + sorted(ROOT.glob("preview/*.mp3"))
    for path in compressed_files:
        subprocess.run([str(FFMPEG), "-nostdin", "-v", "error", "-i", str(path), "-f", "null", "-"], check=True, capture_output=True)
        probe = subprocess.run([str(FFPROBE), "-v", "error", "-show_entries", "stream=codec_name,sample_rate,channels:format=duration", "-of", "json", str(path)], check=True, capture_output=True, text=True)
        info = json.loads(probe.stdout)
        expected_codec = "vorbis" if path.suffix == ".ogg" else "mp3"
        streams = info["streams"]
        valid = len(streams) == 1 and streams[0]["codec_name"] == expected_codec and int(streams[0]["sample_rate"]) == 48000
        if not valid:
            failures.append(str(path.relative_to(ROOT)))
        decoded.append({"file": str(path.relative_to(ROOT)), "passed": valid, "info": info})
    music = ROOT / "music/windworn_viaduct_60s.wav"
    loudness = subprocess.run([str(FFMPEG), "-nostdin", "-hide_banner", "-i", str(music), "-af", "loudnorm=I=-18:TP=-2:LRA=9:print_format=json", "-f", "null", "-"], check=True, capture_output=True, text=True)
    match = re.search(r'\{\s*"input_i".*?\}', loudness.stderr, re.S)
    loudness_measurement = json.loads(match.group(0)) if match else None
    if loudness_measurement is None:
        failures.append("music_loudness_measurement_missing")
    report = {"all_passed": not failures, "wav_checks": len(results), "compressed_decode_checks": len(decoded), "failures": failures, "wav": results, "compressed": decoded, "music_loudness": loudness_measurement, "listening_review": "Subjective listening not performed; please audition the sample before integration."}
    (ROOT / "validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"all_passed": report["all_passed"], "wav_checks": len(results), "decode_checks": len(decoded), "failures": failures, "music_input_lufs": loudness_measurement.get("input_i") if loudness_measurement else None}, ensure_ascii=False))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
