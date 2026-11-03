extends SceneTree
## Screenshot des offenen Inventars mit allen Items aus scenes/items/data/ (Icons prüfen).
##
## Aufruf (Projektordner, mit Fenster bzw. Xvfb):
##   SHOT_OUT=/pfad godot --path . -s res://tools/tests/shot_inventory.gd
## Schreibt inventory.png.

var OUT := OS.get_environment("SHOT_OUT")
const DATA_DIR := "res://scenes/items/data"


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://scenes/testmap/testmap.tscn")
	await _frames(30)
	var player: Node = get_first_node_in_group("player")
	var inv: Node = player.get("inventory")
	for f in DirAccess.get_files_at(DATA_DIR):
		if f.get_extension() != "tres":
			continue
		var item := load(DATA_DIR.path_join(f)) as ItemData
		if item != null and not item.is_currency:
			inv.call("add_item", item, mini(3, item.max_stack))
	await _frames(10)
	var press := InputEventAction.new()
	press.action = "inventory"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(20)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT.path_join("inventory.png"))
	print("shot inventory")
	quit()
