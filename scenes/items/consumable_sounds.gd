extends RefCounted
## Prozedurale Sounds für die Benutz-Animationen der Verbrauchsitems (ConsumableUse).
##
## Es gibt keine passenden Aufnahmen im Projekt, deshalb wird alles aus Rauschen und
## Sinustönen gebaut (wie EnemySounds): Stoffrascheln, Kappe, Zischen, Dose öffnen, Schlucken,
## Folie, Schlürfen, Reißen, Wickeln und ein kurzer Heil-Ton. Jeder Sound wird beim ersten
## Aufruf erzeugt und gecacht. Benutzt per preload (kein class_name).

const MIX_RATE := 22050

static var _cache := {}


## Sound zu `name` (siehe match unten), null wenn unbekannt.
static func get_sound(name: StringName) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var samples: PackedFloat32Array
	var peak := 0.7
	match name:
		&"rustle":
			samples = _rustle(0.26, 1800.0, 7)
			peak = 0.45
		&"stow":
			samples = _rustle(0.18, 1400.0, 3)
			peak = 0.4
		&"cap":
			samples = _cap()
			peak = 0.6
		&"hiss":
			samples = _hiss(0.55)
			peak = 0.55
		&"click":
			samples = _click(0.035, 2600.0)
			peak = 0.5
		&"can_open":
			samples = _can_open()
			peak = 0.75
		&"gulp":
			samples = _gulp()
			peak = 0.6
		&"foil":
			samples = _foil()
			peak = 0.5
		&"slurp":
			samples = _slurp()
			peak = 0.5
		&"tear":
			samples = _tear()
			peak = 0.6
		&"wrap":
			samples = _rustle(0.55, 1100.0, 10)
			peak = 0.4
		&"heal":
			samples = _heal()
			peak = 0.35
		&"cancel":
			samples = _cancel()
			peak = 0.35
		_:
			return null
	var stream := _to_stream(samples, peak)
	_cache[name] = stream
	return stream


static func _frames(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(MIX_RATE * seconds))
	return samples


## Weiches Stoffrascheln: Tiefpass-Rauschen in `bursts` kleinen Stößen.
static func _rustle(seconds: float, cutoff: float, bursts: int) -> PackedFloat32Array:
	var samples := _frames(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cutoff) + bursts
	var low := 0.0
	var a := _alpha(cutoff)
	var n := samples.size()
	for i in n:
		var t := float(i) / n
		low += a * (rng.randf_range(-1.0, 1.0) - low)
		var wobble := 0.5 + 0.5 * absf(sin(t * PI * bursts + sin(t * 23.0)))
		samples[i] = low * wobble * sin(t * PI)
	return samples


## Schutzkappe ab: dumpfer Plopp mit kurzem Klick.
static func _cap() -> PackedFloat32Array:
	var samples := _frames(0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(520.0, 180.0, minf(t / 0.05, 1.0)) / MIX_RATE
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 400.0)
		samples[i] = sin(phase) * exp(-t * 45.0) * 0.8 + click * 0.6
	return samples


