extends RefCounted
## Prozedurale Auto-Sounds: Motor-Schleife (tiefes Brummen, Tonhöhe folgt dem Tempo über
## pitch_scale) und Hupe (zwei Töne). Wird einmal erzeugt und geteilt. Per preload benutzt.

const SoundGen := preload("res://scenes/enemies/enemy_sounds.gd")

static var _engine: AudioStreamWAV
static var _horn: AudioStreamWAV
static var _hit: AudioStreamWAV


## Eine Sekunde Motor, nahtlos schleifbar (alle Frequenzen ganzzahlig in Hz).
static func engine_loop() -> AudioStreamWAV:
	if _engine != null:
		return _engine
	var rate := SoundGen.MIX_RATE
	var n := rate
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	for i: int in n:
		var t := float(i) / rate
		# Zündfolge: Grundton 48 Hz mit Obertönen, leicht pulsierend, dazu gefiltertes Rauschen.
		var v := sin(TAU * 48.0 * t) * 0.6 + sin(TAU * 96.0 * t) * 0.35 + sin(TAU * 144.0 * t) * 0.18
		v += signf(sin(TAU * 24.0 * t)) * 0.12
		v *= 0.75 + 0.25 * sin(TAU * 8.0 * t)
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.08
		samples[i] = v + low * 0.5
	_engine = SoundGen._to_stream(samples, 0.7)
	_engine.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_engine.loop_begin = 0
	_engine.loop_end = n
	return _engine


static func horn() -> AudioStreamWAV:
	if _horn != null:
		return _horn
	var rate := SoundGen.MIX_RATE
	var n := int(rate * 0.55)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i: int in n:
		var t := float(i) / rate
		var env := minf(t / 0.02, 1.0) * minf((0.55 - t) / 0.06, 1.0)
		var v := 0.0
		for f: float in [415.0, 523.0]:
			# Rechteckig und etwas schnarrend wie eine billige Hupe.
			v += clampf(sin(TAU * f * t) * 3.0, -1.0, 1.0) * 0.5
		samples[i] = v * env
	_horn = SoundGen._to_stream(samples, 0.8)
	return _horn


## Dumpfer Aufprall (Auto trifft jemanden).
static func hit() -> AudioStreamWAV:
	if _hit != null:
		return _hit
	_hit = SoundGen.thud()
	return _hit
