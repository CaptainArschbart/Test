extends SceneTree
## Prüft SMG und Kontaktgranate in der Testmap: Feuerrate, Magazin, Nachladen (Magazin fällt
## heraus, linke Hand folgt), Streuung beim Dauerfeuer, Zielen, Hülsen, Schaden und Lärm;
## Kontaktzündung an Boden, Hindernis in der Luft und Gegner, Schaden mit Abfall, Radius, Deckung,
## Camera-Shake, Wurfablauf der Hand, Granaten-Anzeige und dass EMP und Pistole unverändert sind.
##
## Aufruf (Projektordner), mit Fenster, weil die Waffe nur bei gefangener Maus schießt:
##   godot --path . -s res://tools/tests/test_weapons_smg_grenade.gd
##   (Linux ohne Bildschirm: xvfb-run -a godot --rendering-driver opengl3 --path . -s …)
## Letzte Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne Klassennamen aus dem Projekt typisiert (ein -s-Skript wird vor den Autoloads kompiliert).

const TESTMAP := "res://scenes/testmap/testmap.tscn"
const SMG := "res://scenes/items/data/smg.tres"
const PISTOL := "res://scenes/items/data/pistol.tres"
const CONTACT := "res://scenes/items/data/contact_grenade.tres"
const EMP := "res://scenes/items/data/emp_grenade.tres"
const GRENADE_SCRIPT := "res://scenes/items/grenade.gd"
## Abseits der Map, damit nichts anderes im Weg ist.
const ARENA := Vector3(400.0, 300.0, 400.0)

var _checks := 0
var _fails := 0
var _player: Node3D
var _holder: Node3D
var _item_user: Node3D
var _heard: Array = []


## Ziel mit take_hit, merkt sich jeden Treffer.
class Dummy extends StaticBody3D:
	var hits: Array[float] = []

	func take_hit(damage: float, _point: Vector3, _normal: Vector3) -> void:
		hits.append(damage)

	func total() -> float:
		var sum := 0.0
		for h in hits:
			sum += h
		return sum


## Hört Geräusche wie ein Gegner (Gruppe noise_listener).
class Listener extends Node3D:
	var log: Array = []

	func hear_noise(_position: Vector3, radius: float, _source: Node, kind: StringName) -> void:
		log.append([kind, radius])


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


## Wartet `s` Sekunden Spielzeit (bei langsamen Renderern länger als echte Zeit).
func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await process_frame
		left -= root.get_process_delta_time()


func _run() -> void:
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
	_item_user = _player.get("item_user")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(2)
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Maus gefangen (sonst schießt keine Waffe)")
	var listener := Listener.new()
	listener.add_to_group(&"noise_listener")
	current_scene.add_child(listener)

	# Spieler auf eine eigene Plattform in der Luft, Blick nach -Z, waagerecht.
	_platform(ARENA + Vector3(0, -1, 0), Vector3(30, 1, 30))
	_player.global_position = ARENA + Vector3(0, 0.1, 0)
	_player.rotation = Vector3.ZERO
	(_player.get("head") as Node3D).rotation = Vector3.ZERO
	await _frames(10)

	await _test_smg(listener)
	await _test_pistol_semi()
	await _test_contact_grenade(listener)
	await _test_throw()
	await _test_emp_unchanged()
	_finish()


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


func _dummy(center: Vector3, size: Vector3) -> Dummy:
	var body := Dummy.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	current_scene.add_child(body)
	body.global_position = center
	return body


func _give(path: String, count := 1) -> Resource:
	var item: Resource = load(path)
	var inventory: Node = _player.get("inventory")
	for i in 9:
		inventory.call("_clear", i)
	inventory.call("add_item", item, count)
	inventory.call("select", 1)
	inventory.call("select", 0)
	return item


