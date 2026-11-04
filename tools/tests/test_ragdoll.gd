extends SceneTree
## Prüft die Ragdolls aus Schedule 1, Phase 5 (P5-1, P5-2, P5-4, P5-5) in der Testmap:
##   - Gerüst: 11 Körper auf Schicht „ragdoll“, 10 Gelenke, CCD an Becken und Kopf, Haut der Leiche
##     höchstens wenige Zentimeter im Boden,
##   - Tod nah an der Kamera schaltet auf Physik, die Leiche kommt am Boden zur Ruhe, die Knochen
##     folgen den Körpern, Knie knicken nicht nach vorn durch,
##   - ein Schuss stößt in Schussrichtung, ein Stoß gegen die Wand geht nicht hindurch (CCD),
##   - Leichen blockieren weder Spieler noch Gegner noch Schüsse,
##   - Budget: höchstens 8 aktive, ältere frieren ein; weit weg nur Todesanimation; nach 30 s Schlaf,
##   - Fußgänger: vom Auto umgeworfen als Ragdoll, stehen mit UAL2 LayToIdle wieder auf (Rücken- und
##     Bauchlage, an der Wand): erstes Bild auf dem liegenden Körper, Haut nie im Boden, Kapsel frei,
##   - leichte Treffer: Hit_Head oder Hit_Chest nach Trefferhöhe (P5-6),
##   - schwerer Treffer wirft lebende Gegner um, im Liegen treffbar, sie stehen auf und kämpfen (P5-2).
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
	await _test_hit_zones()
	await _test_knockdown()
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
	# Haut der liegenden Leiche (Hand- und Fußkapseln halten Finger und Schuhe über dem Boden).
	var skel := ((rag as Node).get_parent()) as Skeleton3D
	var skin_low := [INF]
	var skin_high := [-INF]
	skel.connect("skeleton_updated", func() -> void:
		skin_low[0] = _skin_lowest(skel)
		skin_high[0] = -_skin_lowest(skel, true), CONNECT_ONE_SHOT)
	await _frames(3)
	_check(skin_low[0] > floor_y - 0.06, "Haut der Leiche kaum im Boden (tiefster Punkt %.3f m)" % (skin_low[0] - floor_y))
	# Alle Hautpunkte folgen dem Körper (keine Fläche bleibt in Standhöhe hängen, z. B. am Knochen Body).
	_check(skin_high[0] < floor_y + 0.75, "Haut der Leiche liegt flach, nichts hängt in Standhöhe (höchster Punkt %.2f m)" % (skin_high[0] - floor_y))
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
	print("Fußgänger: umgeworfen und wieder auf (UAL2 LayToIdle)")
	# Rücken: Stoß von vorn (Fußgänger schauen nach -Z), Bauch: Stoß von hinten, Wand: Stoß dagegen.
	await _get_up_case("Rückenlage", ARENA + Vector3(4, 0.05, 2), Vector3(0, 0, 1), 5.0, null)
	await _get_up_case("Bauchlage", ARENA + Vector3(-6, 0.05, 2), Vector3(0, 0, -1), 5.0, null)
	var wall := _box(ARENA + Vector3(12.0, 1.5, -6.0), Vector3(0.3, 3.0, 6.0))
	await _get_up_case("an der Wand", ARENA + Vector3(10.6, 0.05, -6.0), Vector3(1, 0, 0), 6.5, wall)
	wall.queue_free()
	await _frames(2)


