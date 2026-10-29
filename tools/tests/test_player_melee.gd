extends SceneTree
## Prüft Boxen und aufgeladenen Dash-Schlag (PlayerMelee) in einer kleinen Arena aus dem Code:
## Boden, Wand, erhöhte Plattform mit Kante, Trefferpuppe und echte Gegner (enemy.tscn).
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_player_melee.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne die Klassennamen Player/Enemy/PlayerMelee (ein -s-Skript wird vor den Autoloads kompiliert).

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"
const PISTOL := "res://scenes/items/data/pistol.tres"
const DUMMY_SOURCE := """extends StaticBody3D
var hits: Array = []
func take_hit(damage: float, _point: Vector3, _normal: Vector3) -> void:
	hits.append(damage)
"""
## Zustände aus PlayerMelee.State und Enemy.State.
const IDLE := 0
const JAB := 1
const CHARGE := 2
const DASH := 3
const POWER := 4
const ENEMY_COMBAT := 3
const ENEMY_STUNNED := 6
const ENEMY_DEAD := 7

var _checks := 0
var _fails := 0
var _root: Node3D
var _player: CharacterBody3D
var _melee: Node
var _tuning: Resource


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _wait_frames(n: int) -> void:
	for i in n:
		await physics_frame


## Wartet, bis der Hitstop vorbei ist (läuft in Echtzeit).
func _wait_hitstop() -> void:
	for i in 2000:
		if Engine.time_scale >= 1.0:
			return
		await process_frame


func _box(size: Vector3, center: Vector3, body: StaticBody3D = null) -> StaticBody3D:
	if body == null:
		body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	body.add_child(mesh)
	_root.add_child(body)
	body.global_position = center
	return body


func _place(pos: Vector3, yaw := 0.0) -> void:
	_melee.call("cancel")
	_melee.set("_power_cooldown", 0.0)
	_melee.set("_cooldown", 0.0)
	_player.global_position = pos
	_player.rotation = Vector3(0.0, yaw, 0.0)
	(_player.get("head") as Node3D).rotation = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	await _wait_frames(12)


## Taste halten für `frames` Physik-Frames, dann loslassen.
func _charge(frames: int) -> void:
	_melee.call("press", &"melee")
	Input.action_press("melee")
	await _wait_frames(frames)
	Input.action_release("melee")
	await _wait_frames(1)


func _wait_state(wanted: int, limit := 120) -> void:
	for i in limit:
		if _melee.get("state") == wanted:
			return
		await physics_frame


