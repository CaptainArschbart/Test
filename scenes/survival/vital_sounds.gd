extends RefCounted
## Prozedurale Sounds für Low-Health und Tod: Herzschlag, Atem, Flatline-Ton.
##
## Es gibt dafür keine Audio-Dateien im Projekt, deshalb werden die Klänge beim ersten Aufruf
## als AudioStreamWAV (16 Bit, mono) im Speicher erzeugt und gecacht. Kein Import nötig.
## Benutzt per preload (kein class_name), damit nach dem Pull kein Klassen-Cache fehlt.

const MIX_RATE := 22050

static var _cache := {}


## Ein Schlag „lub-dub“: zwei tiefe, gedämpfte Stöße, etwa 0,55 s.
static func heartbeat() -> AudioStreamWAV:
	if _cache.has(&"heart"):
		return _cache[&"heart"]
	var frames := int(MIX_RATE * 0.55)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	for i: int in frames:
		var t := float(i) / MIX_RATE
		samples[i] = _thump(t, 0.0, 1.0) + _thump(t, 0.2, 0.72)
	var stream := _to_stream(samples, 0.95)
	_cache[&"heart"] = stream
	return stream


## Schwerer Atem als Schleife (ein- und ausatmen, ca. 2,4 s): gefiltertes Rauschen mit Hüllkurve.
static func breath() -> AudioStreamWAV:
	if _cache.has(&"breath"):
		return _cache[&"breath"]
	var length := 2.4
	var frames := int(MIX_RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	var band := 0.0
	for i: int in frames:
		var t := float(i) / MIX_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		# Zwei einfache Tiefpässe: „low“ trägt das Rauschen, „band“ nimmt den dumpfen Teil wieder raus.
		low += (noise - low) * 0.18
		band += (low - band) * 0.02
		var hiss := low - band
		var env := 0.0
		if t < 0.85:
			# Einatmen: schneller rein, kurz halten.
			env = sin(t / 0.85 * PI) * 0.8
		elif t > 1.0 and t < 2.15:
			# Ausatmen: länger, etwas lauter und tiefer.
			env = pow(sin((t - 1.0) / 1.15 * PI), 1.4)
			hiss = lerpf(hiss, low, 0.35)
		samples[i] = hiss * env * 1.6
	var stream := _to_stream(samples, 0.7)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	_cache[&"breath"] = stream
	return stream


## Dauerton des EKG-Monitors (Schleife). Die Länge ist ein ganzzahliges Vielfaches der Periode,
## damit die Schleife nicht knackt.
static func flatline() -> AudioStreamWAV:
	if _cache.has(&"flatline"):
		return _cache[&"flatline"]
	var freq := 980.0
	var periods := 98
	var frames := int(round(MIX_RATE * periods / freq))
	var samples := PackedFloat32Array()
	samples.resize(frames)
	for i: int in frames:
		var phase := TAU * periods * float(i) / frames
		# Etwas Obertöne, damit es nach Monitor-Piepser statt nach Sinus-Testton klingt.
		samples[i] = sin(phase) * 0.8 + sin(phase * 2.0) * 0.12 + sin(phase * 3.0) * 0.06
	var stream := _to_stream(samples, 0.5)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	_cache[&"flatline"] = stream
	return stream


## Ein tiefer Stoß ab `start` Sekunden: abfallende Tonhöhe, schneller Abfall, kleiner Klick vorne.
static func _thump(t: float, start: float, gain: float) -> float:
	var local := t - start
	if local < 0.0:
		return 0.0
	var freq := lerpf(62.0, 38.0, clampf(local / 0.12, 0.0, 1.0))
	var attack := clampf(local / 0.006, 0.0, 1.0)
	var body := sin(TAU * freq * local) * exp(-local * 16.0)
	var click := sin(TAU * 140.0 * local) * exp(-local * 70.0) * 0.35
	return (body + click) * attack * gain


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
