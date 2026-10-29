extends SceneTree
## Ein abgebrochenes Beitreten darf einen danach gestarteten Host nicht schließen.
##
## Aufruf: godot --headless --path . -s res://tools/tests/test_lobby_join.gd
## Letzte Zeile: "CHECKS n FAILS m".

const MENU := "res://scenes/menu/main_menu.tscn"

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
	change_scene_to_file(MENU)
	for _i in 20:
		await process_frame
	var menu := current_scene
	_check(menu != null and menu.get("_host_port") != null, "Hauptmenü mit Lobby-Port")
	if menu == null or menu.get("_host_port") == null:
		_finish()
		return
	var port_field: LineEdit = menu.get("_host_port")
	port_field.text = "7798"
	menu.call("_begin_join_wait")
	_check(bool(menu.get("_join_pending")), "Join-Wartezeit läuft")
	menu.call("_on_host_port_pressed")
	await process_frame
	var net := get_root().get_node("NetworkManager")
	var session := bool(net.call("has_session"))
	var server := session and bool(menu.multiplayer.is_server())
	_check(not bool(menu.get("_join_pending")) and server, "Host beendet die offene Join-Wartezeit und lauscht")
	menu.call("_on_join_timeout")
	await process_frame
	session = bool(net.call("has_session"))
	server = session and bool(menu.multiplayer.is_server())
	_check(server, "Alter Join-Timeout reißt den Host nicht ab")
	net.call("stop")
	_finish()


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
