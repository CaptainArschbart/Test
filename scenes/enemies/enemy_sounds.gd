extends RefCounted
## Prozedurale Gegner-Sounds: Rufe (Funk-Stimme aus Formanten), Grunzer, Todesschrei,
## Schlag-Wusch und Aufprall. Schritte und Schüsse nehmen die vorhandenen WAVs aus assets/audio.
##
## Es gibt keine Sprachaufnahmen im Projekt. Die Stimmen sind deshalb kurze, verzerrte
## Silbenfolgen (wie ein übersteuertes Funkgerät), die Tonfall und Länge eines Rufs tragen.
## Was gesagt wird, steht zusätzlich als Text über dem Kopf (Enemy.BARKS).
## Alles wird beim ersten Aufruf erzeugt und gecacht. Benutzt per preload (kein class_name).

const MIX_RATE := 22050

const STEPS: Array[AudioStream] = [
	preload("res://assets/audio/footstep_01.wav"),
	preload("res://assets/audio/footstep_02.wav"),
	preload("res://assets/audio/footstep_03.wav"),
]
const PISTOL_SHOT: AudioStream = preload("res://assets/audio/pistol_shot.wav")
const RIFLE_SHOT: AudioStream = preload("res://assets/audio/sniper_shot.wav")
const RELOAD: AudioStream = preload("res://assets/audio/pistol_reload.wav")

## Vokal-Formanten (F1, F2, F3) in Hz.
const VOWELS := {
	&"a": Vector3(780, 1250, 2500),
	&"e": Vector3(520, 1850, 2550),
	&"i": Vector3(330, 2200, 2900),
	&"o": Vector3(520, 900, 2450),
	&"u": Vector3(360, 800, 2300),
	&"m": Vector3(280, 1100, 2300),
}

## Silben je Ruf: [Länge s, Tonhöhe Anfang, Tonhöhe Ende (Faktor auf 120 Hz), Vokal, Lautstärke, Hauch vorne].
const LINES := {
	# „Hm?“ – fragend, steigt an.
	&"suspicious": [[0.32, 1.0, 1.35, &"m", 0.8, 0.0]],
	# „Wer ist da?“
	&"investigate": [[0.12, 1.1, 1.1, &"e", 0.9, 0.3], [0.1, 1.15, 1.2, &"i", 0.8, 0.5], [0.24, 1.2, 1.5, &"a", 1.0, 0.2]],
	# „Hey! Da ist er!“ – laut, kurz, fallend.
	&"alert": [[0.16, 1.7, 1.9, &"e", 1.0, 0.8], [0.08, 0.0, 0.0, &"a", 0.0, 0.0], [0.1, 1.6, 1.6, &"a", 1.0, 0.4],
			[0.08, 1.5, 1.5, &"i", 0.9, 0.5], [0.22, 1.7, 1.25, &"e", 1.0, 0.2]],
	# „Ich such ihn …“ – murmelnd.
	&"search": [[0.1, 1.0, 1.0, &"i", 0.7, 0.4], [0.16, 1.05, 0.95, &"u", 0.7, 0.5], [0.28, 0.95, 0.85, &"e", 0.6, 0.1]],
	# „Weg …“ – enttäuscht, fallend.
	&"lost": [[0.14, 1.1, 1.0, &"e", 0.8, 0.6], [0.34, 1.0, 0.75, &"o", 0.7, 0.0]],
	# „Mann am Boden!“
	&"body": [[0.12, 1.5, 1.5, &"a", 1.0, 0.1], [0.1, 1.45, 1.45, &"a", 0.9, 0.0], [0.12, 1.5, 1.6, &"o", 1.0, 0.3],
			[0.26, 1.6, 1.2, &"e", 1.0, 0.1]],
	&"hurt": [[0.18, 1.45, 0.95, &"a", 1.0, 0.6]],
	&"death": [[0.65, 1.3, 0.55, &"o", 1.0, 0.5]],
	# Nachladen: „Deckung!“
	&"cover": [[0.1, 1.4, 1.4, &"e", 0.9, 0.5], [0.24, 1.45, 1.2, &"u", 1.0, 0.4]],
}

const FORMANT_GAINS := [1.0, 0.7, 0.35]

static var _cache := {}


static func step() -> AudioStream:
	return STEPS[randi() % STEPS.size()]


