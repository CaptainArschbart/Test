#!/usr/bin/env python3
"""Prüft alle WAVs unter assets/audio: Format, Pegel, Clipping, Gleichanteil, Stille,
Schleifen-Naht und dass jede Datei, die der Code erwartet, da ist.

Aufruf aus dem Repo-Root:  python3 tools/tests/check_audio_levels.py
Exitcode 0 = grün. Braucht nur numpy.
"""

from __future__ import annotations

import os
import re
import sys
import wave

import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUDIO = os.path.join(ROOT, "assets", "audio")

LINES = ["suspicious", "investigate", "alert", "search", "lost", "body", "cover", "hurt", "death"]
TAGS = ["low", "mid", "high"]
EXPECTED = [
	"pistol_shot.wav", "pistol_shot_world.wav", "sniper_shot.wav", "sniper_shot_world.wav",
	"pistol_reload.wav", "sniper_reload.wav", "pistol_empty.wav",
	"footstep_01.wav", "footstep_02.wav", "footstep_03.wav", "land_01.wav", "land_02.wav",
	"melee_swing.wav", "melee_thud.wav", "emp_zap.wav",
	"heartbeat.wav", "breath_loop.wav", "flatline_loop.wav",
] + [f"voices/{l}_{i}_{t}.wav" for l in LINES for i in range(3) for t in TAGS]
LOOPS = ["breath_loop.wav", "flatline_loop.wav"]

checks = 0
fails = 0


def check(ok: bool, msg: str) -> None:
	global checks, fails
	checks += 1
	if not ok:
		fails += 1
		print("FAIL", msg)


def read(path: str):
	with wave.open(path, "rb") as w:
		ch, width, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
		raw = w.readframes(n)
	data = np.frombuffer(raw, "<i2").astype(np.float64) / 32768.0
	if ch == 2:
		data = data.reshape(-1, 2).T
	return data, sr, ch, width


def db(x: float) -> float:
	return 20 * np.log10(max(x, 1e-9))


def main() -> int:
	print(f"{'Datei':38s} {'kHz':>5s} {'Kan':>3s} {'Länge':>6s} {'Peak dB':>8s} {'RMS dB':>7s}")
	for rel in EXPECTED:
		path = os.path.join(AUDIO, rel)
		check(os.path.exists(path), f"{rel} fehlt")
		check(os.path.exists(path + ".import"), f"{rel}.import fehlt")
		if not os.path.exists(path):
			continue
		x, sr, ch, width = read(path)
		mono = x if x.ndim == 1 else x.mean(axis=0)
		peak = float(np.max(np.abs(x)))
		rms = float(np.sqrt(np.mean(mono ** 2)))
		dur = mono.size / sr
		print(f"{rel:38s} {sr / 1000:5.1f} {ch:3d} {dur:6.2f} {db(peak):8.1f} {db(rms):7.1f}")
		check(width == 2, f"{rel}: nicht 16 Bit")
		check(sr >= 22050, f"{rel}: Abtastrate {sr} zu niedrig")
		check(peak < 0.99, f"{rel}: Clipping (Peak {peak:.3f})")
		check(db(peak) > -18, f"{rel}: zu leise (Peak {db(peak):.1f} dB)")
		clipped = int(np.sum(np.abs(x) >= 32766 / 32768))
		check(clipped == 0, f"{rel}: {clipped} Samples am Anschlag")
		check(abs(float(np.mean(mono))) < 0.01, f"{rel}: Gleichanteil {np.mean(mono):.4f}")
		check(0.05 <= dur <= 3.0, f"{rel}: Länge {dur:.2f} s")
		if rel not in LOOPS:
			# Kein Knacken am Ende: letzte 2 ms leise.
			tail = np.max(np.abs(mono[-max(1, sr // 500):]))
			check(tail < 0.02, f"{rel}: endet nicht in Stille ({tail:.3f})")
			# Kein Knacken am Anfang.
			check(abs(mono[0]) < 0.05, f"{rel}: beginnt mit Sprung ({mono[0]:.3f})")
		# Gemessene Rohdaten der 3D-Sounds müssen mono sein (AudioStreamPlayer3D).
		if rel.startswith("voices/") or "world" in rel or rel.startswith(("footstep", "land", "melee", "emp")):
			check(ch == 1, f"{rel}: 3D-Sound sollte mono sein")
	for rel in LOOPS:
		path = os.path.join(AUDIO, rel)
		if not os.path.exists(path):
			continue
		x, sr, ch, _ = read(path)
		mono = x if x.ndim == 1 else x.mean(axis=0)
		# Naht: Sprung vom letzten zum ersten Sample nicht größer als typische Sample-Schritte.
		jump = abs(mono[-1] - mono[0])
		typical = float(np.percentile(np.abs(np.diff(mono)), 99.5))
		check(jump <= typical * 1.5 + 1e-3, f"{rel}: Schleifen-Naht {jump:.4f} > {typical:.4f}")
		imp = open(path + ".import", encoding="utf-8").read()
		check("edit/loop_mode=2" in imp, f"{rel}: Import ohne Schleife")
		m = re.search(r"edit/loop_end=(-?\d+)", imp)
		check(m is not None and int(m.group(1)) == mono.size, f"{rel}: loop_end passt nicht zur Länge")
	# Code verweist nur auf vorhandene Dateien.
	for dirpath, _dirs, files in os.walk(os.path.join(ROOT, "scenes")):
		for f in files:
			if not f.endswith((".gd", ".tscn", ".tres")):
				continue
			text = open(os.path.join(dirpath, f), encoding="utf-8").read()
			for ref in re.findall(r"res://assets/audio/[\w/]+\.wav", text):
				check(os.path.exists(os.path.join(ROOT, ref[len("res://"):])), f"{f}: {ref} fehlt")
	print(f"CHECKS {checks} FAILS {fails}")
	return 1 if fails else 0


if __name__ == "__main__":
	sys.exit(main())
