extends SceneTree
## Prüft die Waffen aus Schedule 1, Phase 4 (P4-1 bis P4-3) in der Testmap:
##   - die 7 neuen Waffen (Revolver, schwere Pistole, Pumpgun, Abgesägte, Bullpup, Kompakt-MP,
##     Präzisionsgewehr): Daten, Ego-Ansicht mit Modell und Markern, Sounds, Preis,
##   - Schrot: 8 Kugeln pro Schuss, Schaden fällt mit der Entfernung (damage_at),
##   - Feuerstoß: ein Klick am Bullpup gibt genau 3 Schuss,
##   - Patrone für Patrone nachladen (Pumpgun), Schießen bricht das Nachladen ab,
##   - Kadenz der Kompakt-MP,
##   - Gegner-Ausrüstung: neue Profile mit Waffe, die Gegnerfigur hält genau dieses Modell,
##     die Neon City setzt alle neuen Profile ein,
##   - Waffenladen: die neuen Waffen hängen kaufbar an den Lochwänden, Präzisionsgewehr ab Stufe 5.
##
## Aufruf (Projektordner), headless reicht:
##   godot --headless --path . -s res://tools/tests/test_weapons_m3.gd
## Letzte Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne Klassennamen aus dem Projekt typisiert (ein -s-Skript wird vor den Autoloads kompiliert).

const TESTMAP := "res://scenes/testmap/testmap.tscn"
const DATA := "res://scenes/items/data/%s.tres"
const NEW_WEAPONS := ["revolver", "heavy_pistol", "pump_shotgun", "sawed_off", "bullpup", "compact_smg", "dmr"]
const NEW_PROFILES := {"gang_leader": "revolver", "gang_shotgun": "pump_shotgun", "gang_sawed_off": "sawed_off",
	"gang_compact_smg": "compact_smg", "security_bullpup": "bullpup", "security_heavy_pistol": "heavy_pistol"}
const PROFILE_DIR := "res://scenes/enemies/profiles/"
const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"
const SHOP_SCRIPT := "res://scenes/crime/street_shop.gd"
const NEON_ENEMIES := "res://scenes/neon_city/neon_city_enemies.tscn"
## Abseits der Map, damit nichts anderes im Weg ist.
const ARENA := Vector3(400.0, 300.0, -400.0)

var _checks := 0
var _fails := 0
var _player: Node3D
var _holder: Node3D


## Ziel mit take_hit, merkt sich jeden Treffer.
class Dummy extends StaticBody3D:
	var hits: Array[float] = []

	func take_hit(damage: float, _point: Vector3, _normal: Vector3) -> void:
		hits.append(damage)


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
		await process_frame
		left -= root.get_process_delta_time()


func _run() -> void:
	_check_data()
	_check_profiles_data()
	_check_neon_city()
	change_scene_to_file(TESTMAP)
	for i in 300:
		if current_scene != null and current_scene.scene_file_path == TESTMAP:
			break
		await physics_frame
	await _frames(20)
	_player = get_first_node_in_group("player") as Node3D
	_check(_player != null, "Spieler in der Testmap")
	if _player == null:
		_finish()
		return
	_holder = _player.get("weapon_holder")
	_platform(ARENA + Vector3(0, -1, 0), Vector3(40, 1, 60))
	_player.global_position = ARENA + Vector3(0, 0.1, 0)
	_player.rotation = Vector3.ZERO
	(_player.get("head") as Node3D).rotation = Vector3.ZERO
	await _frames(10)
	await _test_shotgun()
	await _test_single_reload()
	await _test_burst()
	await _test_compact_smg()
	await _test_enemy_models()
	await _test_enemy_anims()
	await _test_shop()
	_finish()


# --- Daten -------------------------------------------------------------------------------------

func _meshes(node: Node) -> int:
	var n := 1 if node is MeshInstance3D else 0
	for c in node.get_children():
		n += _meshes(c)
	return n


