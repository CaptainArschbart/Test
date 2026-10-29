extends SceneTree
## Screenshots der Verbrauchsitems in der Testmap: Pickup, in der Hand, Phasen der Benutz-Animation.
##
## Aufruf (Projektordner, mit Fenster bzw. Xvfb):
##   SHOT_OUT=/pfad godot --path . --rendering-driver opengl3 -s res://tools/tests/shot_consumables.gd
## SHOT_ONLY = nur ein Item (id), SHOT_TIMES = Anteile der Benutz-Phase (Standard 0.2,0.55,0.8),
## SHOT_PITCH = Blickwinkel in Grad, SHOT_BRIGHT=1 = helles Umgebungslicht (zum Einstellen der Posen).

var OUT := OS.get_environment("SHOT_OUT")
const ITEMS := ["stim_pack", "energy_drink", "noodles", "nano_bandage"]

func _initialize() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("shot ", name)

func _run() -> void:
	change_scene_to_file("res://scenes/testmap/testmap.tscn")
	await _frames(20)
	var player: Node = get_first_node_in_group("player")
	var only := OS.get_environment("SHOT_ONLY")
	var times := OS.get_environment("SHOT_TIMES")
	var stamps: Array = []
	for t in (times if times != "" else "0.2,0.55,0.8").split(","):
		stamps.append(float(t))
	player.global_position = Vector3(0, 0.05, 40)
	player.rotation = Vector3.ZERO
	player.get_node("Head").rotation = Vector3(deg_to_rad(float(OS.get_environment("SHOT_PITCH") if OS.get_environment("SHOT_PITCH") != "" else "0")), 0, 0)
	if OS.get_environment("SHOT_BRIGHT") != "":
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.45, 0.5, 0.55)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(1, 1, 1)
		env.ambient_light_energy = 1.2
		player.get("camera").environment = env
	await _frames(10)
	var inv: Node = player.get("inventory")
	for id: String in ITEMS:
		if only != "" and only != id:
			continue
		var item: Resource = load("res://scenes/items/data/%s.tres" % id)
		# Pickup vor der Kamera.
		var pickup: Node3D = load("res://scenes/items/pickup.tscn").instantiate()
		pickup.set("item", item)
		pickup.set("count", 1)
		current_scene.add_child(pickup)
		var cam: Camera3D = player.get("camera")
		pickup.global_position = cam.global_position + (-cam.global_basis.z) * 0.85 + Vector3(0, -0.2, 0)
		await _frames(30)
		await _shot(id + "_pickup")
		pickup.queue_free()
		inv.call("add_item", item, 3)
		for i in 9:
			if inv.call("get_item", i) == item:
				inv.call("select", i)
		await _frames(40)
		await _shot(id + "_hand")
		var item_user: Node = player.get("item_user")
		var use: Node = item_user.call("get_consumable_use")
		item_user.call("use_selected")
		var draw_end: float = use.get("_draw_end")
		var use_end: float = use.get("_use_end")
		for f: float in stamps:
			var target := draw_end + (use_end - draw_end) * f
			while use.call("is_active") and float(use.get("_time")) < target:
				await process_frame
			await _shot("%s_use_%.2f" % [id, f])
		await _frames(240)
		print("stats hp=", player.get("stats").get("hp"))
		inv.call("remove_at", inv.get("selected"), 99)
		await _frames(10)
	quit()