func _test_smg(listener: Listener) -> void:
	print("SMG")
	var smg: Resource = _give(SMG)
	await _frames(3)
	_check(_holder.call("get_weapon") == smg, "SMG in der Hand")
	var view: Node3D = null
	for child in _holder.get_children():
		if child is Node3D and child.has_node("Muzzle"):
			view = child
	_check(view != null and view.has_node("Magazine/HandReloadLeft") and view.has_node("Eject"),
		"SMG-Modell mit Magazin, Hand-Marker und Auswurf")
	_check(_holder.call("get_ammo") == 30, "volles Magazin: 30")

	# Ziel 3 m vor der Kamera.
	var camera: Camera3D = _player.get("camera")
	var target := _dummy(camera.global_position - camera.global_basis.z * 3.0, Vector3(1.4, 1.4, 0.3))
	await _frames(2)
	listener.log.clear()
	var hip_spread: float = _holder.call("get_spread_degrees")

	# Dauerfeuer 1 s.
	var shells_before := _count_shells()
	var start_ammo: int = _holder.call("get_ammo")
	_press("fire")
	# Feuerrate ab dem ersten Schuss messen (der Klick kommt erst im nächsten Bild an).
	var since_first := -1.0
	var max_spread := hip_spread
	while since_first < 1.0:
		await process_frame
		if since_first >= 0.0:
			since_first += root.get_process_delta_time()
		elif int(_holder.call("get_ammo")) < start_ammo:
			since_first = 0.0
		max_spread = maxf(max_spread, _holder.call("get_spread_degrees"))
	var fired: int = start_ammo - int(_holder.call("get_ammo"))
	var rate := (fired - 1) / since_first
	var target_rate: float = 1.0 / smg.fire_interval
	_check(absf(rate - target_rate) < target_rate * 0.12, "Feuerrate: %d Schuss, %.1f/s (Soll %.1f/s = %d Schuss/min)" % [fired, rate, target_rate, roundi(target_rate * 60.0)])
	_check(max_spread > hip_spread + 3.0, "Streuung wächst beim Dauerfeuer (%.2f° → %.2f°)" % [hip_spread, max_spread])
	_check(target.hits.size() >= fired - 2 and is_equal_approx(target.hits[0], smg.damage),
		"Treffer am Ziel: %d von %d, je %.0f Schaden" % [target.hits.size(), fired, target.hits[0] if target.hits.size() > 0 else 0.0])
	_check(_count_shells() > shells_before, "Hülsen fliegen (%d)" % (_count_shells() - shells_before))
	var heard_shot := false
	for entry in listener.log:
		if entry[0] == &"shot" and is_equal_approx(entry[1], smg.noise_radius):
			heard_shot = true
	_check(heard_shot, "Schüsse sind für Gegner hörbar (%.0f m)" % smg.noise_radius)
	_release("fire")
	await _seconds(0.8)
	var calm: float = _holder.call("get_spread_degrees")
	_check(absf(calm - hip_spread) < 0.05, "Streuung geht ohne Schießen zurück (%.2f°)" % calm)

	# Zielen.
	_press("aim")
	await _seconds(0.4)
	_check(_holder.call("get_aim") > 0.99, "Zielen: voll im Anschlag")
	var aim_spread: float = _holder.call("get_spread_degrees")
	_check(aim_spread < hip_spread * 0.3, "Zielen: Streuung %.2f° statt %.2f°" % [aim_spread, hip_spread])
	_check(camera.fov < 60.0, "Zielen: Kamera zoomt (FOV %.0f)" % camera.fov)
	var dot := view.get_node("Sight/Dot") as Node3D
	var local := camera.global_transform.affine_inverse() * dot.global_position
	_check(absf(local.x) < 0.01 and absf(local.y) < 0.01, "Zielen: Rotpunkt in der Bildmitte (%.3f, %.3f)" % [local.x, local.y])
	_release("aim")
	await _seconds(0.3)

	# Magazin leer schießen, automatisches Nachladen.
	_press("fire")
	for i in 400:
		await process_frame
		if _holder.call("is_reloading"):
			break
	_release("fire")
	_check(_holder.call("is_reloading"), "leeres Magazin lädt von selbst nach")
	var magazine := view.get_node("Magazine") as Node3D
	var base_y := magazine.position.y
	var lowest := base_y
	var hand_gap := 1.0
	var hands: Node3D = _player.get("hands")
	var left: Node3D = null
	for child in hands.get_children():
		if child is Node3D and child.name.to_lower().contains("left"):
			left = child
	var reload_s := 0.0
	while _holder.call("is_reloading"):
		await process_frame
		reload_s += root.get_process_delta_time()
		lowest = minf(lowest, magazine.position.y)
		var p: float = _holder.call("get_reload_progress")
		if left != null and p > 0.4 and p < 0.5:
			var marker := view.get_node("Magazine/HandReloadLeft") as Node3D
			hand_gap = minf(hand_gap, left.global_position.distance_to(marker.global_position))
	_check(reload_s > smg.reload_time - 0.2 and reload_s < smg.reload_time + 0.2, "Nachladen dauert %.2f s (Soll %.1f)" % [reload_s, smg.reload_time])
	_check(lowest < base_y - 0.15, "Magazin fällt beim Nachladen heraus (%.2f m)" % (base_y - lowest))
	_check(absf(magazine.position.y - base_y) < 0.001, "Magazin sitzt danach wieder")
	if left != null:
		_check(hand_gap < 0.12, "linke Hand am Magazin (%.3f m)" % hand_gap)
	_check(_holder.call("get_ammo") == 30, "nach dem Nachladen wieder 30 Schuss")
	target.queue_free()
	await _frames(2)


