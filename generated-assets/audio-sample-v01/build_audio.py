from __future__ import annotations

import json
import math
import time
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent
RATE = 48000
RNG = np.random.default_rng(20261025)
RECORDS: dict[str, dict] = {}
START = time.perf_counter()


def timeline(seconds: float) -> np.ndarray:
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def filtered_noise(seconds: float, cutoff: float, low: float = 0) -> np.ndarray:
    count = round(seconds * RATE)
    raw = RNG.normal(0, 1, count)
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    response = np.exp(-(frequencies / cutoff) ** 4)
    if low:
        response *= 1 - np.exp(-(frequencies / low) ** 4)
    result = np.fft.irfft(np.fft.rfft(raw) * response, n=count)
    return result / max(float(np.std(result)), 1e-8)


def edges(audio: np.ndarray, attack: float = 0.008, release: float = 0.06) -> np.ndarray:
    result = audio.copy()
    a = min(round(attack * RATE), len(result) // 2)
    r = min(round(release * RATE), len(result) // 2)
    if a:
        ramp = np.sin(np.linspace(0, math.pi / 2, a)) ** 2
        result[:a] *= ramp[:, None] if result.ndim == 2 else ramp
    if r:
        ramp = np.cos(np.linspace(0, math.pi / 2, r)) ** 2
        result[-r:] *= ramp[:, None] if result.ndim == 2 else ramp
    return result


def loop_join(audio: np.ndarray, seconds: float = 0.08) -> np.ndarray:
    count = round(seconds * RATE)
    ramp = np.linspace(0, 1, count)
    if audio.ndim == 2:
        ramp = ramp[:, None]
    joined = audio[-count:] * (1 - ramp) + audio[:count] * ramp
    return np.concatenate([audio[count:-count], joined])


def echo(audio: np.ndarray, taps: tuple[tuple[float, float], ...]) -> np.ndarray:
    result = audio.copy()
    for seconds, gain in taps:
        offset = round(seconds * RATE)
        if offset < len(audio):
            result[offset:] += audio[:-offset] * gain
    return result


def note_frequency(note: int) -> float:
    return 440 * 2 ** ((note - 69) / 12)


def bell(note: int, seconds: float = 1.8, soft: bool = False) -> np.ndarray:
    t = timeline(seconds)
    fundamental = note_frequency(note)
    tone = np.sin(2 * math.pi * fundamental * t) * np.exp(-t / (1.05 if soft else 0.58))
    tone += 0.20 * np.sin(2 * math.pi * fundamental * 2.002 * t) * np.exp(-t / 0.28)
    tone += 0.06 * np.sin(2 * math.pi * fundamental * 3.01 * t) * np.exp(-t / 0.13)
    return edges(tone, 0.018 if soft else 0.004, 0.12)


def motor(seconds: float, initial: float, final: float, texture: str) -> np.ndarray:
    t = timeline(seconds)
    f = final + (initial - final) * np.exp(-t / max(seconds * 0.23, 0.02))
    phase = 2 * math.pi * np.cumsum(f) / RATE
    if texture == "rotor":
        sound = 0.20 * np.sin(phase) + 0.08 * np.sin(phase * 3)
        pulse = (0.58 + 0.42 * np.sin(phase * 3)) ** 2
        sound += filtered_noise(seconds, 1800, 160) * 0.12 * pulse
        sound += 0.05 * np.sin(phase * 7)
    elif texture == "drill":
        sound = 0.17 * np.sin(phase) + 0.08 * np.sin(phase * 2.0)
        sound += 0.07 * np.sin(phase * 4.0 + 0.7 * np.sin(phase / 11))
        sound += filtered_noise(seconds, 3400, 700) * 0.11 * (0.75 + 0.25 * np.sin(phase / 6))
    else:
        sound = 0.14 * np.sin(phase) + 0.06 * np.sin(phase * 2)
        sound += filtered_noise(seconds, 2300, 90) * 0.16 * (0.85 + 0.15 * np.sin(phase / 7))
    return sound


def write_audio(relative: str, audio: np.ndarray, title: str, loop: bool = False, peak_db: float = -6) -> np.ndarray:
    signal = np.asarray(audio, dtype=np.float64)
    signal -= np.mean(signal, axis=0)
    raw_peak = float(np.max(np.abs(signal)))
    signal *= 10 ** (peak_db / 20) / max(raw_peak, 1e-9)
    encoded = np.rint(signal * 32767).astype("<i2")
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    channels = 1 if signal.ndim == 1 else signal.shape[1]
    with wave.open(str(path), "wb") as file:
        file.setnchannels(channels)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(encoded.tobytes())
    rms = float(np.sqrt(np.mean(signal ** 2)))
    RECORDS[relative] = {
        "title": title,
        "duration_seconds": round(len(signal) / RATE, 5),
        "sample_rate": RATE,
        "channels": channels,
        "bits": 16,
        "loop": loop,
        "peak_dbfs": round(20 * math.log10(max(float(np.max(np.abs(signal))), 1e-12)), 2),
        "rms_dbfs": round(20 * math.log10(max(rms, 1e-12)), 2),
        "loop_boundary_delta": round(float(np.max(np.abs(signal[-1] - signal[0]))), 7) if loop else None,
        "bytes": path.stat().st_size,
    }
    return signal


def impact(seconds: float, base: float, decay: float, roughness: float = 0.3) -> np.ndarray:
    t = timeline(seconds)
    sound = np.sin(2 * math.pi * base * t + 0.6 * np.exp(-t * 12)) * np.exp(-t / decay)
    sound += filtered_noise(seconds, 2800, 400) * roughness * np.exp(-t / (decay * 0.35))
    return edges(sound, 0.0015, 0.04)


def make_sfx() -> dict[str, np.ndarray]:
    sfx: dict[str, np.ndarray] = {}

    def save(key: str, sound: np.ndarray, title: str, loop: bool = False) -> None:
        sfx[key] = write_audio(f"sfx/{key}.wav", sound if loop else edges(sound), title, loop, -5)

    save("rotor_start", motor(0.7, 22, 70, "rotor") * np.minimum(timeline(0.7) / 0.2, 1), "旋翼启动")
    save("rotor_loop", loop_join(motor(2.08, 70, 70, "rotor")), "旋翼持续旋转", True)
    save("rotor_stop", motor(0.65, 70, 14, "rotor") * np.exp(-timeline(0.65) * 5), "旋翼减速停止")
    t = timeline(2.08)
    wind = filtered_noise(2.08, 1600, 100) * (0.16 + 0.025 * np.sin(2 * math.pi * 2 * t))
    wind += 0.035 * np.sin(2 * math.pi * 125 * t)
    save("blower_loop", loop_join(wind), "吹风机柔和气流", True)
    save("booster_start", motor(0.55, 34, 92, "jet") * np.minimum(timeline(0.55) / 0.1, 1), "喷气点火")
    save("booster_loop", loop_join(motor(1.58, 92, 92, "jet")), "喷气持续推进", True)
    save("booster_stop", motor(0.55, 90, 18, "jet") * np.exp(-timeline(0.55) * 7), "喷气停止泄压")
    save("drill_start", motor(0.45, 100, 210, "drill"), "钻头前伸启动")
    save("drill_loop", loop_join(motor(1.58, 210, 210, "drill")), "钻头电机旋转", True)
    t = timeline(1.0)
    contact = filtered_noise(1.0, 3900, 800) * np.exp(-t * 2)
    contact *= 0.45 + 0.30 * np.sin(2 * math.pi * 41 * t) ** 2
    save("drill_contact", contact + 0.1 * np.sin(2 * math.pi * 90 * t) * np.exp(-t * 4), "钻头接触石头")
    rubble = np.zeros(round(RATE * 2.3))
    for index in range(24):
        offset = round((0.0 if index == 0 else RNG.uniform(0.04, 1.8)) * RATE)
        grain = impact(0.4, RNG.uniform(85, 360), RNG.uniform(0.025, 0.10), 0.55)
        count = min(len(grain), len(rubble) - offset)
        rubble[offset:offset + count] += grain[:count] * (0.9 if index == 0 else RNG.uniform(0.08, 0.24))
    rubble += filtered_noise(2.3, 1200) * 0.025 * np.exp(-timeline(2.3) / 0.8)
    save("rock_collapse", rubble, "裂岩崩解与碎块落地")
    t = timeline(2.08)
    rolling = filtered_noise(2.08, 900, 70) * (0.10 + 0.04 * np.sin(2 * math.pi * 12.5 * t))
    rolling += 0.025 * np.sin(2 * math.pi * 105 * t)
    save("wheel_roll_loop", loop_join(rolling), "轮胎石面滚动", True)
    save("wheel_landing", impact(0.7, 84, 0.10, 0.35) + 0.15 * impact(0.7, 245, 0.05, 0.1), "轮胎落地与悬挂回弹")
    save("wheel_skid", filtered_noise(0.65, 2600, 450) * np.exp(-timeline(0.65) * 3), "轮胎短促打滑")
    pickup = np.zeros(round(1.6 * RATE))
    for note, onset, gain in [(74, 0, 0.7), (77, 0.12, 0.45), (81, 0.27, 0.3)]:
        tone = bell(note, 1.1)
        offset = round(onset * RATE)
        pickup[offset:offset + len(tone)] += tone * gain
    save("pickup", echo(pickup, ((0.16, 0.14), (0.33, 0.08))), "拾取组件清脆提示")
    equip = impact(0.48, 160, 0.045, 0.2)
    equip += bell(69, 0.48, True) * 0.14
    save("equip", equip, "安装机械锁扣")
    save("unequip", impact(0.48, 115, 0.038, 0.22) + 0.08 * bell(62, 0.48), "卸下机械锁扣")
    t = timeline(0.9)
    save("bridge_start", edges(motor(0.9, 24, 46, "jet"), 0.15, 0.15) + 0.12 * impact(0.9, 68, 0.06), "升降桥机械启动")
    bridge = motor(2.08, 46, 46, "jet") * 0.8
    bridge += 0.09 * np.sin(2 * math.pi * 140 * timeline(2.08))
    save("bridge_move_loop", loop_join(bridge), "升降桥低频运转", True)
    save("bridge_arrived", echo(impact(1.4, 72, 0.16, 0.3) + 0.16 * bell(65, 1.4, True), ((0.12, 0.18), (0.3, 0.1))), "升降桥到位落锁")
    save("ui_click", impact(0.12, 440, 0.009, 0.03), "纸质界面轻点击")
    return sfx


def place_circular(target: np.ndarray, sound: np.ndarray, seconds: float, amplitude: float, pan: float) -> None:
    offset = round(seconds * RATE) % len(target)
    left = math.sqrt((1 - pan) * 0.5)
    right = math.sqrt((1 + pan) * 0.5)
    stereo = sound[:, None] * np.array([left, right])[None, :] * amplitude
    first = min(len(sound), len(target) - offset)
    target[offset:offset + first] += stereo[:first]
    if first < len(sound): target[:len(sound) - first] += stereo[first:]


def make_music() -> np.ndarray:
    seconds = 60.0
    beat = 60 / 64
    bar = beat * 4
    music = np.zeros((round(seconds * RATE), 2), dtype=np.float64)
    chords = [
        [38, 57, 60, 64, 69], [38, 57, 60, 64, 69],
        [34, 53, 57, 60, 65], [34, 53, 57, 60, 65],
        [41, 57, 60, 64, 67], [41, 57, 60, 64, 67],
        [36, 55, 60, 62, 67], [36, 55, 60, 62, 67],
        [38, 57, 60, 64, 69], [38, 57, 60, 64, 69],
        [34, 53, 57, 60, 65], [34, 53, 57, 60, 65],
        [43, 58, 62, 65, 69], [36, 55, 60, 62, 67],
        [41, 55, 60, 65, 67], [41, 55, 60, 65, 67],
    ]
    for index, chord in enumerate(chords):
        t = timeline(bar + 2.6)
        amplitude = (1 - np.exp(-t / 0.8)) * np.exp(-np.maximum(t - bar + 0.2, 0) / 0.9)
        for voice, note in enumerate(chord):
            f = note_frequency(note)
            pad = np.sin(2 * math.pi * f * t + voice * 0.7)
            pad += 0.27 * np.sin(2 * math.pi * f * 2 * t + 0.15 * np.sin(t * 0.8))
            pad += 0.09 * np.sin(2 * math.pi * f * 3 * t)
            pan = (voice - 2) * 0.23
            place_circular(music, pad * amplitude, index * bar, 0.052 if voice == 0 else 0.026, pan)
    melody = [
        (0, 1.0, 74), (1, 0.5, 77), (1, 2.5, 81), (2, 1.5, 79), (3, 2.0, 77),
        (4, 0.75, 72), (5, 1.0, 76), (5, 2.75, 79), (6, 1.5, 74), (7, 2.5, 72),
        (8, 0.5, 77), (8, 2.75, 81), (9, 1.5, 84), (10, 1.0, 81), (11, 2.0, 77),
        (12, 0.75, 74), (12, 2.25, 77), (13, 1.5, 79), (14, 1.0, 77), (15, 1.5, 72),
    ]
    for index, position, note in melody:
        tone = bell(note, 3.2, True)
        tone = echo(tone, ((0.281, 0.23), (0.563, 0.10), (0.839, 0.06)))
        pan = math.sin(index * 1.7) * 0.35
        place_circular(music, tone, index * bar + position * beat, 0.13, pan)
    for index in [1, 3, 5, 7, 9, 11, 13]:
        tone = bell(chords[index][3] + 12, 2.5, True)
        place_circular(music, tone, index * bar + beat * 3, 0.025, -0.55)
    dry = music.copy()
    for seconds_offset, gain in [(0.113, 0.08), (0.197, 0.06), (0.337, 0.08), (0.487, 0.04), (0.733, 0.03)]:
        delayed = np.roll(dry, round(seconds_offset * RATE), axis=0)
        music += delayed[:, ::-1] * gain
    return write_audio("music/windworn_viaduct_60s.wav", music, "风蚀高架 · 探索音乐 v0.1", True, -6)


def make_sampler(sfx: dict[str, np.ndarray]) -> None:
    blocks = [
        ("旋翼：启动 → 循环 → 停止", [("rotor_start", 0), ("rotor_loop", 0.7), ("rotor_stop", 2.7)], 4.0),
        ("吹风机：持续气流", [("blower_loop", 0)], 2.8),
        ("喷气：点火 → 持续 → 泄压", [("booster_start", 0), ("booster_loop", 0.55), ("booster_stop", 2.05)], 3.1),
        ("钻岩：电机 → 接触 → 石头崩解", [("drill_start", 0), ("drill_loop", 0.45), ("drill_contact", 1.2), ("rock_collapse", 2.4)], 5.1),
        ("轮胎：滚动 → 打滑 → 落地", [("wheel_roll_loop", 0), ("wheel_skid", 2.15), ("wheel_landing", 2.9)], 4.1),
        ("交互：拾取 → 安装 → 卸下 → 点击", [("pickup", 0), ("equip", 1.8), ("unequip", 2.5), ("ui_click", 3.2)], 3.7),
        ("升桥：启动 → 运转 → 到位", [("bridge_start", 0), ("bridge_move_loop", 0.9), ("bridge_arrived", 3.0)], 4.8),
    ]
    total = sum(block[2] for block in blocks)
    result = np.zeros(round(total * RATE))
    cues = []
    cursor = 0.0
    for title, entries, length in blocks:
        cues.append({"start_seconds": round(cursor, 2), "end_seconds": round(cursor + length, 2), "title": title})
        for key, onset in entries:
            sample = sfx[key]
            offset = round((cursor + onset) * RATE)
            result[offset:offset + len(sample)] += sample * (0.55 if key in {"drill_contact", "drill_loop"} else 0.8)
        cursor += length
    write_audio("preview/sfx_demo.wav", edges(result), "机械音效连续试听", False, -3)
    (ROOT / "preview/sfx_cues.json").write_text(json.dumps(cues, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    sfx = make_sfx()
    sfx_seconds = time.perf_counter() - START
    print(f"SFX_COMPLETE count={len(sfx)} seconds={sfx_seconds:.3f}", flush=True)
    make_sampler(sfx)
    music_start = time.perf_counter()
    make_music()
    report = {
        "provenance": "Original local procedural synthesis; no sampled commercial recordings or cloud music generation.",
        "design": "64 BPM, D-minor / F-major color, sparse bell melody and warm synthetic pad, circular reverb tails.",
        "sfx_generation_seconds": round(sfx_seconds, 3),
        "music_generation_seconds": round(time.perf_counter() - music_start, 3),
        "total_generation_seconds": round(time.perf_counter() - START, 3),
        "cloud_generation_calls": 0,
        "token_or_billing_cost": "Not accessible; not claimed to be zero.",
        "listening_review": "Not performed by audio-capable listening tools; subjective quality requires user audition.",
        "files": RECORDS,
    }
    (ROOT / "audio_metrics.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"complete": True, "sfx_count": len(sfx), "seconds": report["total_generation_seconds"], "wav_bytes": sum(record["bytes"] for record in RECORDS.values())}))


if __name__ == "__main__":
    main()
