#!/usr/bin/env python3
"""Erzeugt alle Soundeffekte unter assets/audio neu (44,1 kHz, 16 Bit).

Ersetzt die alten, sehr einfachen Töne (22 kHz, ein Sinus/Rauschen pro Sound) durch
geschichtete Klänge: Knall-Transiente, Körper, Mechanik (Modal-Synthese aus gedämpften
Teiltönen), Raum (synthetische Impulsantwort mit frühen Reflexionen und Nachhall).
Gegnerrufe sind echte deutsche Sprache (Piper-TTS, Stimme „Thorsten“, Datensatz CC0),
in drei Stimmlagen tonhöhenverschoben.

Alles ist eigenes Material bzw. CC0, siehe assets/audio/CREDITS.md.

Aufruf (aus dem Repo-Root):
    pip install numpy scipy librosa soundfile piper-tts
    python3 tools/gen_sounds.py                 # alle Effekte
    python3 tools/gen_sounds.py --voices PFAD   # zusätzlich Stimmen, PFAD = de-thorsten-low.onnx

Der Zufall ist fest geseedet: gleicher Aufruf, gleiche Dateien.
Danach prüft tools/tests/check_audio_levels.py Pegel, Clipping und Schleifen.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import os
import sys
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio")
VOICE_DIR = os.path.join(OUT, "voices")

# Spitzenpegel je Kategorie (linear, < 1.0 = kein Clipping). Die Lautstärke im Spiel regeln
# weiter die Player (volume_db) und der SFX-Bus.
PEAK = {
	"gun": 0.93,
	"mech": 0.75,
	"step": 0.24,
	"land": 0.5,
	"melee": 0.85,
	"zap": 0.7,
	"vital": 0.85,
	"voice": 0.85,
}


# ---------------------------------------------------------------- Bausteine

def secs(n: float) -> int:
	return int(round(n * SR))


def t_axis(dur: float) -> np.ndarray:
	return np.arange(secs(dur)) / SR


def noise(rng: np.random.Generator, dur: float) -> np.ndarray:
	return rng.standard_normal(secs(dur))


def sos_filter(x: np.ndarray, kind: str, freq, order: int = 2) -> np.ndarray:
	sos = signal.butter(order, freq, btype=kind, fs=SR, output="sos")
	return signal.sosfilt(sos, x, axis=-1)


def lp(x, f, order=2):
	return sos_filter(x, "lowpass", f, order)


def hp(x, f, order=2):
	return sos_filter(x, "highpass", f, order)


def bp(x, lo, hi, order=2):
	return sos_filter(x, "bandpass", [lo, hi], order)


def decay(dur: float, tau: float, attack: float = 0.0005) -> np.ndarray:
	"""Exponentieller Abfall mit kurzem Anstieg (kein Knacken am Anfang)."""
	t = t_axis(dur)
	env = np.exp(-t / tau)
	if attack > 0:
		env *= np.clip(t / attack, 0.0, 1.0)
	return env


def place(dst: np.ndarray, src: np.ndarray, at: float, gain: float = 1.0) -> None:
	"""Mischt src ab Sekunde `at` in dst (beides mono oder beides stereo [2, n])."""
	start = secs(at)
	if start >= dst.shape[-1]:
		return
	n = min(src.shape[-1], dst.shape[-1] - start)
	dst[..., start:start + n] += src[..., :n] * gain


def modal(rng, freqs, taus, amps, dur, jitter=0.02) -> np.ndarray:
	"""Metall/Kunststoff-Klick: Summe gedämpfter Teiltöne mit zufälliger Phase."""
	t = t_axis(dur)
	out = np.zeros_like(t)
	for f, tau, a in zip(freqs, taus, amps):
		f *= 1.0 + rng.uniform(-jitter, jitter)
		out += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi)) * np.exp(-t / tau)
	# Anschlag: sehr kurzes Rauschen.
	strike = hp(noise(rng, dur), 2000) * decay(dur, 0.0008, 0.0001) * 0.6
	return (out + strike) * np.clip(t / 0.0002, 0, 1)


def click(rng, base: float, dur=0.06, bright=1.0, body=0.0) -> np.ndarray:
	"""Mechanischer Klick (Abzug, Magazinhalter, Verschluss) um `base` Hz."""
	ratios = [1.0, 1.58, 2.31, 3.17, 4.43]
	freqs = [base * r for r in ratios]
	taus = [0.012, 0.008, 0.006, 0.004, 0.003]
	amps = [1.0, 0.7 * bright, 0.5 * bright, 0.35 * bright, 0.2 * bright]
	out = modal(rng, freqs, taus, amps, dur)
	if body > 0:
		out += lp(noise(rng, dur), 400) * decay(dur, 0.01) * body * 3
	return out


def scrape(rng, dur, lo=1200, hi=6000, grain=0.35) -> np.ndarray:
	"""Reibung Metall auf Metall/Kunststoff: gefiltertes Rauschen mit körniger Hüllkurve."""
	n = secs(dur)
	x = bp(noise(rng, dur), lo, hi)
	# Körnung: zufällige Pulse, geglättet.
	g = (rng.random(n) < 0.004).astype(float) * rng.uniform(0.5, 1.0, n)
	g = lp(g, 300) * 60
	shape = np.sin(np.linspace(0, np.pi, n)) ** 0.7
	return x * shape * ((1 - grain) + grain * np.clip(g, 0, 2))


def grit(rng, dur, density=0.02, lo=2500, hi=9000, tau=0.06) -> np.ndarray:
	"""Kies/Sand unter der Sohle: viele winzige Knackser."""
	n = secs(dur)
	imp = (rng.random(n) < density) * rng.standard_normal(n)
	return bp(imp, lo, hi) * decay(dur, tau, 0.002)


def saturate(x: np.ndarray, drive: float) -> np.ndarray:
	return np.tanh(x * drive) / np.tanh(drive)


def fade_out(x: np.ndarray, dur: float = 0.02) -> np.ndarray:
	n = min(secs(dur), x.shape[-1])
	x = x.copy()
	x[..., -n:] *= np.linspace(1, 0, n) ** 2
	return x


def make_ir(rng, length: float, rt60: float, early: list, damp_hz: float, stereo: bool,
		predelay: float = 0.0) -> np.ndarray:
	"""Synthetische Impulsantwort: frühe Reflexionen (Hauswände) plus dichter Nachhall,
	der oben schneller abklingt (Luft und Fassaden schlucken Höhen)."""
	chans = 2 if stereo else 1
	n = secs(length)
	ir = np.zeros((chans, n))
	t = np.arange(n) / SR
	for c in range(chans):
		tail = rng.standard_normal(n) * np.exp(-6.91 * t / rt60)
		dark = lp(tail, damp_hz)
		bright = hp(tail, damp_hz) * np.exp(-6.91 * t / (rt60 * 0.35))
		late = (dark + bright * 0.5) * np.clip((t - predelay) / 0.03, 0, 1)
		ir[c] = late * 0.35
		for at, gain in early:
			at = at * (1.0 + (0.04 * (c - 0.5) if stereo else 0))
			i = secs(predelay + at)
			if i < n:
				ir[c, i] += gain * rng.choice([-1, 1])
	ir[:, 0] = 1.0  # Direktschall
	return ir if stereo else ir[0]


def convolve(dry: np.ndarray, ir: np.ndarray, wet: float) -> np.ndarray:
	"""Faltung mit dem Raum. dry mono → Ergebnis mono oder stereo (wie ir)."""
	if ir.ndim == 1:
		w = signal.fftconvolve(dry, ir)[:dry.shape[-1]]
		w /= np.max(np.abs(w)) + 1e-9
		return dry / (np.max(np.abs(dry)) + 1e-9) * (1 - wet) + w * wet
	out = np.stack([signal.fftconvolve(dry, ir[c])[:dry.shape[-1]] for c in range(2)])
	out /= np.max(np.abs(out)) + 1e-9
	d = dry / (np.max(np.abs(dry)) + 1e-9)
	return d[None, :] * (1 - wet) + out * wet


def normalize(x: np.ndarray, peak: float) -> np.ndarray:
	x = x - np.mean(x, axis=-1, keepdims=True)  # kein Gleichanteil
	return x * (peak / (np.max(np.abs(x)) + 1e-9))


def write_wav(path: str, x: np.ndarray, sr: int = SR) -> None:
	x = np.clip(x, -1.0, 1.0)
	data = (x * 32767.0).round().astype("<i2")
	chans = 1 if data.ndim == 1 else data.shape[0]
	frames = data if data.ndim == 1 else data.T.reshape(-1)
	buf = io.BytesIO()
	with wave.open(buf, "wb") as w:
		w.setnchannels(chans)
		w.setsampwidth(2)
		w.setframerate(sr)
		w.writeframes(frames.tobytes())
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "wb") as f:
		f.write(buf.getvalue())
	write_import(path, loop=False)


def write_import(path: str, loop: bool, loop_end: int = -1) -> None:
	"""Legt die .import-Datei an (wie der Godot-Editor), damit die Datei ohne erneuten
	Import-Lauf in Git konsistent ist. Eine vorhandene uid bleibt erhalten."""
	imp = path + ".import"
	rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
	uid = None
	if os.path.exists(imp):
		for line in open(imp, encoding="utf-8"):
			if line.startswith("uid="):
				uid = line.strip().split("=", 1)[1].strip('"')
	if uid is None:
		uid = "uid://" + godot_uid(rel)
	md5 = hashlib.md5(("res://" + rel).encode()).hexdigest()
	name = os.path.basename(path)
	dest = f"res://.godot/imported/{name}-{md5}.sample"
	text = f"""[remap]