func _test_pistol_semi() -> void:
	print("Pistole (unverändert halbautomatisch)")
	_give(PISTOL)
	await _frames(3)
	var before: int = _holder.call("get_ammo")
	_press("fire")
	await _seconds(0.7)
	_release("fire")
	_check(before - int(_holder.call("get_ammo")) == 1, "Pistole: Halten gibt genau einen Schuss")


func _test_contact_grenade(listener: Listener) -> void:
	print("Kontaktgranate")
	var data: Resource = load(CONTACT)
	var script: Script = load(GRENADE_SCRIPT)
	var far := ARENA + Vector3(150, 0, 0)
	_platform(far + Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	# 1) Fällt auf den Boden: explodiert beim ersten Aufprall, ohne Abprallen.
	var grenade: RigidBody3D = script.new()
	grenade.set("data", data)
	current_scene.add_child(grenade)
	grenade.global_position = far + Vector3(0, 3, 0)
	var exploded_at := Vector3.INF
	for i in 240:
		if not is_instance_valid(grenade) or grenade.is_queued_for_deletion():
			break
		exploded_at = grenade.global_position
		await physics_frame
	_check(not is_instance_valid(grenade) or grenade.is_queued_for_deletion(), "Kontaktzünder: Granate explodiert beim Aufprall")
	_check(exploded_at.y < far.y + 0.4, "explodiert am Boden (Höhe %.2f m)" % (exploded_at.y - far.y))

	# 2) Hindernis in der Luft (wie Auto/Wand): explodiert dort, nicht erst am Boden.
	var wall := _dummy(far + Vector3(10, 6, 0), Vector3(0.6, 3, 3))
	listener.log.clear()
	grenade = script.new()
	grenade.set("data", data)
	current_scene.add_child(grenade)
	grenade.global_position = far + Vector3(4, 6, 0)
	grenade.linear_velocity = Vector3(16, 1, 0)
	for i in 120:
		if not is_instance_valid(grenade) or grenade.is_queued_for_deletion():
			break
		exploded_at = grenade.global_position
		await physics_frame
	_check(exploded_at.distance_to(wall.global_position) < 0.8, "explodiert am Hindernis in der Luft")
	_check(wall.hits.size() == 1 and wall.hits[0] > data.damage * 0.85, "Hindernis bekommt fast vollen Schaden (%.0f)" % (wall.hits[0] if wall.hits.size() > 0 else 0.0))
	var heard := false
	for entry in listener.log:
		if entry[0] == &"explosion" and is_equal_approx(entry[1], data.noise_radius):
			heard = true
	_check(heard, "Explosion ist für Gegner hörbar (%.0f m)" % data.noise_radius)
	wall.queue_free()

	# 3) Schaden mit Abfall, Radius und Deckung.
	var center := far + Vector3(-10, 1.0, 0)
	var near := _dummy(center + Vector3(0.6, 0, 0), Vector3(0.4, 0.4, 0.4))
	var mid := _dummy(center + Vector3(0, 0, 3.0), Vector3(0.4, 0.4, 0.4))
	var edge := _dummy(center + Vector3(-5.2, 0, 0), Vector3(0.4, 0.4, 0.4))
	var outside := _dummy(center + Vector3(0, 0, -7.0), Vector3(0.4, 0.4, 0.4))
	var covered := _dummy(center + Vector3(2.5, 0, 2.5), Vector3(0.4, 0.4, 0.4))
	_platform(center + Vector3(1.3, 0, 1.3), Vector3(0.3, 2.5, 0.3)).rotation.y = PI * 0.25
	await _frames(2)
	grenade = script.new()
	grenade.set("data", data)
	current_scene.add_child(grenade)
	grenade.global_position = center
	grenade.freeze = true
	await _frames(1)
	grenade.call("explode")
	await _frames(1)
	var d_near := near.total()
	var d_mid := mid.total()
	var d_edge := edge.total()
	print("    Schaden 0,6 m %.1f · 3 m %.1f · 5,2 m %.1f · 7 m %.1f · hinter Säule %.1f" % [d_near, d_mid, d_edge, outside.total(), covered.total()])
	_check(d_near > d_mid and d_mid > d_edge and d_edge > 0.0, "Schaden fällt nach außen ab")
	# Ziel-Mitte 0,6 m entfernt: Schaden × lerp(1, min_damage_fraction, 0,6 / Radius).
	var expected: float = data.damage * lerpf(1.0, data.min_damage_fraction, 0.6 / data.radius)
	_check(absf(d_near - expected) < 0.5, "Schaden passt zur Formel (%.1f, Soll %.1f)" % [d_near, expected])
	_check(d_edge <= data.damage * 0.25, "am Rand nur noch wenig Schaden (%.0f)" % d_edge)
	_check(outside.hits.is_empty(), "außerhalb des Radius kein Schaden")
	_check(covered.hits.is_empty(), "hinter Deckung kein Schaden")

	# 4) Gegner (Enemy) reagiert: echter Gegner bekommt Schaden bzw. stirbt.
	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn")
	var enemy: CharacterBody3D = enemy_scene.instantiate()
	enemy.set("profile", load("res://scenes/enemies/profiles/gangster_pistol.tres"))
	current_scene.add_child(enemy)
	enemy.global_position = far + Vector3(0, 0.05, 12)
	await _frames(5)
	var hp_before: float = enemy.get("health")
	grenade = script.new()
	grenade.set("data", data)
	current_scene.add_child(grenade)
	grenade.global_position = far + Vector3(0, 1.0, 9)
	grenade.linear_velocity = Vector3(0, 0, 14)
	for i in 120:
		if not is_instance_valid(grenade) or grenade.is_queued_for_deletion():
			break
		await physics_frame
	await _frames(2)
	var hp_after: float = enemy.get("health")
	_check(hp_after < hp_before, "Gegner getroffen: %.0f → %.0f HP" % [hp_before, hp_after])

	# 5) Camera-Shake und Schaden am Werfer, wenn er zu nah steht.
	var shake: Node = _player.get("camera_shake")
	shake.call("reset")
	var stats: Node = _player.get("stats")
	var hp: float = stats.get("hp")
	grenade = script.new()
	grenade.set("data", data)
	grenade.set("thrower", _player)
	current_scene.add_child(grenade)
	grenade.global_position = _player.global_position + Vector3(0, 1.0, -3.0)
	grenade.call("explode")
	await _frames(1)
	_check(float(shake.get("trauma")) > 0.3, "Kamera wackelt bei naher Explosion (Trauma %.2f)" % float(shake.get("trauma")))
	var lost := hp - float(stats.get("hp"))
	_check(lost > 5.0 and lost < data.damage, "Werfer in 3 m nimmt Schaden (%.0f HP)" % lost)
	_check(stats.get("last_damage_cause") == &"grenade", "Todesursache „grenade“ gesetzt")
	print("    Spieler lebt: %s, HP %.0f" % [stats.call("is_alive"), float(stats.get("hp"))])
	stats.call("restore_all")
	await _frames(2)


func _test_throw() -> void:
	print("Wurf mit der Hand")
	var data: Resource = _give(CONTACT, 2)
	await _frames(3)
	_check(_item_user.call("get_held_item") == data, "Kontaktgranate in der Hand")
	var label: Label = _item_user.get("_grenade_label")
	_check(label.visible and label.text.ends_with("×2"), "Anzeige: „%s“" % label.text)
	_player.rotation.y = 0.0
	var held: Node3D = _item_user.call("get_held_view")
	var rest := held.position
	_check(_item_user.call("use_selected"), "Wurf startet")
	# Jedes Bild ansehen: beim Ausholen (vor dem Loslassen) Lage der Hand und Inventar prüfen.
	var wind_seen := false
	var wind_ok := true
	var released := false
	for i in 200:
		await process_frame
		var t := float(_item_user.get("_throw_time"))
		var count := _count_inventory(data)
		if t > 0.0 and t < 0.16 and count == 2:
			wind_seen = true
			wind_ok = wind_ok and held.position.z > rest.z + 0.005 and held.position.y > rest.y + 0.005
		if count == 1:
			released = true
			break
	print("    Wurfzeit beim Loslassen %.3f s" % float(_item_user.get("_throw_time")))
	_check(wind_seen and wind_ok, "Ausholen: Hand geht zurück und hoch, Granate noch in der Hand")
	_check(released and float(_item_user.get("_throw_time")) >= 0.16, "nach dem Ausholen fliegt die Granate")
	await _frames(2)
	_check(label.text.ends_with("×1"), "Anzeige zählt runter: „%s“" % label.text)
	await _seconds(0.8)
	# Letzte Granate: Hand bleibt bis zum Ende des Wurfs.
	_check(_item_user.call("use_selected"), "zweiter Wurf")
	await _seconds(0.2)
	_check(_count_inventory(data) == 0 and _item_user.call("get_held_view") != null, "nach dem Loslassen bleibt die Hand im Wurf")
	await _seconds(0.4)
	_check(_item_user.call("get_held_view") == null and not label.visible, "danach leere Hand, Anzeige aus")
	await _seconds(1.5)


func _test_emp_unchanged() -> void:
	print("EMP-Granate unverändert")
	var data: Resource = load(EMP)
	var script: Script = load(GRENADE_SCRIPT)
	var far := ARENA + Vector3(-150, 0, 0)
	_platform(far + Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	var grenade: RigidBody3D = script.new()
	grenade.set("data", data)
	current_scene.add_child(grenade)
	grenade.global_position = far + Vector3(0, 2, 0)
	await _seconds(0.9)
	_check(is_instance_valid(grenade) and not grenade.is_queued_for_deletion(), "EMP explodiert nicht beim Aufprall")
	await _seconds(1.0)
	_check(not is_instance_valid(grenade) or grenade.is_queued_for_deletion(), "EMP explodiert nach %.1f s Zünder" % data.fuse_time)


func _count_shells() -> int:
	var n := 0
	for child in current_scene.get_children():
		if child is RigidBody3D and child.get_script() == null:
			n += 1
	return n


func _count_inventory(item: Resource) -> int:
	return int(_item_user.call("count_item", item))


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


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
