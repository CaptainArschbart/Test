extends RefCounted
## Prozedurale Sounds für den Faustkampf des Spielers: Luftzug, Treffer, Wand, Aufladen, Dash und
## Powerschlag. Alles wird beim ersten Aufruf erzeugt und gecacht. Benutzt per preload (kein class_name).

const MIX_RATE := 22050

static var _cache := {}


## Kurzer Luftzug einer Faust (hell, schnell).
static func whoosh() -> AudioStreamWAV:
	return _cached(&"whoosh", func() -> Array:
		var rng := _rng(3)
		var frames := int(MIX_RATE * 0.16)
		var out := _buffer(frames)
		var low := 0.0
		for i: int in frames:
			var k := float(i) / frames
			low += (rng.randf_range(-1.0, 1.0) - low) * lerpf(0.15, 0.55, sin(k * PI))
			out[i] = low * sin(k * PI) * (1.0 - k * 0.5)
		return [out, 0.45])


## Faust trifft Körper: Knacken plus dumpfer Schlag.
static func punch_hit() -> AudioStreamWAV:
	return _cached(&"punch_hit", func() -> Array:
		var rng := _rng(7)
		var frames := int(MIX_RATE * 0.22)
		var out := _buffer(frames)
		var low := 0.0
		for i: int in frames:
			var t := float(i) / MIX_RATE
			low += (rng.randf_range(-1.0, 1.0) - low) * 0.2
			var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 90.0)
			var body := sin(TAU * lerpf(140.0, 60.0, minf(t / 0.08, 1.0)) * t) * exp(-t * 24.0)
			out[i] = crack * 0.7 + body + low * exp(-t * 35.0) * 0.6
		return [out, 0.9])


## Faust trifft Wand oder Kiste: kurz und hart.
static func wall_hit() -> AudioStreamWAV:
	return _cached(&"wall_hit", func() -> Array:
		var rng := _rng(9)
		var frames := int(MIX_RATE * 0.12)
		var out := _buffer(frames)
		for i: int in frames:
			var t := float(i) / MIX_RATE
			out[i] = rng.randf_range(-1.0, 1.0) * exp(-t * 70.0) + sin(TAU * 220.0 * t) * exp(-t * 45.0) * 0.6
		return [out, 0.6])


## Aufladen: steigender Synth-Ton mit Knistern (Länge = volle Ladezeit 0,8 s, danach Haltebrummen).
static func charge() -> AudioStreamWAV:
	return _cached(&"charge", func() -> Array:
		var rng := _rng(13)
		var frames := int(MIX_RATE * 1.4)
		var out := _buffer(frames)
		var phase := 0.0
		for i: int in frames:
			var t := float(i) / MIX_RATE
			var rise := minf(t / 0.8, 1.0)
			var freq := lerpf(70.0, 260.0, rise * rise) + sin(t * 38.0) * 6.0 * rise
			phase += TAU * freq / MIX_RATE
			var tone := sin(phase) * 0.6 + signf(sin(phase * 2.0)) * 0.18 + sin(phase * 3.01) * 0.15
			var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.04 + rise * 0.12 else 0.0
			var env := minf(t / 0.05, 1.0) * lerpf(0.35, 1.0, rise)
			out[i] = (tone + crackle * 0.5) * env
		return [out, 0.5])


## Dash: tiefes Rauschen, das vorbeizieht.
static func dash() -> AudioStreamWAV:
	return _cached(&"dash", func() -> Array:
		var rng := _rng(17)
		var frames := int(MIX_RATE * 0.38)
		var out := _buffer(frames)
		var low := 0.0
		for i: int in frames:
			var k := float(i) / frames
			low += (rng.randf_range(-1.0, 1.0) - low) * lerpf(0.05, 0.25, sin(k * PI))
			out[i] = low * sin(k * PI) * (1.0 - k * 0.3)
		return [out, 0.65])


## Powerschlag: Bass-Wumms, Knall und elektrisches Zischen.
static func power_hit() -> AudioStreamWAV:
	return _cached(&"power_hit", func() -> Array:
		var rng := _rng(21)
		var frames := int(MIX_RATE * 0.7)
		var out := _buffer(frames)
		var low := 0.0
		for i: int in frames:
			var t := float(i) / MIX_RATE
			low += (rng.randf_range(-1.0, 1.0) - low) * 0.1
			var boom := sin(TAU * lerpf(110.0, 38.0, minf(t / 0.25, 1.0)) * t) * exp(-t * 7.0)
			var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 60.0)
			var zap := (rng.randf_range(-1.0, 1.0) if rng.randf() < 0.2 else 0.0) * exp(-t * 6.0) * 0.5
			out[i] = boom + crack * 0.8 + zap + low * exp(-t * 12.0) * 0.5
		return [out, 0.95])


static func _cached(key: StringName, build: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		var built: Array = build.call()
		_cache[key] = _to_stream(built[0], built[1])
	return _cache[key]


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _buffer(frames: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(frames)
	return out


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
