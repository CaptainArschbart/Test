extends RefCounted
## Gegner-Sounds: Rufe, Schritte, Schüsse, Schlag-Wusch, Aufprall und EMP-Knistern.
##
## Alles liegt als WAV unter assets/audio (erzeugt mit tools/gen_sounds.py, Lizenzen in
## assets/audio/CREDITS.md). Die Rufe sind deutsche Sprachaufnahmen (TTS) passend zum Text
## über dem Kopf (Enemy.BARKS, gleiche Reihenfolge), in drei Stimmlagen. Die nächste Lage zu
## EnemyProfile.voice_pitch wird genommen, der kleine Rest über die Abspielrate ausgeglichen.
## Benutzt per preload (kein class_name).

const AUDIO_DIR := "res://assets/audio/"

const STEPS: Array[AudioStream] = [
	preload("res://assets/audio/footstep_01.wav"),
	preload("res://assets/audio/footstep_02.wav"),
	preload("res://assets/audio/footstep_03.wav"),
]
## Gegner hört man aus der Welt: mono, mehr Raum, weniger Knall-Höhen als beim Spieler.
const PISTOL_SHOT: AudioStream = preload("res://assets/audio/pistol_shot_world.wav")
const RIFLE_SHOT: AudioStream = preload("res://assets/audio/sniper_shot_world.wav")
const RELOAD: AudioStream = preload("res://assets/audio/pistol_reload.wav")
const SWING: AudioStream = preload("res://assets/audio/melee_swing.wav")
const THUD: AudioStream = preload("res://assets/audio/melee_thud.wav")
const ZAP: AudioStream = preload("res://assets/audio/emp_zap.wav")

## Ruf-Schlüssel mit Aufnahmen. Unbekannte Schlüssel fallen auf „hurt“ zurück.
const LINES: Array[StringName] = [&"suspicious", &"investigate", &"alert", &"search", &"lost",
		&"body", &"cover", &"hurt", &"death"]
const VARIANTS := 3
## Stimmlagen der Aufnahmen als Tonhöhen-Faktor (−4, −1,5 und +0,5 Halbtöne).
const VOICE_LAYERS := {&"low": 0.7937, &"mid": 0.9170, &"high": 1.0293}

static var _cache := {}


static func step() -> AudioStream:
	return STEPS[randi() % STEPS.size()]


## Ruf `line` (Schlüssel aus LINES) in der Stimmlage `pitch`. variant wählt die Aufnahme und
## passt zum Text BARKS[line][variant % 3].
static func voice(line: StringName, pitch: float, variant: int = 0) -> AudioStream:
	if not LINES.has(line):
		line = &"hurt"
	var index := variant % VARIANTS
	var key := "%s_%d_%.2f" % [line, index, pitch]
	if _cache.has(key):
		return _cache[key]
	var layer: StringName = &"mid"
	var best := INF
	for tag: StringName in VOICE_LAYERS:
		var d := absf(log(maxf(pitch, 0.1) / float(VOICE_LAYERS[tag])))
		if d < best:
			best = d
			layer = tag
	var source := load("%svoices/%s_%d_%s.wav" % [AUDIO_DIR, line, index, layer]) as AudioStreamWAV
	if source == null:
		return null
	var stream := source
	var rest := maxf(pitch, 0.1) / float(VOICE_LAYERS[layer])
	if absf(rest - 1.0) > 0.005:
		# Kopie mit angepasster Abspielrate, die geladene Datei bleibt unverändert.
		stream = source.duplicate() as AudioStreamWAV
		stream.mix_rate = roundi(source.mix_rate * rest)
	_cache[key] = stream
	return stream


## Kurzes Wuschen eines Schlags.
static func swing() -> AudioStream:
	return SWING


## Dumpfer Aufprall (Schlag trifft, Körper fällt).
static func thud() -> AudioStream:
	return THUD


## Funkenknistern beim Betäuben (EMP).
static func zap() -> AudioStream:
	return ZAP