## Ruf `line` (Schlüssel aus LINES) in der Stimmlage `pitch`. variant macht kleine Unterschiede.
static func voice(line: StringName, pitch: float, variant: int = 0) -> AudioStreamWAV:
	var key := "%s_%.2f_%d" % [line, pitch, variant % 3]
	if _cache.has(key):
		return _cache[key]
	var syllables: Array = LINES.get(line, LINES[&"hurt"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var total := 0.0
	for s: Array in syllables:
		total += s[0]
	var frames := int(MIX_RATE * (total + 0.08))
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var phase := 0.0
	var filters := [_Reso.new(), _Reso.new(), _Reso.new()]
	var pos := 0
	for s: Array in syllables:
		var length: float = s[0] * rng.randf_range(0.9, 1.12)
		var count := int(MIX_RATE * length)
		var formants: Vector3 = VOWELS[s[3]] * rng.randf_range(0.95, 1.06)
		var amp: float = s[4]
		var breath: float = s[5]
		for i: int in count:
			if pos >= frames:
				break
			var k := float(i) / maxf(count, 1)
			var f0: float = 118.0 * pitch * lerpf(s[1], s[2], k) * (1.0 + 0.02 * sin(TAU * 5.5 * pos / MIX_RATE))
			var src := 0.0
			if f0 > 1.0 and amp > 0.0:
				phase = fmod(phase + f0 / MIX_RATE, 1.0)
				# Sägezahn mit weicher Kante als Stimmband-Anregung.
				src = (phase * 2.0 - 1.0) * 0.7 + rng.randf_range(-0.08, 0.08)
			# Hauch am Silbenanfang (h, sch, t).
			if breath > 0.0 and k < 0.3:
				src += rng.randf_range(-1.0, 1.0) * breath * (1.0 - k / 0.3)
			var env := minf(k / 0.12, 1.0) * minf((1.0 - k) / 0.2, 1.0) * amp
			var out := 0.0
			for f: int in 3:
				out += filters[f].process(src, formants[f], 90.0 + 40.0 * f) * FORMANT_GAINS[f]
			samples[pos] = out * env
			pos += 1
	# Funk-Charakter: hart begrenzen und Bits reduzieren.
	for i: int in frames:
		var v := tanh(samples[i] * 3.0)
		samples[i] = round(v * 24.0) / 24.0
	var stream := _to_stream(samples, 0.85)
	_cache[key] = stream
	return stream


## Kurzes Wuschen eines Schlags.
static func swing() -> AudioStreamWAV:
	if _cache.has(&"swing"):
		return _cache[&"swing"]
	var frames := int(MIX_RATE * 0.26)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var reso := _Reso.new()
	for i: int in frames:
		var k := float(i) / frames
		var freq := lerpf(500.0, 1800.0, sin(k * PI))
		samples[i] = reso.process(rng.randf_range(-1.0, 1.0), freq, 300.0) * sin(k * PI)
	var stream := _to_stream(samples, 0.6)
	_cache[&"swing"] = stream
	return stream


## Dumpfer Aufprall (Schlag trifft, Körper fällt).
static func thud() -> AudioStreamWAV:
	if _cache.has(&"thud"):
		return _cache[&"thud"]
	var frames := int(MIX_RATE * 0.3)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var low := 0.0
	for i: int in frames:
		var t := float(i) / MIX_RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.12
		var body := sin(TAU * lerpf(90.0, 45.0, minf(t / 0.15, 1.0)) * t) * exp(-t * 18.0)
		samples[i] = body + low * exp(-t * 30.0) * 0.8
	var stream := _to_stream(samples, 0.9)
	_cache[&"thud"] = stream
	return stream


## Funkenknistern beim Betäuben (EMP).
static func zap() -> AudioStreamWAV:
	if _cache.has(&"zap"):
		return _cache[&"zap"]
	var frames := int(MIX_RATE * 0.5)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i: int in frames:
		var t := float(i) / MIX_RATE
		var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.25 else 0.0
		samples[i] = (crackle + sin(TAU * 60.0 * t) * 0.4 * signf(sin(TAU * 120.0 * t))) * exp(-t * 4.0)
	var stream := _to_stream(samples, 0.55)
	_cache[&"zap"] = stream
	return stream


class _Reso:
	## Zweipoliger Resonanzfilter (Bandpass) für Formanten.
	var y1 := 0.0
	var y2 := 0.0

	func process(x: float, freq: float, bandwidth: float) -> float:
		var r := exp(-PI * bandwidth / MIX_RATE)
		var c := 2.0 * r * cos(TAU * freq / MIX_RATE)
		var y := (1.0 - r) * x + c * y1 - r * r * y2
		y2 = y1
		y1 = y
		return y


static func _to_stream(samples: PackedFloat32Array, peak: float) -> AudioStreamWAV:
	var top := 0.0001
	for v: float in samples:
		top = maxf(top, absf(v))
	var scale := peak / top
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * scale, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
