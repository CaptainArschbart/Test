extends SceneTree
## Startet Sektor 7 über das Menü und prüft, ob die Stadtinhalte gebaut sind und der Spieler mit W läuft.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_player_move.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const SLUM := "res://scenes/slum/slum.tscn"

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _walk(player: Node3D, frames: int) -> float:
	var start := player.global_position
	Input.action_press("move_forward")
	await _wait(frames)
	Input.action_release("move_forward")
	var d := player.global_position - start
	d.y = 0.0
	return d.length()


func _run() -> void:
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await _wait(10)
	current_scene.call("_start_game", SLUM)
	for i in 300:
		if current_scene != null and current_scene.scene_file_path == SLUM:
			break
		await physics_frame
	await _wait(60)
	# Kompiliert ein Skript mit neuem class_name nicht (Klassen-Cache), fehlen Läden und Wohnungen.
	var content := current_scene.get_node_or_null("CityContent")
	_check(content != null and content.get_child_count() > 0, "Läden und Tankstellen gebaut (CityContent)")
	var player := get_first_node_in_group("player") as CharacterBody3D
	_check(player != null, "Spieler gespawnt")
	if player == null:
		_finish()
		return
	print("  info input_locked=%s local=%s noclip=%s pos=%s" % [player.get("input_locked"),
			player.call("controls_local_body"), player.get("noclip"), player.global_position])
	var walked := await _walk(player, 60)
	_check(walked > 2.0, "Läuft mit W (%.2f m in 1 s)" % walked)
	# Option „Physik 30 Hz“: gleiches Tempo, Kamera folgt dem Kopf, Interpolation an.
	var settings := root.get_node("Settings")
	settings.set("physics_rate", 30)
	settings.call("apply")
	_check(Engine.physics_ticks_per_second == 30 and physics_interpolation, "Physik 30 Hz mit Interpolation")
	var start_ms := Time.get_ticks_msec()
	var start := player.global_position
	Input.action_press("move_forward")
	while Time.get_ticks_msec() - start_ms < 1000:
		await process_frame
	Input.action_release("move_forward")
	var walked30 := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	_check(walked30 > 2.0, "Läuft mit W bei 30 Hz (%.2f m in 1 s)" % walked30)
	var camera := player.get("camera") as Camera3D
	var head := player.get("head") as Node3D
	_check(camera.global_position.distance_to(head.global_position) < 0.6, "Kamera bleibt am Kopf (%.2f m)"
			% camera.global_position.distance_to(head.global_position))
	settings.set("physics_rate", 60)
	settings.call("apply")
	_check(Engine.physics_ticks_per_second == 60 and not physics_interpolation, "zurück auf 60 Hz")
	_finish()


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