## Druckluft beim Injizieren: Hochpass-Rauschen, schnell an, langsam aus.
static func _hiss(seconds: float) -> PackedFloat32Array:
	var samples := _frames(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var low := 0.0
	var a := _alpha(3500.0)
	var n := samples.size()
	for i in n:
		var t := float(i) / n
		var white := rng.randf_range(-1.0, 1.0)
		low += a * (white - low)
		var env := minf(t / 0.04, 1.0) * pow(1.0 - t, 1.5)
		samples[i] = (white - low) * env
	return samples


static func _click(seconds: float, freq: float) -> PackedFloat32Array:
	var samples := _frames(seconds)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		samples[i] = sin(TAU * freq * t) * exp(-t * 160.0) + sin(TAU * freq * 1.7 * t) * exp(-t * 260.0) * 0.5
	return samples


## Dose öffnen: scharfes Knacken, dann Sprudeln mit kleinen Bläschen.
static func _can_open() -> PackedFloat32Array:
	var samples := _frames(0.75)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var low := 0.0
	var a := _alpha(4200.0)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += a * (white - low)
		var crack := white * exp(-t * 220.0) * 1.4 + sin(TAU * 3100.0 * t) * exp(-t * 300.0) * 0.6
		var fizz := (white - low) * exp(-t * 4.5) * 0.55 * minf(t / 0.02, 1.0)
		var bubble := 0.0
		if rng.randf() < 0.0025:
			bubble = rng.randf_range(0.4, 0.9)
		samples[i] = crack + fizz + bubble * exp(-t * 3.0)
	return samples


## Schluck: tiefer Ton, der nach unten rutscht, mit etwas Rauschen.
static func _gulp() -> PackedFloat32Array:
	var samples := _frames(0.22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var phase := 0.0
	var low := 0.0
	var a := _alpha(600.0)
	var n := samples.size()
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(210.0, 95.0, t) / MIX_RATE
		low += a * (rng.randf_range(-1.0, 1.0) - low)
		samples[i] = (sin(phase) * 0.8 + low * 0.6) * sin(t * PI)
	return samples


## Folie abziehen: Knistern mit kurzen Spitzen.
static func _foil() -> PackedFloat32Array:
	var samples := _frames(0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var low := 0.0
	var a := _alpha(5000.0)
	var n := samples.size()
	for i in n:
		var t := float(i) / n
		var white := rng.randf_range(-1.0, 1.0)
		low += a * (white - low)
		var crackle := 1.0 if rng.randf() < 0.02 else 0.25
		samples[i] = (white - low) * crackle * sin(t * PI)
	return samples


## Schlürfen: Bandpass-Rauschen, das in der Tonhöhe steigt.
static func _slurp() -> PackedFloat32Array:
	var samples := _frames(0.42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var low1 := 0.0
	var low2 := 0.0
	var n := samples.size()
	for i in n:
		var t := float(i) / n
		var white := rng.randf_range(-1.0, 1.0)
		low1 += _alpha(lerpf(900.0, 2600.0, t)) * (white - low1)
		low2 += _alpha(lerpf(300.0, 900.0, t)) * (white - low2)
		samples[i] = (low1 - low2) * sin(t * PI) * (0.7 + 0.3 * sin(t * 60.0))
	return samples


## Verband aufreißen: raues Rauschen mit schneller Amplitudenmodulation.
static func _tear() -> PackedFloat32Array:
	var samples := _frames(0.38)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var low := 0.0
	var a := _alpha(2600.0)
	var n := samples.size()
	for i in n:
		var t := float(i) / n
		low += a * (rng.randf_range(-1.0, 1.0) - low)
		var grit := 0.4 + 0.6 * absf(sin(t * 140.0 + sin(t * 37.0) * 3.0))
		samples[i] = low * grit * minf(t / 0.03, 1.0) * (1.0 - t)
	return samples


## Heil-Ton: zwei helle Sinustöne mit Schimmer, leise.
static func _heal() -> PackedFloat32Array:
	var samples := _frames(0.7)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var first := sin(TAU * 660.0 * t) * exp(-t * 7.0)
		var second := sin(TAU * 990.0 * t) * exp(-maxf(t - 0.08, 0.0) * 6.0) * (1.0 if t > 0.08 else 0.0)
		var shimmer := sin(TAU * 1980.0 * t + sin(TAU * 6.0 * t) * 2.0) * exp(-t * 5.0) * 0.25
		samples[i] = first * 0.6 + second * 0.7 + shimmer
	return samples


## Abbruch: kurzer, fallender Ton.
static func _cancel() -> PackedFloat32Array:
	var samples := _frames(0.18)
	var phase := 0.0
	var n := samples.size()
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(420.0, 220.0, t) / MIX_RATE
		samples[i] = (1.0 if sin(phase) > 0.0 else -1.0) * 0.4 * (1.0 - t)
	return samples


## Glättungsfaktor eines einfachen Tiefpasses für `cutoff` Hz.
static func _alpha(cutoff: float) -> float:
	var rc := 1.0 / (TAU * cutoff)
	var dt := 1.0 / MIX_RATE
	return dt / (rc + dt)


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
