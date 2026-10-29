extends SceneTree
## Prüft, ob alle Sounds über die bestehenden Schnittstellen laden: EnemySounds (Rufe in allen
## Stimmlagen der Profile, Schüsse, Schritte, Schlag, Aufprall, EMP), VitalSounds (Herz, Atem
## und Flatline als Schleife) und die Waffen-Resources.
##
## Aufruf (Projektordner, vorher einmal importieren):
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/tests/test_audio.gd
## Letzte Zeile "CHECKS n FAILS m", Exitcode 0 = grün.
## Pegel, Clipping und Schleifen-Naht prüft tools/tests/check_audio_levels.py (ohne Godot).

const EnemySounds := preload("res://scenes/enemies/enemy_sounds.gd")
const VitalSounds := preload("res://scenes/survival/vital_sounds.gd")
const WEAPONS := ["res://scenes/items/data/pistol.tres", "res://scenes/items/data/sniper.tres"]
const PROFILE_DIR := "res://scenes/enemies/profiles/"

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _run() -> void:
	var pitches: Array[float] = [1.0]
	for file_name: String in DirAccess.get_files_at(PROFILE_DIR):
		if file_name.ends_with(".tres"):
			var profile := load(PROFILE_DIR + file_name)
			if profile != null and "voice_pitch" in profile:
				pitches.append(float(profile.voice_pitch))
	_check(pitches.size() > 1, "Gegnerprofile mit voice_pitch gefunden (%d)" % (pitches.size() - 1))
	var voices_ok := true
	for line: StringName in EnemySounds.LINES:
		for pitch: float in pitches:
			for variant in EnemySounds.VARIANTS:
				var s: AudioStream = EnemySounds.voice(line, pitch, variant)
				if s == null or s.get_length() < 0.1 or s.get_length() > 3.0:
					voices_ok = false
					print("    fehlt/kaputt: %s %d %.2f" % [line, variant, pitch])
	_check(voices_ok, "alle Rufe in allen Stimmlagen laden (0,1–3 s)")
	var deep: AudioStream = EnemySounds.voice(&"alert", 0.75, 0)
	var high: AudioStream = EnemySounds.voice(&"alert", 1.0, 0)
	_check(deep != high, "tiefe und normale Stimme sind verschiedene Aufnahmen")
	_check(EnemySounds.voice(&"gibt_es_nicht", 1.0, 0) != null, "unbekannter Ruf fällt auf hurt zurück")
	for s: AudioStream in [EnemySounds.PISTOL_SHOT, EnemySounds.RIFLE_SHOT, EnemySounds.RELOAD,
			EnemySounds.swing(), EnemySounds.thud(), EnemySounds.zap(), EnemySounds.step()]:
		_check(s != null and s.get_length() > 0.05, "Gegner-Sound lädt: %s" % (s.resource_path if s else "null"))
	var heart := VitalSounds.heartbeat()
	_check(heart != null and heart.get_length() > 0.3, "Herzschlag lädt")
	for s: AudioStreamWAV in [VitalSounds.breath(), VitalSounds.flatline()]:
		_check(s != null and s.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Schleife: %s" % s.resource_path)
	for path: String in WEAPONS:
		var w := load(path)
		_check(w != null and w.fire_sound != null and w.reload_sound != null and w.empty_sound != null,
				"Waffe hat alle Sounds: %s" % path)
		if w != null and w.reload_sound != null:
			_check(w.reload_sound.get_length() <= w.reload_time + 0.05,
					"Nachladesound passt in reload_time: %s" % path)
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
