extends SceneTree
## Screenshots der Waffen in der Testmap: aus der Hüfte, im Anschlag, beim Nachladen und als Pickup.
##
## Aufruf (Projektordner, mit Fenster bzw. Xvfb):
##   SHOT_OUT=/pfad godot --path . -s res://tools/tests/shot_weapons.gd
## SHOT_ONLY = nur eine Waffe (id). Pro Waffe entsteht <id>.png mit den vier Bildern nebeneinander.

var OUT := OS.get_environment("SHOT_OUT")
const WEAPONS := ["pistol", "smg", "ak47", "m4", "sniper", "revolver", "heavy_pistol", "pump_shotgun",
	"sawed_off", "bullpup", "compact_smg", "dmr"]


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	return img


func _run() -> void:
	change_scene_to_file("res://scenes/testmap/testmap.tscn")
	await _frames(20)
	var player: Node = get_first_node_in_group("player")
	player.global_position = Vector3(0, 0.05, 40)
	player.rotation = Vector3.ZERO
	await _frames(10)
	var inv: Node = player.get("inventory")
	var only := OS.get_environment("SHOT_ONLY")
	for id: String in WEAPONS:
		if only != "" and only != id:
			continue
		var item: Resource = load("res://scenes/items/data/%s.tres" % id)
		var shots: Array[Image] = []
		inv.call("add_item", item, 1)
		for i in 9:
			if inv.call("get_item", i) == item:
				inv.call("select", i)
		await _frames(50)
		shots.append(await _grab())
		Input.action_press("aim")
		await _frames(40)
		shots.append(await _grab())
		Input.action_release("aim")
		await _frames(30)
		Input.action_press("reload")
		await _frames(2)
		Input.action_release("reload")
		await _frames(int(item.get("reload_time") * 30.0))
		shots.append(await _grab())
		await _frames(90)
		inv.call("remove_at", inv.get("selected"), 99)
		var pickup: Node3D = load("res://scenes/items/pickup.tscn").instantiate()
		pickup.set("item", item)
		pickup.set("count", 1)
		current_scene.add_child(pickup)
		var cam: Camera3D = player.get("camera")
		pickup.global_position = cam.global_position + (-cam.global_basis.z) * 1.2 + Vector3(0, -0.25, 0)
		await _frames(30)
		shots.append(await _grab())
		pickup.queue_free()
		var w := shots[0].get_width()
		var h := shots[0].get_height()
		var sheet := Image.create(w * 2, h * 2, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
		sheet.save_png(OUT.path_join(id + ".png"))
		print("shot ", id)
		await _frames(10)
	quit()
