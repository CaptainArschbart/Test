#!/usr/bin/env python3
"""Erzeugt die Sounds für SMG und Kontaktgranate als WAV (44,1 kHz, 16 Bit, mono).

Aufruf aus dem Repo-Root: python3 tools/gen_weapon_sounds.py
Schreibt nach assets/audio/: smg_shot.wav, smg_reload.wav, grenade_throw.wav,
grenade_explosion.wav. Nur Standardbibliothek, fester Zufalls-Seed (gleiches Ergebnis).

Mit `--m3` nur die Waffen aus Schedule 1, Phase 4 (eigener Seed, ältere Dateien bleiben unberührt):
revolver_shot, revolver_reload, heavy_pistol_shot, shotgun_shot (mit Repetieren), shotgun_reload
(eine Patrone), sawed_off_shot, sawed_off_reload, bullpup_shot, compact_smg_shot, dmr_shot.
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = random.Random(1337)


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def lowpass(samples, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    a = (1.0 / RATE) / (rc + 1.0 / RATE)
    out, y = [], 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    a = rc / (rc + 1.0 / RATE)
    out, y, prev = [], 0.0, 0.0
    for x in samples:
        y = a * (y + x - prev)
        prev = x
        out.append(y)
    return out


def noise(seconds):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(seconds * RATE))]


def env(samples, attack, decay_rate):
    out = []
    for i, x in enumerate(samples):
        t = i / RATE
        e = min(t / attack, 1.0) if attack > 0 else 1.0
        out.append(x * e * math.exp(-t * decay_rate))
    return out


def mix_into(base, add, start_s, gain=1.0):
    start = int(start_s * RATE)
    need = start + len(add)
    if len(base) < need:
        base.extend([0.0] * (need - len(base)))
    for i, x in enumerate(add):
        base[start + i] += x * gain
    return base


def tone(freq_from, freq_to, seconds):
    out, phase = [], 0.0
    n = int(seconds * RATE)
    for i in range(n):
        f = freq_from + (freq_to - freq_from) * i / max(n - 1, 1)
        phase += 2 * math.pi * f / RATE
        out.append(math.sin(phase))
    return out


def click(seconds, cutoff_lo, cutoff_hi, decay):
    return env(highpass(lowpass(noise(seconds), cutoff_hi), cutoff_lo), 0.0005, decay)


def write(name, samples, peak=0.9):
    m = max(abs(x) for x in samples) or 1.0
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x / m * peak)) * 32767)) for x in samples)
        w.writeframes(frames)
    print("geschrieben:", os.path.normpath(path), "%.2f s" % (len(samples) / RATE))


def smg_shot():
    # Kurzer, trockener Knall: heller Crack plus dumpfer Körper, schnell abklingend (Dauerfeuer).
    crack = env(highpass(noise(0.09), 1800), 0.0005, 70)
    body = env(lowpass(noise(0.14), 900), 0.001, 32)
    thump = env(tone(160, 70, 0.1), 0.001, 45)
    out = mix_into(list(crack), body, 0.0, 0.9)
    out = mix_into(out, thump, 0.0, 0.6)
    tail = env(lowpass(noise(0.2), 2500), 0.01, 18)
    return mix_into(out, tail, 0.02, 0.18)


def smg_reload():
    # Magazin raus, neues rein, Verschluss ziehen (passt zu 1,6 s Nachladezeit).
    out = silence(1.55)
    mix_into(out, click(0.05, 1500, 6000, 90), 0.12, 0.7)          # Haltetaste
    mix_into(out, env(lowpass(noise(0.12), 1500), 0.005, 25), 0.18, 0.5)  # Magazin rutscht
    mix_into(out, env(highpass(noise(0.25), 400), 0.02, 12), 0.45, 0.12)   # Stoff/Hand
    mix_into(out, click(0.06, 800, 5000, 70), 0.98, 1.0)            # Magazin rastet ein
    mix_into(out, env(tone(900, 600, 0.05), 0.0, 60), 0.98, 0.25)
    mix_into(out, click(0.05, 2000, 8000, 80), 1.26, 0.8)           # Verschluss zurück
    mix_into(out, click(0.07, 700, 4500, 60), 1.36, 1.0)            # Verschluss vor
    return out


def grenade_throw():
    # Stift klickt, dann ein kurzes Wusch.
    out = silence(0.45)
    mix_into(out, click(0.04, 2500, 9000, 100), 0.0, 0.8)
    mix_into(out, tone(3200, 2600, 0.03), 0.01, 0.08)
    whoosh = highpass(lowpass(noise(0.3), 1600), 300)
    whoosh = [x * math.sin(math.pi * i / len(whoosh)) for i, x in enumerate(whoosh)]
    return mix_into(out, whoosh, 0.12, 0.6)


def grenade_explosion():
    # Harter Anschlag, tiefer Druck, Grollen und ein paar Splitter im Nachhall.
    out = env(highpass(noise(0.08), 1200), 0.0005, 40)
    mix_into(out, env(lowpass(noise(1.8), 220), 0.004, 2.6), 0.0, 2.2)
    mix_into(out, env(tone(90, 32, 0.9), 0.002, 4.5), 0.0, 1.2)
    mix_into(out, env(lowpass(noise(1.4), 900), 0.01, 4.0), 0.02, 0.5)
    for _ in range(14):
        t = rng.uniform(0.15, 1.1)
        mix_into(out, click(0.03, 1500, 7000, 120), t, rng.uniform(0.04, 0.12))
    return lowpass(out, 6000)


def boom(seconds, crack_hz, body_hz, body_decay, thump_from, thump_to, tail=0.0):
    """Schuss-Grundform: Crack (hell), Körper (dumpf), tiefer Druck und optional ein langer Nachhall."""
    out = env(highpass(noise(min(seconds, 0.14)), crack_hz), 0.0005, 55)
    mix_into(out, env(lowpass(noise(seconds), body_hz), 0.001, body_decay), 0.0, 1.0)
    mix_into(out, env(tone(thump_from, thump_to, min(seconds, 0.3)), 0.001, 18), 0.0, 0.8)
    if tail > 0.0:
        mix_into(out, env(lowpass(noise(tail), 1800), 0.01, 5.0), 0.02, 0.22)
    return out


def revolver_shot():
    return boom(0.35, 1500, 1100, 13, 130, 45, tail=0.7)


def revolver_reload():
    # Eine Patrone in die Trommel, Trommel klickt eine Kammer weiter (0,45 s pro Patrone).
    out = silence(0.42)
    mix_into(out, env(highpass(noise(0.08), 1200), 0.004, 35), 0.04, 0.35)    # Patrone rutscht
    mix_into(out, env(tone(2600, 2350, 0.04), 0.0, 70), 0.12, 0.25)            # Messing an Stahl
    mix_into(out, click(0.04, 1800, 7000, 110), 0.27, 0.9)                     # Trommel rastet
    return out


def heavy_pistol_shot():
    return boom(0.24, 1700, 1000, 20, 150, 55, tail=0.35)


def shotgun_shot():
    # Breiter Knall, danach wird repetiert (Vorderschaft zurück und wieder vor).
    out = boom(0.55, 1100, 900, 7, 95, 35, tail=0.9)
    mix_into(out, click(0.07, 900, 5000, 55), 0.38, 0.7)                       # zurück
    mix_into(out, env(lowpass(noise(0.08), 2200), 0.005, 30), 0.4, 0.25)
    mix_into(out, click(0.07, 700, 4500, 50), 0.55, 0.85)                      # vor
    return out


def shotgun_reload():
    # Eine Patrone ins Röhrenmagazin (0,55 s pro Patrone).
    out = silence(0.5)
    mix_into(out, env(highpass(noise(0.12), 800), 0.01, 22), 0.05, 0.3)
    mix_into(out, click(0.05, 1200, 6000, 90), 0.24, 0.85)
    mix_into(out, env(tone(1800, 1500, 0.03), 0.0, 80), 0.24, 0.15)
    return out


def sawed_off_shot():
    return boom(0.5, 1300, 1000, 8, 100, 38, tail=0.8)


def sawed_off_reload():
    # Kippen, zwei Hülsen fallen, zwei Patronen rein, zuklappen (1,9 s).
    out = silence(1.85)
    mix_into(out, click(0.06, 900, 5000, 60), 0.08, 0.9)
    for t in (0.36, 0.43):
        mix_into(out, env(tone(rng.uniform(2300, 2700), 2100, 0.06), 0.0, 45), t, 0.2)
    for t in (0.9, 1.15):
        mix_into(out, env(highpass(noise(0.1), 900), 0.006, 30), t, 0.3)
        mix_into(out, click(0.03, 1500, 6000, 120), t + 0.08, 0.4)
    mix_into(out, click(0.07, 700, 4000, 50), 1.58, 1.0)
    return out


def bullpup_shot():
    return boom(0.18, 2000, 1300, 30, 170, 70, tail=0.25)


def compact_smg_shot():
    out = env(highpass(noise(0.06), 2200), 0.0004, 85)
    mix_into(out, env(lowpass(noise(0.09), 1100), 0.001, 48), 0.0, 0.8)
    mix_into(out, env(tone(190, 90, 0.07), 0.001, 60), 0.0, 0.45)
    return out


def dmr_shot():
    return boom(0.45, 1800, 1200, 9, 120, 40, tail=0.9)


def generate_m3():
    global rng
    rng = random.Random(4096)
    write("revolver_shot.wav", revolver_shot(), 0.9)
    write("revolver_reload.wav", revolver_reload(), 0.7)
    write("heavy_pistol_shot.wav", heavy_pistol_shot(), 0.88)
    write("shotgun_shot.wav", shotgun_shot(), 0.92)
    write("shotgun_reload.wav", shotgun_reload(), 0.7)
    write("sawed_off_shot.wav", sawed_off_shot(), 0.92)
    write("sawed_off_reload.wav", sawed_off_reload(), 0.75)
    write("bullpup_shot.wav", bullpup_shot(), 0.85)
    write("compact_smg_shot.wav", compact_smg_shot(), 0.8)
    write("dmr_shot.wav", dmr_shot(), 0.9)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    if "--m3" in __import__("sys").argv:
        generate_m3()
        raise SystemExit
    write("smg_shot.wav", smg_shot(), 0.85)
    write("smg_reload.wav", smg_reload(), 0.8)
    write("grenade_throw.wav", grenade_throw(), 0.6)
    write("grenade_explosion.wav", grenade_explosion(), 0.95)