## Umwerfen, liegen lassen, aufstehen. Prüft Ragdoll, Ausrichtung des ersten Animationsbilds auf dem
## liegenden Körper, Rückenlage beim Aufstehen, Haut nie unter dem Boden, Kapsel frei, Ende stehend.
func _get_up_case(label: String, at: Vector3, push: Vector3, speed: float, wall: StaticBody3D) -> void:
	var civ := (load(CIVILIAN) as GDScript).new() as CharacterBody3D
	civ.set("stay_put", true)
	civ.set("net_seed", 7)
	current_scene.add_child(civ)
	civ.global_position = at
	await _frames(5)
	var model: Object = civ.get("model")
	var anim := (model.get("_anim") as AnimationPlayer)
	_check(model.get("ragdoll_skeleton") != null and anim != null and anim.has_animation(UalLibrary.GET_UP),
		"%s: Figur hat Ragdoll-Skelett und %s" % [label, UalLibrary.GET_UP])
	civ.call("hit_by_car", push, speed)
	await _frames(2)
	var rag: Ragdoll = model.get("ragdoll")
	_check(rag != null and rag.running, "%s: vom Auto umgeworfen, Ragdoll" % label)
	if rag == null:
		civ.queue_free()
		return
	var sk := rag.get_skeleton()
	var hips := sk.find_bone("Hips")
	for i in 240:
		if rag.max_speed() < 0.3 and rag.time > 1.0:
			break
		await physics_frame
	var face := rag.facing_up()
	model.call("get_up")
	# Warten, bis das Aufstehen beginnt (Bauchlage: erst umdrehen). Ragdoll-Becken bis dahin mitschreiben.
	var rag_hips := rag.bone_position(hips)
	var up_at_rise := face
	for i in 240:
		if float(model.get("_rise_left")) > 0.0:
			break
		rag_hips = rag.bone_position(hips)
		up_at_rise = rag.facing_up()
		await physics_frame
	var rising := float(model.get("_rise_left")) > 0.0
	_check(rising, "%s: steht auf (lag mit Brust %s)" % [label, "oben" if face > 0.0 else "unten"])
	if not rising:
		civ.queue_free()
		return
	_check(up_at_rise > 0.4, "%s: beim Aufstehen auf dem Rücken (Brust nach oben %.2f)" % [label, up_at_rise])
	var anim_hips := (sk.global_transform * sk.get_bone_global_pose(hips)).origin
	var off := anim_hips - rag_hips
	_check(Vector2(off.x, off.z).length() < 0.15,
		"%s: erstes Bild sitzt auf dem liegenden Körper (Becken %.2f m daneben, %.2f m Höhe)" % [label, Vector2(off.x, off.z).length(), off.y])
	# Haut während des Aufstehens nie unter dem Boden (Pose samt Ragdoll-Überblendung).
	var floor_y := ARENA.y
	var lowest := [INF]
	var probe := func() -> void:
		lowest[0] = minf(lowest[0], _skin_lowest(sk))
	sk.skeleton_updated.connect(probe)
	# Hineinfahren (RISE_MATCH) + Animation + etwas Luft.
	var length := anim.get_animation(UalLibrary.GET_UP).length + EnemyModel.RISE_MATCH
	await _seconds(length + 0.3)
	sk.skeleton_updated.disconnect(probe)
	_check(lowest[0] > floor_y - 0.05, "%s: Haut nie im Boden (tiefster Punkt %.3f m)" % [label, lowest[0] - floor_y])
	_check(not rag.running and (rag as Node).get_children().is_empty(), "%s: Ragdoll abgebaut" % label)
	_check(not bool(model.call("is_fallen")), "%s: steht wieder" % label)
	var stand := (sk.global_transform * sk.get_bone_global_pose(hips)).origin
	_check(absf(stand.y - (floor_y + 0.8)) < 0.15, "%s: Hüfte auf Standhöhe (%.2f m)" % [label, stand.y - floor_y])
	_check(not _capsule_blocked(civ), "%s: Kapsel steckt in keiner Wand" % label)
	if wall != null:
		_check(civ.global_position.x < wall.global_position.x - 0.15, "%s: steht vor der Wand, nicht dahinter (x %.2f, Wand %.2f)" % [label, civ.global_position.x, wall.global_position.x])
	civ.queue_free()
	await _frames(2)


## P5-6: leichte Treffer spielen je nach Höhe Hit_Head oder Hit_Chest (UAL1, retargetet).
func _test_hit_zones() -> void:
	print("Trefferreaktion nach Zone")
	var enemy := _enemy(ARENA + Vector3(-3, 0.05, -8))
	await _frames(10)
	var model: Object = enemy.get("model")
	var head_y := enemy.global_position.y + 1.72
	enemy.call("take_hit", 8.0, Vector3(enemy.global_position.x, head_y, enemy.global_position.z), Vector3(0, 0, 1))
	await _frames(4)
	_check(str(model.get("_current")) == EnemyModel.HIT_HEAD, "Kopftreffer: %s" % model.get("_current"))
	await _seconds(1.0)
	enemy.call("take_hit", 15.0, enemy.global_position + Vector3.UP * 1.15, Vector3(0, 0, 1))
	await _frames(4)
	_check(str(model.get("_current")) == EnemyModel.HIT_CHEST, "Brusttreffer: %s" % model.get("_current"))
	await _seconds(1.0)
	_check(not bool(model.call("is_fallen")), "Leichte Treffer werfen nicht um")
	enemy.queue_free()
	await _frames(2)