func _check_data() -> void:
	print("Daten der neuen Waffen")
	var models := {}
	for id: String in NEW_WEAPONS:
		var w: Resource = load(DATA % id)
		if w == null:
			_check(false, "%s lädt" % id)
			continue
		_check(str(w.get("id")) == id and w.get("fire_sound") != null and w.get("reload_sound") != null
			and int(w.get("value")) > 0, "%s: id, Sounds, Preis %d ¢" % [id, int(w.get("value"))])
		var scene: PackedScene = w.get("view_scene")
		var view: Node3D = scene.instantiate() if scene != null else null
		if view == null:
			_check(false, "%s: Ego-Ansicht fehlt" % id)
			continue
		var model := view.get_node_or_null("Model")
		_check(model != null and _meshes(model) > 0 and str(model.scene_file_path).contains("quaternius_guns"),
			"%s: Modell aus dem Quaternius-Pack (%s)" % [id, str(model.scene_file_path).get_file() if model else "-"])
		if model != null:
			models[str(model.scene_file_path)] = id
		var muzzle := view.get_node_or_null("Muzzle") as Node3D
		_check(muzzle != null and muzzle.position.z < -0.15 and view.has_node("Muzzle/Flash")
			and view.has_node("Muzzle/FlashLight"), "%s: Mündung vor dem Griff mit Blitz und Licht" % id)
		if muzzle != null:
			var sight: Vector3 = w.get("sight_offset")
			_check(sight.y > muzzle.position.y - 0.05 and sight.y < muzzle.position.y + 0.1,
				"%s: Visier über dem Lauf (%.3f, Lauf %.3f)" % [id, sight.y, muzzle.position.y])
			# Die Mündung sitzt an der Spitze des Modells (höchstens 1,5 cm daneben).
			var front := _front_z(model, view)
			_check(absf(front - muzzle.position.z) < 0.015, "%s: Mündung an der Laufspitze (%.3f / Modell %.3f)" % [id, muzzle.position.z, front])
		if bool(w.get("automatic")) or int(w.get("burst_count")) > 1:
			_check(view.has_node("Magazine/HandReloadLeft") and view.has_node("HandGripLeft"),
				"%s: Magazin mit Nachlade-Marker und linkem Griff" % id)
		if bool(w.get("eject_shells")):
			_check(view.has_node("Eject"), "%s: Hülsenauswurf" % id)
		view.free()
	_check(models.size() == NEW_WEAPONS.size(), "Jede neue Waffe hat ihr eigenes Modell (%d)" % models.size())
	var pump: Resource = load(DATA % "pump_shotgun")
	var near: float = pump.call("damage_at", 3.0)
	var mid: float = pump.call("damage_at", 14.0)
	var far: float = pump.call("damage_at", 40.0)
	_check(is_equal_approx(near, 13.0) and mid < near and mid > far and is_equal_approx(far, 13.0 * 0.25),
		"Schadensabfall Pumpgun: 3 m %.1f, 14 m %.1f, 40 m %.1f pro Kugel" % [near, mid, far])
	var pistol: Resource = load(DATA % "pistol")
	_check(is_equal_approx(float(pistol.call("damage_at", 70.0)), float(pistol.get("damage"))),
		"Pistole ohne Abfall (alte Waffen unverändert)")


## Vorderste Spitze der Meshes unter `model` in Koordinaten der Waffenszene (kleinstes z).
func _front_z(model: Node, view: Node3D) -> float:
	var best := INF
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != view:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				best = minf(best, (xf * v).z)
	return best


func _check_profiles_data() -> void:
	print("Gegner-Ausrüstung")
	for name: String in NEW_PROFILES:
		var p: Resource = load(PROFILE_DIR + name + ".tres")
		var w: Resource = p.get("weapon") if p != null else null
		_check(w != null and str(w.get("id")) == NEW_PROFILES[name] and int(p.get("style")) == 1,
			"%s trägt %s" % [name, NEW_PROFILES[name]])
		var loot: Array = p.get("loot_items") if p != null else []
		_check(loot.has(w), "%s lässt seine Waffe als Beute fallen" % name)
	var smg_gang: Resource = load(PROFILE_DIR + "gangster_smg.tres")
	_check(smg_gang.get("weapon") != null and str(smg_gang.get("weapon").get("id")) == "smg", "SMG-Gangster halten die SMG")


