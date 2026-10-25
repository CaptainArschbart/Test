extends Node
## Spielt alle MP3s aus res://sounds nacheinander auf dem Bus "Music".
## Am Ende der Liste geht es bei der ersten Datei weiter.
## Die Lautstärke kommt vom Bus, den Settings und der Musik-Regler setzen.

const MUSIC_DIR := "res://sounds"

var player: AudioStreamPlayer
var tracks: Array[AudioStream] = []
var track_paths: Array[String] = []
var track_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "Music"
	player.bus = Settings.MUSIC_BUS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(_on_track_finished)
	_load_tracks()
	play_current()


func _exit_tree() -> void:
	if player != null and is_instance_valid(player):
		player.stop()
		player.stream = null
	tracks.clear()


func play_current() -> void:
	if tracks.is_empty() or player == null:
		return
	if player.playing:
		player.stop()
	player.stream = tracks[track_index]
	player.play()


func _load_tracks() -> void:
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		push_error("AudioManager: Ordner %s fehlt." % MUSIC_DIR)
		return
	var names := dir.get_files()
	names.sort()
	for file_name: String in names:
		if not file_name.to_lower().ends_with(".mp3"):
			continue
		var path := MUSIC_DIR.path_join(file_name)
		var stream := load(path) as AudioStream
		if stream == null:
			push_error("AudioManager: %s ließ sich nicht laden." % path)
			continue
		tracks.append(stream)
		track_paths.append(path)
	if tracks.is_empty():
		push_error("AudioManager: keine MP3 in %s." % MUSIC_DIR)


func _on_track_finished() -> void:
	if tracks.is_empty():
		return
	track_index = (track_index + 1) % tracks.size()
	play_current()