## P5-2: Schwerer Treffer (ab 25 % der vollen LP) wirft einen lebenden Gegner um, er liegt betäubt,
## ist im Liegen treffbar, steht auf und kämpft weiter. Im Liegen erschossen: tot.
func _test_knockdown() -> void:
	print("Schwerer Treffer: umfallen und wieder auf")
	var enemy := _enemy(ARENA + Vector3(3, 0.05, -10))
	await _frames(10)
	var model: Object = enemy.get("model")
	var floor_y := ARENA.y
	var stand_pos := enemy.global_position
	enemy.call("take_hit", 30.0, enemy.global_position + Vector3.UP * 1.15, Vector3(0, 0, 1))
	await _frames(3)
	var rag: Ragdoll = model.get("ragdoll")
	_check(int(enemy.get("state")) == 6 and bool(model.call("is_fallen")) and rag != null and rag.running,
		"30 von 70 LP: umgeworfen (betäubt, Ragdoll)")
	await _seconds(1.2)
	var chest := rag.part_position("chest") if rag != null else Vector3.INF
	var space := enemy.get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(chest + Vector3.UP * 2.0, chest + Vector3.DOWN * 0.5, 1 | 2, [_player.get_rid()]))
	_check(not down.is_empty() and down.collider == enemy, "Liegt: Schuss auf die Brust trifft ihn (%s)" % [down.get("collider")])
	var old := space.intersect_ray(PhysicsRayQueryParameters3D.create(stand_pos + Vector3(-2, 1.5, 0), stand_pos + Vector3(2, 1.5, 0), 1 | 2, [_player.get_rid()]))
	_check(old.is_empty() or old.collider != enemy, "Liegt: an der alten Stelle in Kopfhöhe ist nichts mehr")
	var lowest := [INF]
	var sk := rag.get_skeleton() if rag != null else null
	var probe := func() -> void:
		lowest[0] = minf(lowest[0], _skin_lowest(sk))
	if sk != null:
		sk.skeleton_updated.connect(probe)
	for i in 600:
		if int(enemy.get("state")) != 6:
			break
		await physics_frame
	if sk != null:
		sk.skeleton_updated.disconnect(probe)
	_check(int(enemy.get("state")) == 3 and not bool(model.call("is_fallen")), "Steht auf und kämpft weiter (Zustand %d)" % int(enemy.get("state")))
	_check(lowest[0] > floor_y - 0.05, "Beim Aufstehen Haut nie im Boden (tiefster Punkt %.3f m)" % (lowest[0] - floor_y))
	var shape := enemy.get("_shape") as CollisionShape3D
	_check(shape != null and shape.transform.is_equal_approx(enemy.get("_shape_rest")), "Kapsel steht wieder")
	enemy.queue_free()
	await _frames(2)
	# Im Liegen erschossen.
	var other := _enemy(ARENA + Vector3(-3, 0.05, -10))
	await _frames(10)
	other.call("take_hit", 30.0, other.global_position + Vector3.UP * 1.15, Vector3(0, 0, 1))
	await _seconds(1.0)
	other.call("take_hit", 60.0, (_ragdoll(other) as Ragdoll).part_position("chest"), Vector3.UP)
	await _frames(3)
	_check(bool(other.call("is_dead")), "Im Liegen erschossen: tot")
	other.queue_free()
	await _frames(2)


## Tiefster Punkt der Haut (CPU: Gewichte x Knochen x Bindungspose), jeder zweite Punkt; mit highest
## der höchste, negativ.
func _skin_lowest(sk: Skeleton3D, highest := false) -> float:
	var low := INF
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false) + sk.get_parent().find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.get_node_or_null(mi.skeleton) != sk:
			continue
		var mats: Array[Transform3D] = []
		for i in mi.skin.get_bind_count():
			var bn := mi.skin.get_bind_name(i)
			var bone := sk.find_bone(bn) if bn != "" else mi.skin.get_bind_bone(i)
			mats.append(sk.global_transform * sk.get_bone_global_pose(bone) * mi.skin.get_bind_pose(i))
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / verts.size()
			for v in range(0, verts.size(), 2):
				var y := 0.0
				for j in per:
					var w := weights[v * per + j]
					if w > 0.0:
						y += (mats[bones[v * per + j]] * verts[v]).y * w
				low = minf(low, -y if highest else y)
	return low


func _capsule_blocked(body: CharacterBody3D) -> bool:
	for child in body.get_children():
		if child is CollisionShape3D:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = (child as CollisionShape3D).shape
			query.collision_mask = 1
			query.exclude = [body.get_rid()]
			query.transform = body.global_transform * (child as CollisionShape3D).transform * Transform3D(Basis(), Vector3.UP * 0.06)
			return not body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	return false


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
