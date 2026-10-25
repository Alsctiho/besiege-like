from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[1]
OUTPUT = PROJECT / "assets/adventure/audio"
FFMPEG = "E:/Tools/ffmpeg-9.0.1-essentials_build/bin/ffmpeg.exe"


def main() -> None:
    start = time.perf_counter()
    output = OUTPUT / "sfx"
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for source in sorted((ROOT / "sfx").glob("*.wav")):
        name = source.stem
        continuous = name.endswith("_loop")
        cutoff = 1400 if name.startswith(("rotor", "booster", "bridge", "wheel")) else 2200
        if name in {"pickup", "ui_click", "equip", "unequip"}:
            cutoff = 4000
        filters = f"highpass=f=40,lowpass=f={cutoff}"
        if not continuous:
            filters += ",afade=t=in:d=0.01"
        target = output / f"{name}.ogg"
        subprocess.run([FFMPEG, "-nostdin", "-y", "-hide_banner", "-loglevel", "error", "-i", str(source), "-af", filters, "-c:a", "libvorbis", "-q:a", "5", str(target)], check=True)
        records.append({"file": str(target.relative_to(PROJECT)), "source": str(source.relative_to(PROJECT)), "low_pass_hz": cutoff, "loop": continuous, "bytes": target.stat().st_size})
    music = OUTPUT / "music"
    music.mkdir(parents=True, exist_ok=True)
    target = music / "windworn_viaduct.ogg"
    subprocess.run([FFMPEG, "-nostdin", "-y", "-hide_banner", "-loglevel", "error", "-i", str(ROOT / "music/windworn_viaduct_60s.wav"), "-c:a", "libvorbis", "-q:a", "5", str(target)], check=True)
    report = {"original_music_unchanged": True, "sfx_changes": "Reduced harsh high-frequency noise and softened one-shot attack; runtime mixing provides additional gain control.", "generation_seconds": round(time.perf_counter() - start, 3), "sfx": records, "music_bytes": target.stat().st_size}
    (ROOT / "game_audio_metrics.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"sfx": len(records), "music_seconds": 60, "conversion_seconds": report["generation_seconds"], "asset_bytes": sum(item["bytes"] for item in records) + report["music_bytes"]}))


if __name__ == "__main__":
    main()
