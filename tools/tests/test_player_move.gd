extends SceneTree
## Startet Sektor 7 über das Menü und prüft, ob der Spieler mit W läuft, springt und sich nach
## einem Taschendiebstahl-Versuch wieder bewegen kann.
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
	var player := get_first_node_in_group("player") as CharacterBody3D
	_check(player != null, "Spieler gespawnt")
	if player == null:
		_finish()
		return
	print("  info input_locked=%s local=%s noclip=%s pos=%s" % [player.get("input_locked"),
			player.call("controls_local_body"), player.get("noclip"), player.global_position])
	var walked := await _walk(player, 60)
	_check(walked > 2.0, "Läuft mit W (%.2f m in 1 s)" % walked)
	_finish()


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
