extends RefCounted
## Sounds für Low-Health und Tod: Herzschlag, Atem, Flatline-Ton.
##
## Die Klänge liegen als WAV unter assets/audio (erzeugt mit tools/gen_sounds.py). Atem und
## Flatline sind im Import als Schleife markiert (nahtlos, Flatline = genau 98 Perioden).
## Benutzt per preload (kein class_name), damit nach dem Pull kein Klassen-Cache fehlt.

const HEARTBEAT: AudioStream = preload("res://assets/audio/heartbeat.wav")
const BREATH: AudioStreamWAV = preload("res://assets/audio/breath_loop.wav")
const FLATLINE: AudioStreamWAV = preload("res://assets/audio/flatline_loop.wav")


## Ein Schlag „lub-dub“, etwa 0,6 s, dumpf wie durch den eigenen Brustkorb.
static func heartbeat() -> AudioStream:
	return HEARTBEAT


## Schwerer Atem als Schleife (ein- und ausatmen, 2,4 s).
static func breath() -> AudioStreamWAV:
	return _looped(BREATH)


## Dauerton des EKG-Monitors (Schleife).
static func flatline() -> AudioStreamWAV:
	return _looped(FLATLINE)


## Sicherheitsnetz: Schleife auch dann, wenn die Datei ohne Loop-Einstellung importiert wurde.
static func _looped(stream: AudioStreamWAV) -> AudioStreamWAV:
	if stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return stream
	var copy := stream.duplicate() as AudioStreamWAV
	copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	copy.loop_begin = 0
	copy.loop_end = int(copy.get_length() * copy.mix_rate)
	return copy