importer="wav"
type="AudioStreamWAV"
uid="{uid}"
path="{dest}"

[deps]

source_file="res://{rel}"
dest_files=["{dest}"]

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode={2 if loop else 0}
edit/loop_begin=0
edit/loop_end={loop_end}
compress/mode=2
"""
	with open(imp, "w", encoding="utf-8", newline="\n") as f:
		f.write(text)


def godot_uid(seed: str) -> str:
	"""Godot-UID-Text (Basis 34 wie ResourceUID::id_to_text), fest aus dem Pfad abgeleitet."""
	chars = "abcdefghijklmnopqrstuvwxy012345678"
	v = int(hashlib.sha1(seed.encode()).hexdigest()[:15], 16) & 0x7FFFFFFFFFFFFFFF
	s = ""
	while True:
		s = chars[v % 34] + s
		v //= 34
		if v == 0:
			break
	return s


# ---------------------------------------------------------------- Waffen

def gunshot(rng, heavy: bool) -> np.ndarray:
	"""Trockener Schuss (mono): Überschallknall, Mündungsknall, Körper, Tiefbass, Mechanik."""
	dur = 0.6 if heavy else 0.4
	t = t_axis(dur)
	x = np.zeros(secs(dur))
	# 1) Knall: extrem kurze, breitbandige Transiente (N-Welle beim Gewehr).
	crack = hp(noise(rng, dur), 1500) * decay(dur, 0.0007 if not heavy else 0.0011, 0.00005)
	x += crack * (1.3 if heavy else 1.0)
	if heavy:
		nwave = np.where(t < 0.0012, 1.0 - 2.0 * t / 0.0012, 0.0)
		x += hp(nwave, 300) * 1.2
	# 2) Mündungsknall: Rauschen im Mittenband, sehr schnell weg.
	x += bp(noise(rng, dur), 250, 5000) * decay(dur, 0.012 if not heavy else 0.02, 0.0002) * 1.4
	# 3) Körper: tiefer werdender Druckstoß.
	f0, f1 = (150.0, 48.0) if not heavy else (120.0, 36.0)
	tau_b = 0.05 if not heavy else 0.11
	freq = f1 + (f0 - f1) * np.exp(-t / 0.02)
	phase = 2 * np.pi * np.cumsum(freq) / SR
	body = (np.sin(phase) + 0.35 * np.sin(2 * phase)) * decay(dur, tau_b, 0.0008)
	x += body * (1.1 if heavy else 0.9)
	# 4) Tiefbass-Schub.
	x += lp(noise(rng, dur), 140, 4) * decay(dur, 0.07 if not heavy else 0.16, 0.002) * 4.0
	# 5) Mechanik: Verschluss/Schlitten (nur die Pistole repetiert selbst).
	if not heavy:
		place(x, click(rng, 2300, 0.05, 0.9) * 0.18, 0.004)
		place(x, click(rng, 1900, 0.06, 0.8, body=0.2) * 0.22, 0.05)
	else:
		place(x, click(rng, 1400, 0.08, 0.6) * 0.1, 0.003)
	x = saturate(x / np.max(np.abs(x)) * 1.6, 2.2)
	x[:secs(0.0003)] *= np.linspace(0, 1, secs(0.0003))  # kein Sprung am ersten Sample
	return fade_out(x, 0.05)


def outdoor_ir(rng, heavy: bool, stereo: bool) -> np.ndarray:
	"""Straßenschlucht: Echos von Hauswänden, beim Gewehr rollt der Hall länger nach."""
	if heavy:
		early = [(0.021, 0.55), (0.047, 0.4), (0.083, 0.32), (0.131, 0.28), (0.22, 0.2),
				(0.36, 0.17), (0.55, 0.11), (0.81, 0.07)]
		return make_ir(rng, 2.6, 2.2, early, 900, stereo)
	early = [(0.017, 0.5), (0.038, 0.38), (0.061, 0.3), (0.097, 0.24), (0.16, 0.16), (0.27, 0.1)]
	return make_ir(rng, 1.3, 0.95, early, 1400, stereo)


def make_guns(rng) -> list:
	made = []
	for heavy, name in ((False, "pistol"), (True, "sniper")):
		dry = gunshot(rng, heavy)
		total = 1.4 if not heavy else 2.6
		pad = np.zeros(secs(total))
		pad[:dry.size] = dry
		# Spieler (2D, stereo): Hall breit, der Knall bleibt vorne.
		ir = outdoor_ir(rng, heavy, stereo=True)
		wet = 0.32 if not heavy else 0.42
		st = convolve(pad, ir, wet)
		st = fade_out(normalize(st, PEAK["gun"]), 0.15)
		write_wav(os.path.join(OUT, f"{name}_shot.wav"), st)
		made.append(f"{name}_shot.wav")
		# Gegner (3D, mono): mehr Raum, weniger Knall-Höhen, wirkt aus der Entfernung gehört.
		ir_m = outdoor_ir(rng, heavy, stereo=False)
		mono = convolve(lp(pad, 7000), ir_m, wet + 0.12)
		mono = fade_out(normalize(mono, PEAK["gun"]), 0.15)
		write_wav(os.path.join(OUT, f"{name}_shot_world.wav"), mono)
		made.append(f"{name}_shot_world.wav")
	return made


def small_room(rng, stereo=True):
	return make_ir(rng, 0.35, 0.25, [(0.004, 0.3), (0.009, 0.2), (0.015, 0.12)], 3000, stereo)


def make_mechanics(rng) -> list:
	# Leerklick: Abzug fällt, Hahn schlägt ins Leere.
	dur = 0.18
	x = np.zeros(secs(dur))
	place(x, click(rng, 1700, 0.04, 0.6) * 0.35, 0.0)
	place(x, click(rng, 2600, 0.08, 1.0, body=0.3), 0.012)
	x = convolve(x, small_room(rng), 0.15)
	write_wav(os.path.join(OUT, "pistol_empty.wav"), fade_out(normalize(x, PEAK["mech"])))

	# Pistole nachladen (reload_time 1,2 s): Magazin raus, rein, Schlitten ziehen und los.
	dur = 1.15
	x = np.zeros(secs(dur))
	place(x, click(rng, 3200, 0.04, 0.8) * 0.5, 0.04)            # Magazinhalter
	place(x, scrape(rng, 0.14, 1500, 7000) * 0.25, 0.07)           # Magazin rutscht raus
	place(x, click(rng, 1100, 0.05, 0.5, body=0.2) * 0.3, 0.2)    # letzter Anschlag
	place(x, scrape(rng, 0.09, 1200, 6000) * 0.22, 0.46)           # neues Magazin rein
	place(x, click(rng, 900, 0.09, 0.9, body=0.6) * 0.9, 0.56)    # einrasten
	place(x, scrape(rng, 0.1, 1800, 8000) * 0.3, 0.8)              # Schlitten zurück
	place(x, click(rng, 2100, 0.05, 0.8) * 0.45, 0.89)            # hinterer Anschlag
	place(x, click(rng, 1500, 0.12, 1.0, body=0.5) * 1.0, 0.95)   # Schlitten schnellt vor
	x = convolve(x, small_room(rng), 0.18)
	write_wav(os.path.join(OUT, "pistol_reload.wav"), fade_out(normalize(x, PEAK["mech"])))

	# Repetiergewehr nachladen (reload_time 2,4 s).
	dur = 2.25
	x = np.zeros(secs(dur))
	place(x, click(rng, 1300, 0.07, 0.7, body=0.3) * 0.7, 0.15)   # Kammer hoch
	place(x, scrape(rng, 0.22, 900, 5000) * 0.35, 0.3)             # Verschluss zurück
	place(x, click(rng, 1000, 0.1, 0.9, body=0.6) * 0.9, 0.52)    # Anschlag hinten
	brass = [4200, 6900, 9800, 12500]
	for at, g in ((0.6, 0.35), (0.86, 0.22), (1.0, 0.14), (1.08, 0.08)):  # Hülse springt
		place(x, modal(rng, brass, [0.05, 0.035, 0.025, 0.018], [1, 0.6, 0.4, 0.25], 0.12, 0.05) * g, at)
	place(x, scrape(rng, 0.12, 1500, 6000) * 0.2, 1.15)            # Patrone rein
	place(x, click(rng, 2400, 0.05, 0.8) * 0.5, 1.28)
	place(x, scrape(rng, 0.2, 900, 5000) * 0.35, 1.5)              # Verschluss vor
	place(x, click(rng, 1100, 0.1, 0.9, body=0.5) * 0.85, 1.71)
	place(x, click(rng, 1250, 0.09, 0.8, body=0.7) * 1.0, 1.9)    # Kammer runter, verriegelt
	x = convolve(x, small_room(rng), 0.18)
	write_wav(os.path.join(OUT, "sniper_reload.wav"), fade_out(normalize(x, PEAK["mech"])))
	return ["pistol_empty.wav", "pistol_reload.wav", "sniper_reload.wav"]


# ---------------------------------------------------------------- Bewegung

def street_ir(rng):
	return make_ir(rng, 0.5, 0.35, [(0.006, 0.25), (0.014, 0.15), (0.027, 0.1)], 2500, False)


def footstep(rng, weight: float) -> np.ndarray:
	"""Stiefel auf rauem Beton: Ferse, Abrollen, Sohle, Kies."""
	dur = 0.32
	x = np.zeros(secs(dur))
	heel = lp(noise(rng, dur), 380, 4) * decay(dur, 0.012, 0.0015) * 3.0
	t = t_axis(dur)
	heel += np.sin(2 * np.pi * rng.uniform(75, 95) * t) * decay(dur, 0.018, 0.002) * 0.6
	heel += bp(noise(rng, dur), 700, 2500) * decay(dur, 0.006, 0.0005) * 0.5
	place(x, heel * weight, 0.0)
	toe_at = rng.uniform(0.055, 0.085)
	toe = lp(noise(rng, dur), 600, 4) * decay(dur, 0.01, 0.002) * 1.6
	toe += bp(noise(rng, dur), 1200, 4000) * decay(dur, 0.006, 0.001) * 0.6
	place(x, toe * rng.uniform(0.45, 0.65) * weight, toe_at)
	place(x, scrape(rng, rng.uniform(0.06, 0.1), 2000, 7500, 0.6) * 0.12, toe_at - 0.01)
	place(x, grit(rng, 0.2, 0.015, tau=0.05) * 0.9, 0.0)
	x = convolve(x, street_ir(rng), 0.12)
	return fade_out(normalize(x, PEAK["step"]), 0.04)


def land(rng) -> np.ndarray:
	"""Aufkommen nach Sprung/Fall: beide Füße, Knie federn, Ausrüstung klappert, Kies."""
	dur = 0.55
	x = np.zeros(secs(dur))
	for at, g in ((0.0, 1.0), (rng.uniform(0.018, 0.035), 0.8)):
		th = lp(noise(rng, dur), 220, 4) * decay(dur, 0.035, 0.002) * 4.0
		th += np.sin(2 * np.pi * 60 * t_axis(dur)) * decay(dur, 0.05, 0.003) * 0.7
		th += bp(noise(rng, dur), 500, 2500) * decay(dur, 0.01, 0.001) * 0.6
		place(x, th * g, at)
	place(x, bp(noise(rng, 0.2), 400, 2200) * decay(0.2, 0.05, 0.01) * 0.3, 0.03)  # Kleidung
	place(x, modal(rng, [2900, 4700, 6100], [0.03, 0.02, 0.015], [1, 0.6, 0.3], 0.1) * 0.06, 0.05)
	place(x, grit(rng, 0.3, 0.03, tau=0.09) * 1.4, 0.0)
	x = convolve(x, street_ir(rng), 0.15)
	return fade_out(normalize(x, PEAK["land"]), 0.06)


def make_movement(rng) -> list:
	made = []
	for i, w in enumerate((1.0, 0.92, 1.06), start=1):
		write_wav(os.path.join(OUT, f"footstep_0{i}.wav"), footstep(rng, w))
		made.append(f"footstep_0{i}.wav")
	for i in (1, 2):
		write_wav(os.path.join(OUT, f"land_0{i}.wav"), land(rng))
		made.append(f"land_0{i}.wav")
	return made


# ---------------------------------------------------------------- Nahkampf und EMP

def make_melee(rng) -> list:
	# Schlag-Wusch: Luft, Stoff, Band wandert nach oben und wieder runter.
	dur = 0.32
	n = secs(dur)
	src = noise(rng, dur)
	out = np.zeros(n)
	block = 256
	centre = 350 + 1400 * np.sin(np.linspace(0, np.pi, n)) ** 2
	zi = None
	for s in range(0, n, block):
		f = float(np.mean(centre[s:s + block]))
		sos = signal.butter(2, [f * 0.6, f * 1.6], btype="bandpass", fs=SR, output="sos")
		if zi is None:
			zi = np.zeros((sos.shape[0], 2))
		out[s:s + block], zi = signal.sosfilt(sos, src[s:s + block], zi=zi)
	env = np.sin(np.linspace(0, np.pi, n)) ** 2.2
	cloth = bp(noise(rng, dur), 1500, 6000) * env * 0.15
	x = out * env + cloth
	write_wav(os.path.join(OUT, "melee_swing.wav"), fade_out(normalize(x, PEAK["melee"] * 0.7)))

	# Treffer/Körper fällt: tiefer Schlag, Haut-Klatschen, Stoff.
	dur = 0.4
	t = t_axis(dur)
	x = lp(noise(rng, dur), 180, 4) * decay(dur, 0.045, 0.001) * 5
	x += np.sin(2 * np.pi * (55 + 40 * np.exp(-t / 0.02)) * t) * decay(dur, 0.06, 0.0015) * 1.2
	x += bp(noise(rng, dur), 1200, 6000) * decay(dur, 0.005, 0.0002) * 0.9
	x += bp(noise(rng, dur), 250, 900) * decay(dur, 0.025, 0.001) * 0.9
	x += bp(noise(rng, dur), 600, 3000) * decay(dur, 0.08, 0.01) * 0.12
	x = saturate(x / np.max(np.abs(x)) * 1.5, 1.8)
	x = convolve(x, street_ir(rng), 0.1)
	write_wav(os.path.join(OUT, "melee_thud.wav"), fade_out(normalize(x, PEAK["melee"] * 0.75)))

	# EMP-Betäubung: Lichtbogen mit Netzbrummen, Knistern, Zischen und Aussetzern.
	dur = 0.75
	n = secs(dur)
	t = t_axis(dur)
	buzz_ph = 2 * np.pi * 100 * t + 0.6 * np.sin(2 * np.pi * 7 * t)
	buzz = np.sign(np.sin(buzz_ph)) * (np.abs(np.sin(buzz_ph)) ** 0.3)
	buzz = bp(buzz, 150, 3500) * 0.5
	imp = (rng.random(n) < 0.012) * rng.standard_normal(n) * 4
	crack = bp(imp, 1800, 9000) + bp(imp, 500, 1500) * 0.5
	sizzle = hp(noise(rng, dur), 5000) * 0.25
	gate = lp((rng.random(n) < 0.0009).astype(float), 25)
	gate = np.clip(gate / (np.max(gate) + 1e-9) * 1.5, 0.15, 1.0)
	env = decay(dur, 0.32, 0.004) * (1 + 0.6 * np.exp(-t / 0.03))
	x = (buzz + crack + sizzle * gate) * env
	x = saturate(x / np.max(np.abs(x)) * 1.4, 1.6)
	write_wav(os.path.join(OUT, "emp_zap.wav"), fade_out(normalize(x, PEAK["zap"]), 0.08))
	return ["melee_swing.wav", "melee_thud.wav", "emp_zap.wav"]


# ---------------------------------------------------------------- Vitalwerte

def make_vitals(rng) -> list:
	# Herzschlag „lub-dub“, wie durch den eigenen Brustkorb gehört (sehr tief, dumpf).
	dur = 0.6
	t = t_axis(dur)
	x = np.zeros(secs(dur))
	for at, f, tau, g in ((0.0, 52, 0.045, 1.0), (0.19, 66, 0.032, 0.7)):
		f_t = f * (1 + 0.5 * np.exp(-t / 0.012))
		ph = 2 * np.pi * np.cumsum(f_t) / SR
		beat = np.sin(ph) * decay(dur, tau, 0.006)
		beat += lp(noise(rng, dur), 120, 4) * decay(dur, tau * 0.6, 0.004) * 2.5
		beat += bp(noise(rng, dur), 150, 400) * decay(dur, 0.01, 0.002) * 0.25
		place(x, beat * g, at)
	x = lp(x, 260, 4)
	write_wav(os.path.join(OUT, "heartbeat.wav"), fade_out(normalize(x, PEAK["vital"]), 0.05))

	# Schwerer Atem als Schleife: Luft durch Mund/Rachen (Rauschen durch Formanten).
	length = 2.4
	n = secs(length)
	t = t_axis(length)
	src = noise(rng, length)
	def tract(sig, formants, bws, gains):
		out = np.zeros_like(sig)
		for f, b, g in zip(formants, bws, gains):
			out += bp(sig, f - b / 2, f + b / 2) * g
		return out
	inhale = tract(src, [700, 1900, 3200, 5200], [500, 700, 900, 2500], [0.6, 0.8, 0.6, 0.5])
	exhale = tract(src, [520, 1250, 2400, 4000], [400, 500, 700, 1500], [1.0, 0.8, 0.45, 0.2])
	env_in = np.where(t < 0.85, np.sin(np.clip(t / 0.85, 0, 1) * np.pi) ** 1.5, 0.0) * 0.7
	ex_t = np.clip((t - 1.0) / 1.15, 0, 1)
	env_ex = np.where((t > 1.0) & (t < 2.15), np.sin(ex_t * np.pi) ** 1.3 * (1 - 0.3 * ex_t), 0.0)
	# Leichtes Stimmbandknarzen am Anfang des Ausatmens.
	creak = np.sin(2 * np.pi * 95 * t) * (np.abs(np.sin(2 * np.pi * 47 * t)) ** 4)
	creak = bp(creak, 200, 1200) * env_ex * np.exp(-np.clip(t - 1.0, 0, None) / 0.25) * 0.08
	x = inhale * env_in + exhale * env_ex + creak
	x = normalize(x, PEAK["vital"] * 0.85)
	x[:secs(0.005)] *= np.linspace(0, 1, secs(0.005))
	x[-secs(0.005):] *= np.linspace(1, 0, secs(0.005))
	write_wav(os.path.join(OUT, "breath_loop.wav"), x)
	write_import(os.path.join(OUT, "breath_loop.wav"), loop=True, loop_end=n)

	# EKG-Dauerton: ganzzahlig viele Perioden, damit die Schleife nahtlos ist. Kleiner
	# Monitor-Lautsprecher: Grundton plus abfallende Obertöne, kein Bass.
	freq = 980.0
	periods = 98
	n = int(round(SR * periods / freq))  # 4410 Samples = genau 98 Perioden
	ph = 2 * np.pi * periods * np.arange(n) / n
	x = (np.sin(ph) + 0.18 * np.sin(2 * ph + 0.3) + 0.09 * np.sin(3 * ph + 1.1)
			+ 0.04 * np.sin(4 * ph + 0.5) + 0.02 * np.sin(5 * ph + 2.0))
	x = normalize(x, 0.55)
	write_wav(os.path.join(OUT, "flatline_loop.wav"), x)
	write_import(os.path.join(OUT, "flatline_loop.wav"), loop=True, loop_end=n)
	return ["heartbeat.wav", "breath_loop.wav", "flatline_loop.wav"]


# ---------------------------------------------------------------- Stimmen

# Muss zu Enemy.BARKS passen: gleiche Reihenfolge, damit Text und Ton übereinstimmen.
# hurt/death sind Laute, die Piper als Wort ausspricht.
VOICE_LINES = {
	"suspicious": ["Hm?", "Was war das?", "Hallo?"],
	"investigate": ["Wer ist da?", "Ich seh mal nach.", "Komm raus!"],
	"alert": ["Da ist er!", "Hey! Stehen bleiben!", "Eindringling!"],
	"search": ["Wo bist du?", "Sucht ihn!", "Der ist noch hier."],
	"lost": ["Weg.", "Einbildung.", "Zurück auf Posten."],
	"body": ["Mann am Boden!", "Die haben ihn erwischt!", "Alarm! Einer liegt hier!"],
	"cover": ["Deckung!", "Lade nach!", "Gib mir Deckung!"],
	"hurt": ["Ah!", "Uff!", "Verdammt!"],
	"death": ["Ahhh.", "Ohhh.", "Nein."],
}
# Sprechtempo (Piper length_scale, kleiner = schneller) und Lautstärke je Ruf.
LINE_STYLE = {
	"suspicious": (1.1, 0.75), "investigate": (1.0, 0.85), "alert": (0.85, 1.0),
	"search": (1.0, 0.8), "lost": (1.15, 0.7), "body": (0.9, 1.0), "cover": (0.85, 1.0),
	"hurt": (0.8, 1.0), "death": (1.6, 0.9),
}
# Stimmlagen in Halbtönen. EnemySounds wählt die nächste und gleicht den Rest über die Abspielrate aus.
VOICE_SHIFTS = {"low": -4.0, "mid": -1.5, "high": 0.5}
VOICE_SR = 22050


def make_voices(model_path: str) -> list:
	import librosa
	from piper import PiperVoice
	from piper.config import SynthesisConfig

	voice = PiperVoice.load(model_path)
	made = []
	for line, texts in VOICE_LINES.items():
		speed, gain = LINE_STYLE[line]
		for i, text in enumerate(texts):
			cfg = SynthesisConfig(length_scale=speed, noise_scale=0.6, noise_w_scale=0.7)
			chunks = list(voice.synthesize(text, syn_config=cfg))
			pcm = np.concatenate([c.audio_float_array for c in chunks]).astype(np.float64)
			sr = chunks[0].sample_rate
			pcm = librosa.resample(pcm, orig_sr=sr, target_sr=VOICE_SR)
			if line == "death":
				# Langgezogenes Stöhnen, das am Ende abfällt und leiser wird.
				pcm = librosa.effects.time_stretch(pcm, rate=0.5)
				pcm *= np.linspace(1.0, 0.25, pcm.size) ** 1.5
			for tag, semis in VOICE_SHIFTS.items():
				y = librosa.effects.pitch_shift(pcm, sr=VOICE_SR, n_steps=semis) if semis else pcm
				y = sos_hp(y, 110)
				# Etwas Druck: weicher Kompressor über tanh, dann Stille hinten kürzen.
				y = saturate(y / (np.max(np.abs(y)) + 1e-9) * 1.4, 1.3)
				y = trim_silence(y)
				y = normalize(y, PEAK["voice"] * gain)
				name = f"{line}_{i}_{tag}.wav"
				write_wav(os.path.join(VOICE_DIR, name), fade_out(y, 0.03), VOICE_SR)
				made.append("voices/" + name)
	return made


def sos_hp(x, f):
	sos = signal.butter(2, f, btype="highpass", fs=VOICE_SR, output="sos")
	return signal.sosfilt(sos, x)


def trim_silence(y, thresh=0.01):
	idx = np.where(np.abs(y) > thresh * np.max(np.abs(y)))[0]
	if idx.size == 0:
		return y
	a = max(0, idx[0] - int(0.01 * VOICE_SR))
	b = min(y.size, idx[-1] + int(0.06 * VOICE_SR))
	return y[a:b]


# ---------------------------------------------------------------- Ablauf

def main() -> int:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--voices", metavar="ONNX", help="Piper-Modell de-thorsten-low.onnx für die Gegnerrufe")
	args = ap.parse_args()
	rng = np.random.default_rng(20261028)
	made = []
	made += make_guns(rng)
	made += make_mechanics(rng)
	made += make_movement(rng)
	made += make_melee(rng)
	made += make_vitals(rng)
	if args.voices:
		made += make_voices(args.voices)
	print(f"{len(made)} Dateien geschrieben nach {os.path.relpath(OUT, ROOT)}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
