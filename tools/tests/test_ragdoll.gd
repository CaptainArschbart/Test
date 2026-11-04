extends SceneTree
## Prüft die Ragdolls aus Schedule 1, Phase 5 (P5-1, P5-2, P5-4, P5-5) in der Testmap:
##   - Gerüst: 11 Körper auf Schicht „ragdoll“, 10 Gelenke, CCD an Becken und Kopf,
##   - Tod nah an der Kamera schaltet auf Physik, die Leiche kommt am Boden zur Ruhe, die Knochen
##     folgen den Körpern, Knie knicken nicht nach vorn durch,
##   - ein Schuss stößt in Schussrichtung, ein Stoß gegen die Wand geht nicht hindurch (CCD),
##   - Leichen blockieren weder Spieler noch Gegner noch Schüsse,
##   - Budget: höchstens 8 aktive, ältere frieren ein; weit weg nur Todesanimation; nach 30 s Schlaf,
##   - Fußgänger: vom Auto umgeworfen als Ragdoll, Aufstehen blendet zurück zur Animation.
##
## Aufruf (Projektordner), headless reicht:
##   godot --headless --path . -s res://tools/tests/test_ragdoll.gd
## Letzte Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const TESTMAP := "res://scenes/testmap/testmap.tscn"
const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"
const PROFILE := "res://scenes/enemies/profiles/gangster_pistol.tres"
const CIVILIAN := "res://scenes/civilians/civilian.gd"
const ARENA := Vector3(-400.0, 300.0, 400.0)
const RAGDOLL_LAYER := 1 << 3

var _checks := 0
var _fails := 0
var _player: Node3D
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await physics_frame
		left -= root.get_physics_process_delta_time()


