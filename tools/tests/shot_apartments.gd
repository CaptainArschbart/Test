extends SceneTree
## Screenshots aus dem Treppenhaus und den Wohnungen eines Wohnhauses in Sektor 7 (mit Fenster, nicht headless).
##
## Aufruf (Projektordner):
##   godot --path . -s res://tools/tests/shot_apartments.gd -- <zielordner>
## Speichert apt_<n>.png in den Zielordner (Standard: user://).

const SLUM := "res://scenes/slum/slum.tscn"


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
	var enemies := current_scene.get_node_or_null(^"SlumEnemies")
	if enemies != null:
		enemies.queue_free()
	var houses := current_scene.find_children("ApartmentHouse", "", true, false)
	var house := houses[0] as Node3D
	for h in houses:
		if str(h.get_parent().name) == "Res2":
			house = h
	var cam := Camera3D.new()
	cam.fov = 80.0
	cam.far = 300.0
	current_scene.add_child(cam)
	cam.current = true
	var p := get_first_node_in_group("player") as Node3D
	if p != null:
		p.global_position = house.global_position + Vector3(0, 80, 0)
		p.set_physics_process(false)
	for node in house.get_children():
		if node.has_method("_reveal"):
			node.call("_reveal")
	var unit := house.get_node("Unit_apt_1") as Node3D
	var unit_r := house.get_node("Unit_apt_2") as Node3D
	var unit3 := house.get_node("Unit_apt_3") as Node3D
	var w := float(unit.get("unit_width"))
	var d := float(unit.get("unit_depth"))
	print("Wohnung %.2f x %.2f" % [w, d])
	# [Knoten, lokale Position, lokales Ziel]
	var views := [
		[unit, Vector3(-w * 0.2, 1.6, d * 0.35), Vector3(-w * 0.35, 1.0, -d * 0.3)],
		[unit, Vector3(w * 0.3, 1.6, d * 0.4), Vector3(-w * 0.2, 1.0, -d * 0.3)],
		[unit, Vector3(-w * 0.1, 1.6, d * 0.4), Vector3(w * 0.3, 1.0, -d * 0.4)],
		[unit, Vector3(-w * 0.45, 1.6, d * 0.3), Vector3(w * 0.3, 1.0, -d * 0.2)],
		[unit, Vector3(0, 8.0, 0.1), Vector3(0, 0, 0)],
		[unit_r, Vector3(-w * 0.3, 1.6, d * 0.4), Vector3(-w * 0.1, 1.0, -d * 0.4)],
		[unit3, Vector3(-w * 0.3, 1.6, d * 0.4), Vector3(-w * 0.1, 1.0, -d * 0.4)],
		[house, Vector3(0, 1.7, 4.2), Vector3(0, 1.8, -4)],
		[house, Vector3(0, 1.7, -3), Vector3(0, 1.5, 4)],
		[house, Vector3(0, 40.0, 0.1), Vector3(0, 0, 0)],
	]
	var i := 0
	for v: Array in views:
		var node := v[0] as Node3D
		cam.global_position = node.to_global(v[1])
		var up := Vector3.UP if v[1].y < 20.0 else Vector3.FORWARD
		cam.look_at(node.to_global(v[2]), up)
		await _wait(8)
		var img := root.get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2)
		img.save_png(out_dir.path_join("apt_%d.png" % i))
		i += 1
	quit(0)