func _check_neon_city() -> void:
	var text := FileAccess.get_file_as_string(NEON_ENEMIES)
	var missing := PackedStringArray()
	for name: String in NEW_PROFILES:
		var path := PROFILE_DIR + name + ".tres"
		var at := text.find(path)
		if at < 0:
			missing.append(name)
			continue
		var id := text.substr(at).get_slice("id=\"", 1).get_slice("\"", 0)
		if not text.contains("profile = ExtResource(\"%s\")" % id):
			missing.append(name)
	_check(missing.is_empty(), "Neon City setzt alle neuen Gegnerprofile ein %s" % [missing])


# --- Schießen ----------------------------------------------------------------------------------

func _platform(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	current_scene.add_child(body)
	body.global_position = center
	return body


func _dummy(distance: float, size: Vector3) -> Dummy:
	var camera: Camera3D = _player.get("camera")
	var body := Dummy.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	current_scene.add_child(body)
	body.global_position = camera.global_position - camera.global_basis.z * distance
	return body


func _give(id: String) -> Resource:
	var item: Resource = load(DATA % id)
	var inventory: Node = _player.get("inventory")
	for i in 9:
		inventory.call("_clear", i)
	inventory.call("add_item", item, 1)
	# Munition für das Nachladen (P4-4).
	if item.get("ammo") != null:
		inventory.call("add_item", item.get("ammo"), 200)
	inventory.call("select", 1)
	inventory.call("select", 0)
	return item


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.action_press(action)


func _release(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	Input.action_release(action)


## Ein Klick: drücken, ein paar Bilder halten, loslassen.
func _click(action: String) -> void:
	_press(action)
	await _frames(3)
	_release(action)


func _test_shotgun() -> void:
	print("Pumpgun: Schrot und Schadensabfall")
	var pump: Resource = _give("pump_shotgun")
	await _frames(3)
	_check(_holder.call("get_weapon") == pump and int(_holder.call("get_ammo")) == 6, "Pumpgun in der Hand, 6 Patronen")
	var near := _dummy(3.0, Vector3(3.0, 3.0, 0.3))
	await _frames(2)
	await _click("fire")
	await _frames(3)
	_check(near.hits.size() == 8, "Ein Schuss auf 3 m: %d von 8 Kugeln treffen" % near.hits.size())
	var total := 0.0
	for h in near.hits:
		total += h
	_check(is_equal_approx(total, 8.0 * 13.0), "Nah voller Schaden: %.0f (8 × 13)" % total)
	_check(int(_holder.call("get_ammo")) == 5, "Eine Patrone verbraucht")
	near.queue_free()
	await _frames(2)
	await _seconds(1.0)
	var far := _dummy(18.0, Vector3(8.0, 8.0, 0.3))
	await _frames(2)
	await _click("fire")
	await _frames(3)
	var expected: float = pump.call("damage_at", 18.0 - 0.15)
	var ok := far.hits.size() > 0
	for h in far.hits:
		ok = ok and h < 13.0 * 0.6 and absf(h - expected) < 0.6
	_check(ok, "Auf 18 m weniger Schaden: %d Kugeln je %.1f (Soll %.1f)" % [far.hits.size(), far.hits[0] if far.hits.size() > 0 else 0.0, expected])
	far.queue_free()


func _test_single_reload() -> void:
	print("Pumpgun: Patrone für Patrone")
	await _seconds(1.0)
	var pump: Resource = _holder.call("get_weapon")
	var start: int = _holder.call("get_ammo")
	await _click("reload")
	var per: float = float(pump.get("reload_time")) * float(_player.call("skill_mult", &"reload_mult"))
	await _seconds(per + 0.15)
	_check(int(_holder.call("get_ammo")) == start + 1 and bool(_holder.call("is_reloading")),
		"Nach %.2f s eine Patrone mehr (%d → %d), lädt weiter" % [per, start, int(_holder.call("get_ammo"))])
	# Schießen bricht ab: ein Schuss raus, kein Nachladen mehr.
	var before: int = _holder.call("get_ammo")
	await _click("fire")
	await _frames(3)
	_check(not bool(_holder.call("is_reloading")) and int(_holder.call("get_ammo")) == before - 1,
		"Schießen bricht das Nachladen ab und schießt (%d → %d)" % [before, int(_holder.call("get_ammo"))])
	await _seconds(1.0)
	await _click("reload")
	await _seconds(per * 6.0 + 0.6)
	_check(int(_holder.call("get_ammo")) == 6 and not bool(_holder.call("is_reloading")), "Bis voll nachgeladen (6)")


func _test_burst() -> void:
	print("Bullpup: Dreierfeuerstoß")
	var bp: Resource = _give("bullpup")
	await _frames(3)
	var target := _dummy(4.0, Vector3(2.0, 2.0, 0.3))
	await _frames(2)
	await _click("fire")
	await _seconds(0.3)
	_check(int(_holder.call("get_ammo")) == 27, "Ein Klick, drei Schuss (%d übrig)" % int(_holder.call("get_ammo")))
	_check(target.hits.size() == 3 and is_equal_approx(target.hits[0], float(bp.get("damage"))),
		"Drei Treffer je %.0f" % float(bp.get("damage")))
	# Halten gibt genau einen Feuerstoß (Bullpup ist nicht automatisch).
	await _seconds(0.5)
	_press("fire")
	await _seconds(1.0)
	_release("fire")
	await _frames(3)
	_check(int(_holder.call("get_ammo")) == 24, "Halten: genau ein Feuerstoß (%d übrig)" % int(_holder.call("get_ammo")))
	target.queue_free()


func _test_compact_smg() -> void:
	print("Kompakt-MP: Kadenz")
	var mp: Resource = _give("compact_smg")
	await _frames(3)
	var start: int = _holder.call("get_ammo")
	_press("fire")
	var since := -1.0
	var frames := 0
	while since < 0.8 and frames < 720:
		frames += 1
		await process_frame
		if since >= 0.0:
			since += root.get_process_delta_time()
		elif int(_holder.call("get_ammo")) < start:
			since = 0.0
	_release("fire")
	var fired := start - int(_holder.call("get_ammo"))
	var rate := (fired - 1) / maxf(since, 0.001)
	var want := 1.0 / float(mp.get("fire_interval"))
	_check(absf(rate - want) < want * 0.15, "Kadenz %.1f/s (Soll %.1f/s, %d Schuss)" % [rate, want, fired])


# --- Gegner und Laden --------------------------------------------------------------------------

func _test_enemy_models() -> void:
	print("Gegner halten ihre Waffe")
	for name: String in NEW_PROFILES:
		var enemy: Node3D = load(ENEMY_SCENE).instantiate()
		enemy.set("profile", load(PROFILE_DIR + name + ".tres"))
		current_scene.add_child(enemy)
		enemy.global_position = ARENA + Vector3(6, 0.1, 6)
		await _frames(2)
		var model: Node = enemy.get("model")
		var gun := model.find_child("Gun", true, false) if model != null else null
		var want: String = load(DATA % NEW_PROFILES[name]).get("view_scene").resource_path
		_check(gun != null and gun.scene_file_path == want, "%s: Modell %s in der Hand" % [name, want.get_file()])
		enemy.queue_free()
		await _frames(1)


## P4-6: Zielen, Schießen und Nachladen als Oberkörper-Ebene (UAL1 Pistol_*), auch im Laufen.
func _test_enemy_anims() -> void:
	print("Gegner zielen, schießen und laden nach (UAL1)")
	var enemy: Node3D = load(ENEMY_SCENE).instantiate()
	enemy.set("profile", load(PROFILE_DIR + "gang_leader.tres"))
	current_scene.add_child(enemy)
	enemy.global_position = ARENA + Vector3(6, 0.1, 6)
	enemy.set_physics_process(false)
	await _frames(2)
	var model: Node = enemy.get("model")
	var overlay: AnimOverlay = model.get("_overlay")
	_check(overlay != null, "Bewaffneter Gegner hat die Oberkörper-Ebene")
	if overlay == null:
		enemy.queue_free()
		return
	model.set("aim", 1.0)
	model.set("speed", 3.0)
	for i in 30:
		model.call("animate", 1.0 / 30.0)
		await process_frame
	var anim: AnimationPlayer = model.get("_anim")
	_check(overlay.aim_weight > 0.9 and anim.current_animation.ends_with("Run"),
		"Zielt im Laufen: Beine laufen (%s), Oberkörper zielt (%.2f)" % [anim.current_animation, overlay.aim_weight])
	# Zielen dreht den Oberarm sichtbar gegenüber der Laufpose.
	var sk: Skeleton3D = model.get("ragdoll_skeleton")
	var arm := sk.find_bone("UpperArm.R")
	var seen := [Quaternion(), Quaternion()]
	sk.skeleton_updated.connect(func() -> void: seen[0] = sk.get_bone_pose_rotation(arm), CONNECT_ONE_SHOT)
	await process_frame
	await process_frame
	seen[1] = sk.get_bone_pose_rotation(arm)
	_check(seen[0].angle_to(seen[1]) > 0.2, "Ebene ändert den Arm (%.0f°)" % rad_to_deg(seen[0].angle_to(seen[1])))
	enemy.call("_play_sfx", &"reload", false)
	_check(overlay.is_busy() and str(overlay.get("_action")) == AnimOverlay.RELOAD, "Nachladen spielt Pistol_Reload")
	await _frames(2)
	model.call("trigger_shot")
	_check(str(overlay.get("_action")) == AnimOverlay.SHOOT, "Schuss spielt Pistol_Shoot")
	enemy.call("take_hit", 5.0, enemy.global_position + Vector3.UP * 1.2, Vector3.FORWARD)
	enemy.call("take_hit", 500.0, enemy.global_position + Vector3.UP * 1.2, Vector3.FORWARD)
	await _frames(2)
	_check(overlay.aim_weight == 0.0 and not overlay.is_busy(), "Tot: Ebene aus")
	enemy.queue_free()
	await _frames(1)


func _test_shop() -> void:
	print("Waffenladen: Lochwände")
	var shop: Node3D = load(SHOP_SCRIPT).new()
	shop.name = "TestShop"
	current_scene.add_child(shop)
	shop.global_position = ARENA + Vector3(-15, 0, 15)
	await _frames(3)
	var errors: PackedStringArray = shop.get("layout_errors")
	_check(errors.is_empty(), "Grundriss weiterhin ohne Verstoß %s" % [errors])
	var walls := {}
	for child in shop.get_children():
		if str(child.name).begins_with("Wall_"):
			walls[str(child.get("item").get("id"))] = child
	var want := ["pump_shotgun", "revolver", "heavy_pistol", "dmr", "compact_smg"]
	var missing := PackedStringArray()
	for id: String in want:
		if not walls.has(id):
			missing.append(id)
	_check(missing.is_empty(), "Kaufbar an der Wand: %s %s" % [", ".join(walls.keys()), missing])
	if walls.has("dmr"):
		var dmr: Node = walls["dmr"]
		var xp: Node = _player.get("xp")
		xp.set("level", 1)
		var text: String = dmr.call("get_interact_text", _player)
		_check(text.contains("ab Stufe 5"), "Präzisionsgewehr zeigt Mindeststufe: \"%s\"" % text)
		var inventory: Node = _player.get("inventory")
		for i in 9:
			inventory.call("_clear", i)
		inventory.call("add_money", 1000)
		var money: int = inventory.get("money")
		dmr.call("interact", _player)
		_check(int(inventory.get("money")) == money, "Unter Stufe 5 nicht kaufbar")
		xp.set("level", 5)
		dmr.call("interact", _player)
		_check(int(inventory.get("money")) == money - 260, "Ab Stufe 5 für 260 ¢ gekauft")
	# Die Waffen hängen vor der Platte, nicht in der Wand, und innerhalb der Plattenfläche.
	var bad := PackedStringArray()
	for id: String in walls:
		var sale: Node3D = walls[id]
		var p := sale.position
		if absf(p.x) > 3.52 - 0.02 or absf(p.x) < 3.3 or p.y < 1.0 or p.y > 2.2:
			bad.append("%s %s" % [id, p])
	_check(bad.is_empty(), "Wandplätze vor den Lochwänden %s" % [bad])
	shop.queue_free()
	await _frames(2)


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