func _run() -> void:
	_root = Node3D.new()
	_root.name = "MeleeArena"
	root.add_child(_root)
	current_scene = _root
	var sun := DirectionalLight3D.new()
	_root.add_child(sun)
	_box(Vector3(80.0, 1.0, 80.0), Vector3(0.0, -0.5, 0.0))
	_box(Vector3(6.0, 4.0, 0.5), Vector3(0.0, 2.0, -12.0))
	_box(Vector3(6.0, 2.0, 6.0), Vector3(20.0, 1.0, 0.0))
	var dummy_script := GDScript.new()
	dummy_script.source_code = DUMMY_SOURCE
	dummy_script.reload()
	var dummy := StaticBody3D.new()
	dummy.set_script(dummy_script)
	dummy.name = "Dummy"
	_box(Vector3(0.6, 1.8, 0.6), Vector3(-20.0, 0.9, -5.0), dummy)
	var dash_dummy := StaticBody3D.new()
	dash_dummy.set_script(dummy_script)
	dash_dummy.name = "DashDummy"
	_box(Vector3(0.6, 1.8, 0.6), Vector3(-30.0, 0.9, -5.0), dash_dummy)

	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	# Nicht "Player" nennen: der NetworkManager würde eine feste Figur namens Player ersetzen.
	_player.name = "TestPlayer"
	_root.add_child(_player)
	_player.global_position = Vector3(0.0, 0.0, 20.0)
	await _wait_frames(5)
	(_player.get("stats") as Node).set("invulnerable", true)
	_melee = _player.get("melee")
	_check(_melee != null, "Player legt PlayerMelee an")
	if _melee == null:
		_finish()
		return
	_tuning = _melee.get("tuning")

	# --- Eingabe ---
	var events := InputMap.action_get_events("melee")
	var key := 0
	for event in events:
		if event is InputEventKey:
			key = event.physical_keycode
	_check(key == KEY_F, "Aktion melee liegt auf F")
	var settings: Node = root.get_node("Settings")
	var rebindable: Dictionary = settings.get("REBINDABLE_ACTIONS")
	_check(rebindable.has("melee"), "melee ist im Optionsmenü belegbar")
	var clash := []
	for action: String in rebindable:
		if action != "melee" and settings.call("_read_binding", action) == KEY_F:
			clash.append(action)
	_check(clash.is_empty(), "F kollidiert mit keiner anderen Taste %s" % [clash])

	# --- Boxen: Treffer und Kombo ---
	await _place(Vector3(-20.0, 0.0, -3.6))
	var hits: Array = dummy.get("hits")
	var sides := []
	_melee.connect("punched", func(side: int, _target: Node) -> void: sides.append(side))
	_melee.call("press", &"fire")
	_check(_melee.get("state") == JAB, "Linksklick ohne Waffe schlägt")
	await _wait_frames(8)
	await _wait_hitstop()
	_check(hits.size() == 1 and is_equal_approx(hits[0], _tuning.get("jab_damage")),
		"Faust trifft die Puppe (%s)" % [hits])
	_check(Engine.time_scale == 1.0, "Hitstop endet wieder")
	_check(_melee.call("get_guard_weight") > 0.5, "Hände gehen in die Deckung")
	await _wait_frames(12)
	_melee.call("press", &"fire")
	await _wait_frames(8)
	await _wait_hitstop()
	await _wait_frames(12)
	_melee.call("press", &"fire")
	await _wait_frames(8)
	await _wait_hitstop()
	_check(sides == [-1, 1, -1], "Fäuste wechseln sich ab: links, rechts, links (%s)" % [sides])
	_check(hits.size() == 3 and is_equal_approx(hits[2], _tuning.get("jab_damage") * _tuning.get("hook_multiplier")),
		"dritter Schlag ist ein Haken mit mehr Schaden (%s)" % [hits])
	await _wait_frames(60)
	_melee.call("press", &"fire")
	await _wait_frames(30)
	_check(sides.size() == 4 and sides[3] == -1, "nach der Pause beginnt die Kombo neu mit links")
	await _place(Vector3(-20.0, 0.0, -1.0))
	var before := hits.size()
	_melee.call("press", &"melee")
	await _wait_frames(30)
	_check(hits.size() == before, "zu weit weg (3,7 m): kein Treffer")

	# --- Aufladen ---
	await _place(Vector3(-15.0, 0.0, 15.0))
	_melee.call("press", &"melee")
	Input.action_press("melee")
	await _wait_frames(40)
	_check(_melee.get("state") == CHARGE, "Halten lädt auf")
	_check(is_equal_approx(_melee.call("get_move_factor"), _tuning.get("charge_move_factor")), "Aufladen bremst das Laufen")
	var glow := _player.find_child("ChargeGlow", true, false) as Node3D
	_check(glow != null and glow.visible, "Faust leuchtet beim Aufladen")
	var bar: Control = _melee.get("_bar_root")
	_check(bar != null and bar.visible, "Ladebalken unter dem Fadenkreuz")
	await _wait_frames(40)
	_check(_melee.get("charge") >= 0.99, "nach charge_delay + charge_time voll (%.2f)" % _melee.get("charge"))
	Input.action_release("melee")
	await _wait_frames(1)
	_check(_melee.get("state") == DASH, "Loslassen startet den Dash")
	await _wait_frames(4)
	_check(_melee.call("get_fov_offset") > 3.0, "Sichtfeld-Kick beim Dash (%.1f°)" % _melee.call("get_fov_offset"))
	await _wait_state(POWER)
	var dist: float = _melee.get("last_dash_distance")
	_check(_melee.get("last_dash_reason") == &"distance" and absf(dist - _tuning.get("dash_distance")) < 0.4,
		"voller Dash im Freien: %s, %.2f m" % [_melee.get("last_dash_reason"), dist])
	await _wait_frames(40)
	_check(_melee.get("state") == IDLE and absf(_melee.call("get_fov_offset")) < 0.5, "danach zurück in Ruhe, Sichtfeld normal")

	# Kurz gehalten: Unter charge_min passiert nichts.
	await _place(Vector3(-15.0, 0.0, 15.0))
	var start := _player.global_position
	await _charge(int((_tuning.get("charge_delay") + 0.1) * 60.0))
	await _wait_frames(30)
	_check(_melee.get("state") == IDLE and start.distance_to(_player.global_position) < 0.3,
		"zu kurz aufgeladen: kein Dash")

	# Pause zwischen zwei Powerschlägen.
	await _place(Vector3(-15.0, 0.0, 15.0))
	await _charge(70)
	await _wait_state(IDLE)
	await _wait_frames(10)
	_melee.call("press", &"melee")
	Input.action_press("melee")
	await _wait_frames(25)
	_check(_melee.get("state") != CHARGE, "Cooldown: direkt danach kein neues Aufladen")
	Input.action_release("melee")
	await _wait_frames(5)

	# --- Dash-Abbrüche ---
	await _place(Vector3(0.0, 0.0, -9.5))
	await _charge(70)
	await _wait_state(POWER)
	var z := _player.global_position.z
	_check(_melee.get("last_dash_reason") == &"wall" and z > -11.8 and z < -10.5,
		"Dash stoppt an der Wand (%s, z %.2f, Wand bei -11,75)" % [_melee.get("last_dash_reason"), z])

	await _place(Vector3(20.0, 2.0, 0.5))
	await _charge(70)
	await _wait_state(POWER)
	await _wait_frames(30)
	var p := _player.global_position
	_check(_melee.get("last_dash_reason") == &"edge" and p.y > 1.9 and p.z > -3.0,
		"Dash stoppt vor der Kante, bleibt oben (%s, y %.2f, z %.2f, Kante bei -3)" % [_melee.get("last_dash_reason"), p.y, p.z])

	await _place(Vector3(-15.0, 0.0, 15.0))
	_melee.call("press", &"melee")
	Input.action_press("melee")
	await _wait_frames(70)
	_player.velocity.y = 4.5
	_player.global_position.y += 0.3
	await _wait_frames(3)
	Input.action_release("melee")
	await _wait_frames(2)
	_check(_melee.get("last_dash_reason") == &"no_dash" and _melee.get("state") == POWER,
		"in der Luft: Schlag ohne Dash")
	await _wait_frames(60)

	await _place(Vector3(-30.0, 0.0, -0.5))
	var dash_hits: Array = dash_dummy.get("hits")
	await _charge(70)
	await _wait_state(POWER)
	await _wait_hitstop()
	_check(_melee.get("last_dash_reason") == &"enemy", "Dash bricht vor dem Ziel ab (%s)" % _melee.get("last_dash_reason"))
	_check(dash_hits.size() == 1 and dash_hits[0] >= _tuning.get("power_damage") * 0.99,
		"Powerschlag trifft sofort mit vollem Schaden (%s)" % [dash_hits])
	_check(_player.global_position.z > -4.6, "nicht in das Ziel hineingedasht (z %.2f)" % _player.global_position.z)
	await _wait_frames(60)

	# --- Mit Waffe ---
	var inventory: Node = _player.get("inventory")
	inventory.call("add_item", load(PISTOL), 1, false)
	inventory.call("select", 0)
	await _wait_frames(5)
	var holder: Node = _player.get("weapon_holder")
	_check(holder.call("get_weapon") != null, "Pistole in der Hand")
	_check(not _melee.call("hands_free"), "mit Waffe ist Linksklick kein Faustschlag")
	await _place(Vector3(-20.0, 0.0, -3.6))
	before = hits.size()
	_melee.call("press", &"melee")
	await _wait_frames(3)
	var view: Node3D = null
	for child in holder.get_children():
		if child is Node3D:
			view = child
	_check(_melee.call("is_holstering") and view != null and not view.visible, "F mit Waffe: Waffe weggesteckt")
	await _wait_frames(8)
	await _wait_hitstop()
	_check(hits.size() == before + 1, "Schlag mit weggesteckter Waffe trifft")
	await _wait_frames(120)
	_check(not _melee.call("is_holstering") and view.visible, "Waffe kommt danach zurück")
	inventory.call("remove_at", 0, 1)
	await _wait_frames(5)

	# --- Echte Gegner ---
	var enemy_scene := load(ENEMY_SCENE) as PackedScene
	var thug: CharacterBody3D = enemy_scene.instantiate()
	_root.add_child(thug)
	thug.global_position = Vector3(10.0, 0.0, -5.0)
	var brute: CharacterBody3D = enemy_scene.instantiate()
	_root.add_child(brute)
	brute.global_position = Vector3(10.0, 0.0, 15.0)
	var bystander: CharacterBody3D = enemy_scene.instantiate()
	_root.add_child(bystander)
	bystander.global_position = Vector3(11.6, 0.0, 15.3)
	await _wait_frames(10)
	await _place(Vector3(10.0, 0.0, -3.6))
	thug.global_position = Vector3(10.0, 0.0, -5.0)
	var hp_before: float = thug.get("health")
	var thug_start := thug.global_position
	_melee.call("press", &"melee")
	await _wait_frames(8)
	await _wait_hitstop()
	await _wait_frames(10)
	_check(thug.get("health") < hp_before, "Gegner nimmt Faustschaden (%.0f -> %.0f)" % [hp_before, thug.get("health")])
	_check(thug.get("state") == ENEMY_COMBAT or thug.get("state") == ENEMY_STUNNED,
		"Gegner reagiert (Kampf oder niedergeschlagen, Zustand %d)" % thug.get("state"))
	var knocked := Vector2(thug.global_position.x - thug_start.x, thug.global_position.z - thug_start.z)
	_check(knocked.y < -0.1, "Rückstoß schiebt ihn weg (%.2f m)" % -knocked.y)

	await _place(Vector3(10.0, 0.0, 20.0))
	# Viel Leben, damit der Schlag nicht tötet und die Betäubung zu sehen ist; schon im Kampf (kein Hinterhalt).
	brute.set("health", 300.0)
	brute.call("_enter_combat", false)
	_melee.call("press", &"melee")
	Input.action_press("melee")
	await _wait_frames(70)
	# Erst kurz vor dem Loslassen hinstellen: im Kampf laufen die Gegner sonst in Deckung.
	brute.global_position = Vector3(10.0, 0.0, 16.5)
	bystander.global_position = Vector3(11.5, 0.0, 16.3)
	hp_before = brute.get("health")
	var other_hp: float = bystander.get("health")
	await _wait_frames(1)
	Input.action_release("melee")
	await _wait_state(POWER)
	await _wait_hitstop()
	await _wait_frames(2)
	_check(_melee.get("last_dash_reason") == &"enemy", "Dash auf Gegner bricht ab und schlägt (%s, %.2f m)" % [_melee.get("last_dash_reason"), _melee.get("last_dash_distance")])
	_check(brute.get("health") < hp_before - 40.0, "Powerschlag macht schweren Schaden (%.0f -> %.0f)" % [hp_before, brute.get("health")])
	_check(brute.get("state") == ENEMY_STUNNED, "Gegner ist betäubt (Zustand %d)" % brute.get("state"))
	_check(bystander.get("health") < other_hp, "Schockwelle trifft den Nebenmann (%.0f -> %.0f)" % [other_hp, bystander.get("health")])

	# --- Abbruch ---
	await _place(Vector3(-15.0, 0.0, 15.0))
	_melee.call("press", &"melee")
	Input.action_press("melee")
	await _wait_frames(50)
	_player.call("set_noclip", true)
	await _wait_frames(2)
	_check(_melee.get("state") == IDLE, "Noclip bricht das Aufladen ab")
	Input.action_release("melee")
	_player.call("set_noclip", false)
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
