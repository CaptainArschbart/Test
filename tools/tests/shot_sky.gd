extends SceneTree
## Screenshots von Sektor 7 zu verschiedenen Tageszeiten und Wettern (mit Fenster, nicht headless).
##
## Aufruf (Projektordner):
##   godot --path . -s res://tools/tests/shot_sky.gd -- <zielordner>
## Speichert sky_<zeit>_<wetter>.png in den Zielordner (Standard: user://).

const SLUM := "res://scenes/slum/slum.tscn"
const TIMES := [0.0, 0.22, 0.27, 0.4, 0.5, 0.73, 0.78, 0.9]


func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://"
	change_scene_to_file(SLUM)
	await _wait(60)
	var atmo := current_scene.get_node("WorldAtmosphere")
	atmo.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	cam.far = 500.0
	current_scene.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 2.0, 30)
	cam.rotation_degrees = Vector3(18, 30, 0)
	for weather in [0, 2]:
		atmo.set("weather", weather)
		atmo.call("_sync_rain")
		atmo.call("_snap_weather")
		for t: float in TIMES:
			atmo.set("time_of_day", t)
			atmo.call("_drive_sun")
			await _wait(20)
			var img := root.get_texture().get_image()
			img.resize(img.get_width() / 3, img.get_height() / 3)
			img.save_png(out_dir.path_join("sky_%02d_w%d.png" % [int(t * 100), weather]))
	quit(0)