func _run() -> void:
	change_scene_to_file(TESTMAP)
	for i in 300:
		if current_scene != null and current_scene.scene_file_path == TESTMAP:
			break
		await physics_frame
	await _frames(20)
	_player = get_first_node_in_group("player") as Node3D
	if _player == null:
		_check(false, "Spieler in der Testmap")
		_finish()
		return
	_camera = _player.get("camera")
	_box(ARENA + Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	_player.global_position = ARENA + Vector3(0, 0.1, 8)
	await _frames(10)
	await _test_death()
	await _test_wall()
	await _test_budget()
	await _test_far()
	await _test_civilian()
	_finish()


func _box(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	current_scene.add_child(body)
	body.global_position = center
	return body


func _enemy(at: Vector3, yaw := 0.0) -> Node3D:
	var enemy: Node3D = load(ENEMY_SCENE).instantiate()
	enemy.set("profile", load(PROFILE))
	current_scene.add_child(enemy)
	enemy.global_position = at
	enemy.rotation.y = yaw
	return enemy


## Tödlicher Treffer in die Brust aus Richtung `from_dir` (Welt, waagerecht).
func _kill(enemy: Node3D, from_dir: Vector3, damage := 200.0) -> void:
	var chest := enemy.global_position + Vector3.UP * 1.2
	enemy.call("take_hit", damage, chest, -from_dir.normalized())


func _ragdoll(enemy: Node3D) -> Object:
	var model: Object = enemy.get("model")
	return model.get("ragdoll") if model != null else null


func _test_death() -> void:
	print("Tod als Ragdoll")
	var floor_y := ARENA.y
	var enemy := _enemy(ARENA + Vector3(0, 0.05, 0))
	await _frames(5)
	var model: Object = enemy.get("model")
	_check(model.get("ragdoll_skeleton") != null and model.get("ragdoll") == null,
		"Gegnerfigur bereit für Ragdoll, Modifier entsteht erst beim Umfallen")
	var start_pos := enemy.global_position
	# Schuss von +Z (Spielerseite): Leiche fliegt nach −Z.
	_kill(enemy, Vector3(0, 0, 1))
	await _frames(2)
	var rag := _ragdoll(enemy)
	if rag == null:
		_check(false, "Ragdoll beim Tod angelegt")
		return
	var bodies: Dictionary = rag.get("bodies")
	_check(bool(rag.get("running")) and bodies.size() == 11, "Tod schaltet auf Physik: %d Körper" % bodies.size())
	var layers_ok := true
	for b: RigidBody3D in bodies.values():
		layers_ok = layers_ok and b.collision_layer == RAGDOLL_LAYER and b.collision_mask == 1
	_check(layers_ok, "Körper auf Schicht ragdoll, stoßen nur an die Welt")
	var pelvis: RigidBody3D = bodies.get("pelvis")
	var head: RigidBody3D = bodies.get("head")
	_check(pelvis.continuous_cd and head.continuous_cd, "CCD an Becken und Kopf")
	var joints := 0
	for c in (rag as Node).get_children():
		if c is Joint3D:
			joints += 1
	_check(joints == 10, "10 Gelenke (%d)" % joints)
	# Leiche blockiert niemanden: Spieler- und Gegnerkapseln prüfen die Schicht nicht.
	var other := _enemy(ARENA + Vector3(10, 0.05, 10))
	await _frames(2)
	_check((int(_player.get("collision_mask")) & RAGDOLL_LAYER) == 0 and (int(other.get("collision_mask")) & RAGDOLL_LAYER) == 0,
		"Spieler und Gegner laufen durch Leichen (Masken ohne Schicht 4)")
	other.queue_free()
	await _seconds(3.5)
	var p: Vector3 = rag.call("pelvis_position")
	_check(p.y > floor_y and p.y < floor_y + 0.45, "Becken liegt am Boden (%.2f m über dem Boden)" % (p.y - floor_y))
	_check(float(rag.call("max_speed")) < 0.5, "Leiche kommt zur Ruhe (%.2f m/s)" % float(rag.call("max_speed")))
	var lowest := INF
	for b: RigidBody3D in bodies.values():
		lowest = minf(lowest, b.global_position.y)
	_check(lowest > floor_y - 0.02, "Kein Teil im Boden (tiefster %.2f m)" % (lowest - floor_y))
	_check(p.z < start_pos.z + 0.1, "Fällt in Schussrichtung (Becken z %.2f, Start %.2f)" % [p.z, start_pos.z])
	# Knochen folgen den Körpern: Kopfknochen sitzt im Kopfteil.
	# Die Pose mit Ragdoll gibt es nur während des Skelett-Updates (danach stellt Godot die Knochen
	# zurück), deshalb im Signal modification_processed lesen.
	var sk := ((rag as Node).get_parent()) as Skeleton3D
	var head_bone := sk.find_bone("Head")
	var seen := [Vector3.INF]
	(rag as Node).connect("modification_processed", func() -> void:
		seen[0] = (sk.global_transform * sk.get_bone_global_pose(head_bone)).origin, CONNECT_ONE_SHOT)
	for i in 3:
		await process_frame
	var head_world: Vector3 = seen[0]
	_check(head_world.distance_to(head.global_position) < 0.3, "Kopfknochen folgt dem Kopfteil (%.2f m)" % head_world.distance_to(head.global_position))
	# Knie: Unterschenkel nie mehr als 15° nach vorn durchgedrückt.
	var worst := 0.0
	for side: String in ["l", "r"]:
		var up: RigidBody3D = bodies["upper_leg_" + side]
		var low: RigidBody3D = bodies["lower_leg_" + side]
		var axis := up.global_basis.x
		# Rechte Seite der Figur ≈ x der Körper; Knie-Achse = −rechts, Beugung positiv.
		var bent := atan2(up.global_basis.y.cross(low.global_basis.y).dot(-axis), up.global_basis.y.dot(low.global_basis.y))
		worst = minf(worst, rad_to_deg(bent))
	_check(worst > -15.0, "Knie knicken nicht nach vorn durch (kleinster Winkel %.0f°)" % worst)
	# Schüsse gehen durch Leichen (Strahl auf Schicht 1 und 2 trifft keinen Ragdoll-Teil).
	var space := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 0.05, 1 | 2)
	var hit := space.intersect_ray(q)
	_check(hit.is_empty() or not (hit.collider is RigidBody3D), "Schüsse treffen keine Leiche")
	enemy.queue_free()
	await _frames(3)


func _test_wall() -> void:
	print("Stoß gegen die Wand (CCD)")
	var wall_x := ARENA.x + 1.0
	_box(Vector3(wall_x + 0.05, ARENA.y + 1.5, ARENA.z - 20.0), Vector3(0.1, 3.0, 6.0))
	var enemy := _enemy(Vector3(wall_x - 0.5, ARENA.y + 0.05, ARENA.z - 20.0))
	await _frames(5)
	# Sehr starker Treffer Richtung Wand (+X).
	enemy.call("take_hit", 400.0, enemy.global_position + Vector3(0, 1.2, 0), Vector3(-1, 0, 0))
	var rag := _ragdoll(enemy)
	var bodies: Dictionary = rag.get("bodies")
	for b: RigidBody3D in bodies.values():
		b.linear_velocity = Vector3(25, 0, 0)
	var through := PackedStringArray()
	for i in 90:
		await physics_frame
		for b: RigidBody3D in bodies.values():
			if b.global_position.x > wall_x + 0.15 and not through.has(b.name):
				through.append(b.name)
	_check(through.is_empty(), "Mit 25 m/s gegen die Wand: kein Teil dahinter %s" % [through])
	enemy.queue_free()
	await _frames(3)


func _test_budget() -> void:
	print("Budget: höchstens 8 aktive Ragdolls")
	var list: Array[Node3D] = []
	for i in 10:
		list.append(_enemy(ARENA + Vector3(-12 + i * 2.4, 0.05, -6)))
	await _frames(5)
	for e in list:
		_kill(e, Vector3(0, 0, 1))
		await _frames(1)
	await _frames(2)
	var running := 0
	var frozen := 0
	for e in list:
		var r := _ragdoll(e)
		if r != null and bool(r.get("running")) and not bool(r.get("frozen")):
			running += 1
		elif r != null and bool(r.get("frozen")):
			frozen += 1
	_check(running == 8 and frozen == 2, "10 Tote: %d rechnen, %d eingefroren" % [running, frozen])
	_check(bool(_ragdoll(list[0]).get("frozen")) and bool(_ragdoll(list[1]).get("frozen")), "Die zwei ältesten sind eingefroren")
	# Nach 30 s schläft jeder ein.
	var last := _ragdoll(list[9])
	last.set("time", 29.9)
	await _seconds(0.3)
	_check(bool(last.get("frozen")), "Nach 30 s eingefroren")
	for e in list:
		e.queue_free()
	await _frames(3)


func _test_far() -> void:
	print("Weit weg: nur Todesanimation")
	var far := _enemy(_camera.global_position + Vector3(0, -_camera.global_position.y + ARENA.y + 0.05, -55.0))
	_box(far.global_position + Vector3(0, -0.5, 0), Vector3(6, 1, 6))
	await _frames(5)
	_kill(far, Vector3(0, 0, 1))
	await _frames(2)
	var rag := _ragdoll(far)
	_check(rag != null and not bool(rag.get("running")) and bool(far.get("model").call("is_fallen")),
		"55 m entfernt: tot ohne Ragdoll (Animation)")
	far.queue_free()
	await _frames(2)


func _test_civilian() -> void:
	print("Fußgänger: umgeworfen und wieder auf")
	var civ := (load(CIVILIAN) as GDScript).new() as CharacterBody3D
	civ.set("stay_put", true)
	civ.set("net_seed", 7)
	current_scene.add_child(civ)
	civ.global_position = ARENA + Vector3(4, 0.05, 2)
	await _frames(5)
	var model: Object = civ.get("model")
	_check(model.get("ragdoll_skeleton") != null, "Fußgängerfigur bereit für Ragdoll")
	civ.call("hit_by_car", Vector3(1, 0, 0), 5.0)
	await _frames(2)
	var rag: Object = model.get("ragdoll")
	_check(rag != null and bool(rag.get("running")), "Vom Auto umgeworfen: Ragdoll")
	if rag == null:
		return
	await _seconds(2.0)
	model.call("get_up")
	await _seconds(0.7)
	_check(not bool(rag.get("running")) and (rag as Node).get_children().is_empty(),
		"Aufstehen blendet zurück zur Animation, Körper abgebaut")
	var sk := (rag as Node).get_parent() as Skeleton3D
	var hips := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin
	_check(absf(hips.y - (ARENA.y + 0.9)) < 0.3, "Steht wieder (Hüfte %.2f m über dem Boden)" % (hips.y - ARENA.y))
	civ.queue_free()
	await _frames(2)


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
