#!/usr/bin/env python3
"""Gera placeholders SFX/BGM procedurais (original, sem OST rip).

Uso (na raiz do projeto):
  python scripts/tools/generate_audio_placeholders.py

Saída:
  assets/audio/sfx/*.wav
  assets/audio/bgm/*.wav
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
SFX = ROOT / "assets" / "audio" / "sfx"
BGM = ROOT / "assets" / "audio" / "bgm"


def clamp(x: float, lo: float = -1.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, x))


def write_wav(path: Path, samples: list[float], sr: int = SR) -> None:
    data = bytearray()
    for s in samples:
        data += struct.pack("<h", int(clamp(s) * 32767))
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(bytes(data))
    print(f"wrote {path.relative_to(ROOT)} ({len(samples) / sr:.2f}s)")


def env_adsr(n: int, a: float = 0.01, d: float = 0.05, s: float = 0.6, r: float = 0.1) -> list[float]:
    out = [0.0] * n
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    sus_n = max(0, n - a_n - d_n - r_n)
    i = 0
    for k in range(a_n):
        out[i] = k / max(1, a_n)
        i += 1
    for k in range(d_n):
        out[i] = 1.0 - (1.0 - s) * (k / max(1, d_n))
        i += 1
    for _ in range(sus_n):
        out[i] = s
        i += 1
    for k in range(r_n):
        if i >= n:
            break
        out[i] = s * (1.0 - k / max(1, r_n))
        i += 1
    return out


def tone(freq: float, dur: float, amp: float = 0.4, kind: str = "sine") -> list[float]:
    n = int(dur * SR)
    out: list[float] = []
    for i in range(n):
        t = i / SR
        ph = 2 * math.pi * freq * t
        if kind == "triangle":
            s = 2 * abs(2 * ((t * freq) % 1) - 1) - 1
        else:
            s = math.sin(ph)
        out.append(s * amp)
    return out


def noise(dur: float, amp: float = 0.3) -> list[float]:
    return [random.uniform(-1, 1) * amp for _ in range(int(dur * SR))]


def mul(a: list[float], b: list[float]) -> list[float]:
    return [x * y for x, y in zip(a, b)]


def add(*seqs: list[float]) -> list[float]:
    n = max(len(s) for s in seqs)
    out = [0.0] * n
    for s in seqs:
        for i, v in enumerate(s):
            out[i] += v
    return out


def fade(samples: list[float], fade_in: float = 0.01, fade_out: float = 0.05) -> list[float]:
    n = len(samples)
    fi, fo = int(fade_in * SR), int(fade_out * SR)
    out = samples[:]
    for i in range(min(fi, n)):
        out[i] *= i / max(1, fi)
    for i in range(min(fo, n)):
        out[n - 1 - i] *= i / max(1, fo)
    return out


def lowpass(samples: list[float], alpha: float = 0.15) -> list[float]:
    out: list[float] = []
    y = 0.0
    for x in samples:
        y = y + alpha * (x - y)
        out.append(y)
    return out


def highpass(samples: list[float], alpha: float = 0.1) -> list[float]:
    out: list[float] = []
    y = 0.0
    prev = 0.0
    for x in samples:
        y = alpha * (y + x - prev)
        prev = x
        out.append(y)
    return out


def pluck(freq: float, dur: float, amp: float = 0.35) -> list[float]:
    n = int(dur * SR)
    return mul(tone(freq, dur, amp), env_adsr(n, 0.002, 0.05, 0.15, 0.25))


def drum(freq: float, dur: float, amp: float = 0.6) -> list[float]:
    nn = int(dur * SR)
    body = mul(tone(freq, dur, amp), env_adsr(nn, 0.002, 0.08, 0.15, 0.35))
    body2 = mul(tone(freq * 1.5, dur * 0.6, amp * 0.3), env_adsr(int(dur * 0.6 * SR), 0.001, 0.05, 0.1, 0.2))
    click = mul(noise(0.03, 0.4), env_adsr(int(0.03 * SR), 0.0005, 0.008, 0.1, 0.015))
    return add(body, body2 + [0.0] * (nn - len(body2)), click + [0.0] * (nn - len(click)))


def _crossfade_loop(buf: list[float], fade_s: float) -> None:
    n = len(buf)
    cf = int(fade_s * SR)
    if cf <= 0 or cf * 2 > n:
        return
    for i in range(cf):
        a = i / cf
        buf[n - cf + i] = buf[n - cf + i] * (1 - a) + buf[i] * a


def _world_loop(
    n: int,
    *,
    bpm: float,
    notes: list[float],
    bass_hz: float,
    kick_hz: float,
    kick_drop: float,
    kick_window: float,
    hat_amp: float,
    lead_amp: float,
    pad_a: float,
    pad_b: float,
    bass_decay: float,
    triangle_lead: bool,
    clack: bool,
    shimmer: float,
    organ: float,
) -> list[float]:
    out = [0.0] * n
    beat_len = 60.0 / bpm
    for i in range(n):
        t = i / SR
        beat_phase = (t % beat_len) / beat_len
        bass_env = math.exp(-beat_phase * bass_decay)
        bass = math.sin(2 * math.pi * bass_hz * t) * 0.18 * bass_env
        kick = (
            math.sin(2 * math.pi * (kick_hz - kick_drop * beat_phase) * t) * 0.22 * bass_env
            if beat_phase < kick_window
            else 0.0
        )
        sub = (t % (beat_len / 2)) / (beat_len / 2)
        hat = random.uniform(-1, 1) * hat_amp * math.exp(-sub * 40) if sub < 0.08 else 0.0
        bar = int(t / beat_len) % len(notes)
        nf = notes[bar]
        if triangle_lead:
            tri = 2 * abs(2 * ((t * nf) % 1) - 1) - 1
            lead = tri * lead_amp * (0.55 + 0.45 * math.sin(2 * math.pi * (1.0 / beat_len) * t))
        else:
            lead = math.sin(2 * math.pi * nf * t) * lead_amp * (
                0.5 + 0.5 * math.sin(2 * math.pi * (1.0 / beat_len) * t)
            )
        pad = math.sin(2 * math.pi * pad_a * t) * 0.05 + math.sin(2 * math.pi * pad_b * t) * 0.04
        extra = 0.0
        if clack and beat_phase < 0.06:
            extra += random.uniform(-1, 1) * 0.12 * math.exp(-beat_phase * 70)
        if shimmer > 0.0:
            extra += math.sin(2 * math.pi * (pad_b * 2.0) * t) * shimmer * (
                0.4 + 0.6 * math.sin(2 * math.pi * 0.2 * t)
            )
        if organ > 0.0:
            extra += (
                math.sin(2 * math.pi * (bass_hz * 0.5) * t)
                + 0.5 * math.sin(2 * math.pi * (bass_hz * 1.5) * t)
            ) * organ
        out[i] = bass + kick + hat + lead + pad + extra
    _crossfade_loop(out, 0.15)
    return out


def main() -> None:
    random.seed(42)
    SFX.mkdir(parents=True, exist_ok=True)
    BGM.mkdir(parents=True, exist_ok=True)

    n = int(0.06 * SR)
    click = mul(tone(1800, 0.06, 0.35), env_adsr(n, 0.001, 0.01, 0.2, 0.04))
    click = add(click, mul(tone(900, 0.05, 0.15), env_adsr(int(0.05 * SR), 0.001, 0.01, 0.1, 0.03)))
    write_wav(SFX / "ui_click.wav", fade(click, 0.001, 0.02))

    dur, n = 0.22, int(0.22 * SR)
    whoosh = highpass(noise(dur, 0.55), 0.25)
    env = [math.sin(math.pi * min(1.0, (i / n) * 1.3)) ** 1.5 for i in range(n)]
    whoosh = mul(whoosh, env)
    pitch = [math.sin(2 * math.pi * (600 - 400 * (i / n)) * (i / SR)) * 0.12 * env[i] for i in range(n)]
    write_wav(SFX / "slash.wav", fade(add(whoosh, pitch), 0.005, 0.04))

    dur, n = 0.15, int(0.15 * SR)
    body = mul(tone(120, dur, 0.6), env_adsr(n, 0.001, 0.04, 0.25, 0.08))
    click2 = mul(noise(0.04, 0.5), env_adsr(int(0.04 * SR), 0.0005, 0.01, 0.2, 0.02))
    mid = mul(tone(340, 0.08, 0.25, "triangle"), env_adsr(int(0.08 * SR), 0.001, 0.02, 0.2, 0.05))
    write_wav(SFX / "hit.wav", fade(add(body, click2 + [0.0] * (n - len(click2)), mid + [0.0] * (n - len(mid))), 0.001, 0.03))

    dur, n = 0.2, int(0.2 * SR)
    body = mul(tone(80, dur, 0.55), env_adsr(n, 0.002, 0.06, 0.3, 0.1))
    grit = mul(lowpass(noise(0.12, 0.35), 0.2), env_adsr(int(0.12 * SR), 0.001, 0.04, 0.2, 0.06))
    write_wav(SFX / "hurt.wav", fade(add(body, grit + [0.0] * (n - len(grit))), 0.001, 0.04))

    coin = add(pluck(1318.5, 0.35, 0.35), pluck(1760.0, 0.28, 0.28))
    c2 = [0.0] * int(0.04 * SR) + pluck(2093.0, 0.25, 0.22)
    write_wav(SFX / "coin.wav", fade(add(coin, c2), 0.001, 0.05))

    parts = []
    for fi, f in enumerate([440, 554, 659, 880]):
        parts.append([0.0] * int(0.05 * fi * SR) + pluck(f, 0.4, 0.22))
    sh = mul(highpass(noise(0.5, 0.12), 0.3), env_adsr(int(0.5 * SR), 0.05, 0.1, 0.4, 0.2))
    write_wav(SFX / "breath_full.wav", fade(add(sh, *parts), 0.01, 0.08))

    dur, n = 0.55, int(0.55 * SR)
    whoosh = highpass(noise(dur, 0.5), 0.2)
    env = [math.sin(math.pi * min(1.0, (i / n) * 1.1)) ** 0.8 for i in range(n)]
    whoosh = mul(whoosh, env)
    rise, ph = [], 0.0
    for i in range(n):
        t = i / n
        f = 100 + 500 * t * t
        ph += 2 * math.pi * f / SR
        rise.append(math.sin(ph) * 0.25 * env[i])
    imp = mul(tone(60, 0.2, 0.7), env_adsr(int(0.2 * SR), 0.001, 0.05, 0.2, 0.1))
    write_wav(SFX / "ultimate.wav", fade(add(whoosh, rise, [0.0] * int(0.35 * SR) + imp), 0.01, 0.08))

    parts = []
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        delay = int(0.12 * i * SR)
        p = pluck(f, 0.45, 0.3)
        p2 = pluck(f * 2, 0.35, 0.1)
        parts.append([0.0] * delay + add(p, p2 + [0.0] * (len(p) - len(p2))))
    write_wav(SFX / "stage_clear.wav", fade(add(*parts), 0.005, 0.1))

    d1 = drum(70, 0.55, 0.7)
    d2 = [0.0] * int(0.18 * SR) + drum(90, 0.4, 0.45)
    shak = []
    for i in range(int(0.7 * SR)):
        t = i / SR
        f = 520 + 30 * math.sin(2 * math.pi * 2 * t)
        e = env_adsr(int(0.7 * SR), 0.08, 0.15, 0.5, 0.25)[i]
        shak.append(math.sin(2 * math.pi * f * t) * 0.18 * e)
    shak = [0.0] * int(0.12 * SR) + shak
    sp = [0.0] * int(0.55 * SR) + pluck(1046, 0.35, 0.2)
    write_wav(SFX / "brand_sting.wav", fade(add(d1, d2, shak, sp), 0.005, 0.1))

    n = int(8.0 * SR)
    hub = [0.0] * n
    for i in range(n):
        t = i / SR
        drone = (
            math.sin(2 * math.pi * 110 * t) * 0.12
            + math.sin(2 * math.pi * 164.81 * t) * 0.08
            + math.sin(2 * math.pi * 220 * t) * 0.055
        )
        pad = math.sin(2 * math.pi * 329.63 * t) * 0.035 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.125 * t))
        beat = t % 2.0
        pl = 0.0
        if beat < 0.35:
            e = math.exp(-beat * 7)
            nf = 659.25 if int(t / 2) % 2 == 0 else 523.25
            pl = math.sin(2 * math.pi * nf * t) * 0.07 * e
        hub[i] = drone + pad + pl
    cf = int(0.2 * SR)
    for i in range(cf):
        a = i / cf
        hub[n - cf + i] = hub[n - cf + i] * (1 - a) + hub[i] * a
    write_wav(BGM / "hub_loop.wav", hub)

    # w1 Montanha = stage_loop atual (120 bpm, lead em terças).
    w1 = _world_loop(
        n,
        bpm=120.0,
        notes=[164.81, 196.00, 220.00, 246.94, 261.63, 246.94, 220.00, 196.00],
        bass_hz=82.41,
        kick_hz=80.0,
        kick_drop=40.0,
        kick_window=0.3,
        hat_amp=0.06,
        lead_amp=0.07,
        pad_a=130.81,
        pad_b=196.00,
        bass_decay=8.0,
        triangle_lead=False,
        clack=False,
        shimmer=0.0,
        organ=0.0,
    )
    write_wav(BGM / "stage_loop.wav", w1)
    write_wav(BGM / "w1_loop.wav", w1)

    # w2 Trem — mais rápido, cliques metálicos no tempo.
    w2 = _world_loop(
        n,
        bpm=144.0,
        notes=[196.00, 233.08, 261.63, 293.66, 311.13, 293.66, 246.94, 220.00],
        bass_hz=98.00,
        kick_hz=95.0,
        kick_drop=50.0,
        kick_window=0.18,
        hat_amp=0.10,
        lead_amp=0.08,
        pad_a=146.83,
        pad_b=293.66,
        bass_decay=11.0,
        triangle_lead=True,
        clack=True,
        shimmer=0.0,
        organ=0.0,
    )
    write_wav(BGM / "w2_loop.wav", w2)

    # w3 Distrito — mid-tempo, pad noturno.
    w3 = _world_loop(
        n,
        bpm=108.0,
        notes=[174.61, 207.65, 233.08, 261.63, 233.08, 207.65, 196.00, 174.61],
        bass_hz=87.31,
        kick_hz=70.0,
        kick_drop=28.0,
        kick_window=0.36,
        hat_amp=0.045,
        lead_amp=0.065,
        pad_a=220.00,
        pad_b=349.23,
        bass_decay=6.5,
        triangle_lead=False,
        clack=False,
        shimmer=0.02,
        organ=0.0,
    )
    write_wav(BGM / "w3_loop.wav", w3)

    # w4 Castelo — lento, órgão grave.
    w4 = _world_loop(
        n,
        bpm=86.0,
        notes=[130.81, 155.56, 174.61, 196.00, 174.61, 155.56, 146.83, 130.81],
        bass_hz=65.41,
        kick_hz=52.0,
        kick_drop=18.0,
        kick_window=0.42,
        hat_amp=0.02,
        lead_amp=0.05,
        pad_a=98.00,
        pad_b=196.00,
        bass_decay=5.0,
        triangle_lead=False,
        clack=False,
        shimmer=0.0,
        organ=0.09,
    )
    write_wav(BGM / "w4_loop.wav", w4)

    # w5 Céu Vermelho — pulse largo + shimmer agudo.
    w5 = _world_loop(
        n,
        bpm=72.0,
        notes=[110.00, 130.81, 146.83, 164.81, 185.00, 164.81, 146.83, 123.47],
        bass_hz=55.00,
        kick_hz=48.0,
        kick_drop=12.0,
        kick_window=0.5,
        hat_amp=0.015,
        lead_amp=0.055,
        pad_a=329.63,
        pad_b=493.88,
        bass_decay=4.0,
        triangle_lead=False,
        clack=False,
        shimmer=0.045,
        organ=0.0,
    )
    write_wav(BGM / "w5_loop.wav", w5)

    # Boss: mais escuro e mais lento que qualquer mundo (original, sem OST).
    boss = [0.0] * n
    beat_len_b = 60.0 / 92
    notes_boss = [73.42, 87.31, 98.00, 110.00, 98.00, 87.31, 82.41, 73.42]
    for i in range(n):
        t = i / SR
        beat_phase = (t % beat_len_b) / beat_len_b
        bass_env = math.exp(-beat_phase * 5)
        drone = (
            math.sin(2 * math.pi * 36.71 * t) * 0.18
            + math.sin(2 * math.pi * 55.00 * t) * 0.12
            + math.sin(2 * math.pi * 73.42 * t) * 0.06
        )
        kick = (
            math.sin(2 * math.pi * (48 - 22 * beat_phase) * t) * 0.30 * bass_env
            if beat_phase < 0.22
            else 0.0
        )
        snare = (
            random.uniform(-1, 1) * 0.11 * math.exp(-((beat_phase - 0.5) ** 2) * 180)
            if 0.46 < beat_phase < 0.62
            else 0.0
        )
        bar = int(t / beat_len_b) % 8
        stab_env = max(0.0, 1.0 - (beat_phase * 4.2))
        lead = math.sin(2 * math.pi * notes_boss[bar] * t) * 0.10 * stab_env
        menace = math.sin(2 * math.pi * 27.5 * t) * 0.07 * (0.55 + 0.45 * math.sin(2 * math.pi * 0.15 * t))
        boss[i] = drone + kick + snare + lead + menace
    _crossfade_loop(boss, 0.18)
    write_wav(BGM / "boss_loop.wav", boss)

    print("OK — placeholders regenerados (original/procedural).")


if __name__ == "__main__":
    main()
