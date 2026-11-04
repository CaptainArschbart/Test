extends SceneTree
## Screenshots der Ragdolls in der Testmap: Gegner und Fußgänger werden getroffen, Bilder kurz nach
## dem Treffer, im Fallen und liegend, aus Augenhöhe und von schräg oben.
##
## Aufruf (Projektordner, mit Fenster bzw. Xvfb):
##   SHOT_OUT=/pfad godot --path . -s res://tools/tests/shot_ragdoll.gd
## Schreibt ragdoll_gegner.png, ragdoll_wand.png und ragdoll_fussgaenger.png (je 4 Bilder).

var OUT := OS.get_environment("SHOT_OUT")
const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"
const PROFILES := ["gang_shotgun", "security_bullpup", "gang_leader"]
const ARENA := Vector3(-400.0, 300.0, 400.0)


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


func _box(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)
	current_scene.add_child(body)
	body.global_position = center


func _sheet(name: String, shots: Array[Image]) -> void:
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var sheet := Image.create(w * 2, h * 2, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	sheet.save_png(OUT.path_join(name + ".png"))
	print("shot ", name)


func _look(cam: Camera3D, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


func _run() -> void:
	change_scene_to_file("res://scenes/testmap/testmap.tscn")
	await _frames(30)
	var player: Node3D = get_first_node_in_group("player")
	player.global_position = ARENA + Vector3(0, 0.1, 10)
	player.set("input_locked", true)
	_box(ARENA + Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color(0.25, 0.25, 0.3))
	await _frames(10)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.current = true
	cam.fov = 60.0
	var sun := DirectionalLight3D.new()
	current_scene.add_child(sun)
	sun.rotation_degrees = Vector3(-50, 30, 0)

	# 1) Drei Gegner nebeneinander, Treffer von vorn.
	var foes: Array[Node3D] = []
	for i in PROFILES.size():
		var e: Node3D = load(ENEMY_SCENE).instantiate()
		e.set("profile", load("res://scenes/enemies/profiles/%s.tres" % PROFILES[i]))
		current_scene.add_child(e)
		e.global_position = ARENA + Vector3(-2.5 + i * 2.5, 0.05, 0)
		foes.append(e)
	_look(cam, ARENA + Vector3(0, 1.6, 6), ARENA + Vector3(0, 1.0, 0))
	await _frames(40)
	var shots: Array[Image] = [await _grab()]
	for e in foes:
		e.call("take_hit", 200.0, e.global_position + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
	await _frames(8)
	shots.append(await _grab())
	await _frames(150)
	shots.append(await _grab())
	_look(cam, ARENA + Vector3(3, 3.5, 4), ARENA + Vector3(0, 0, -0.5))
	await _frames(5)
	shots.append(await _grab())
	_sheet("ragdoll_gegner", shots)
	for e in foes:
		e.queue_free()
	await _frames(5)

	# 2) Gegen eine Wand gestoßen.
	_box(ARENA + Vector3(6.5, 1.5, -6), Vector3(0.3, 3, 4), Color(0.5, 0.45, 0.4))
	var w: Node3D = load(ENEMY_SCENE).instantiate()
	w.set("profile", load("res://scenes/enemies/profiles/gang_sawed_off.tres"))
	current_scene.add_child(w)
	w.global_position = ARENA + Vector3(5.6, 0.05, -6)
	_look(cam, ARENA + Vector3(2, 1.6, -2), ARENA + Vector3(6, 0.8, -6))
	await _frames(30)
	shots = [await _grab()]
	w.call("take_hit", 300.0, w.global_position + Vector3(0, 1.2, 0), Vector3(-1, 0, 0))
	var rag: Object = w.get("model").get("ragdoll")
	if rag != null:
		for b: RigidBody3D in (rag.get("bodies") as Dictionary).values():
			b.linear_velocity += Vector3(6, 0, 0)
	await _frames(10)
	shots.append(await _grab())
	await _frames(150)
	shots.append(await _grab())
	_look(cam, ARENA + Vector3(4, 3.0, -3), ARENA + Vector3(6, 0, -6))
	await _frames(5)
	shots.append(await _grab())
	_sheet("ragdoll_wand", shots)
	w.queue_free()
	await _frames(5)

	# 3) Fußgänger umgeworfen und wieder auf.
	var civ := (load("res://scenes/civilians/civilian.gd") as GDScript).new() as CharacterBody3D
	civ.set("stay_put", true)
	civ.set("net_seed", 11)
	current_scene.add_child(civ)
	civ.global_position = ARENA + Vector3(-6, 0.05, -4)
	_look(cam, ARENA + Vector3(-3, 1.6, 0), ARENA + Vector3(-6, 0.8, -4))
	await _frames(30)
	shots = [await _grab()]
	civ.call("hit_by_car", Vector3(-1, 0, 0), 6.0)
	await _frames(10)
	shots.append(await _grab())
	await _frames(120)
	shots.append(await _grab())
	civ.get("model").call("get_up")
	await _frames(30)
	shots.append(await _grab())
	_sheet("ragdoll_fussgaenger", shots)
	quit()
