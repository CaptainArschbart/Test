extends SceneTree
## NPC berauben (CivilianCrime): Taschendiebstahl gelingt im Dunkeln ohne Fahndung, fliegt bei hoher
## Wachsamkeit auf, bricht ab, wenn man vor die Person geht, gehende Personen bleiben beim Griff stehen.
## Bewaffneter Raub: Ziel halten, Tasche
## kommt, loslassen gibt eine Stufe mehr. Nach dem Raub gefesselt: keine Meldung mehr.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_npc_robbery.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne typisierte Verweise auf Spielklassen (ein -s-Skript wird vor den Autoloads kompiliert).

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const CIVILIAN := "res://scenes/civilians/civilian.gd"
const PISTOL := "res://scenes/items/data/pistol.tres"
const ZIPTIES := "res://scenes/items/data/zipties.tres"

var _checks := 0
var _fails := 0
var _root: Node3D
var _player: CharacterBody3D
var _inventory: Node
var _wanted: Node


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


func _box(size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_root.add_child(body)
	body.global_position = center


func _civilian(pos: Vector3, seed_value: int) -> CharacterBody3D:
	var civ := (load(CIVILIAN) as GDScript).new() as CharacterBody3D
	civ.set("stay_put", true)
	civ.set("net_seed", seed_value)
	_root.add_child(civ)
	civ.global_position = pos
	civ.rotation.y = 0.0
	return civ


## Spieler hinstellen. yaw 0 = Blick nach -Z.
func _place(pos: Vector3, yaw: float, crouch: bool) -> void:
	_player.global_position = pos
	_player.rotation.y = yaw
	_player.velocity = Vector3.ZERO
	if crouch:
		Input.action_press("crouch")
	else:
		Input.action_release("crouch")
	await _frames(12)


func _crime(civ: Node) -> Node:
	return civ.get_node("CivilianCrime")


func _prompt(civ: Node) -> String:
	return str(civ.call("get_interact_text", _player))


func _run() -> void:
	_root = Node3D.new()
	_root.name = "RobberyArena"
	root.add_child(_root)
	current_scene = _root
	_box(Vector3(200.0, 1.0, 200.0), Vector3(0.0, -0.5, 0.0))
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_player.name = "TestPlayer"
	_root.add_child(_player)
	await _frames(10)
	# Hocken per gehaltener Taste. Spieler weg vom ersten Passanten.
	_player.get("movement").set("crouch_hold", true)
	_player.global_position = Vector3(0, 0, -80)
	await _frames(4)
	_inventory = _player.get("inventory")
	_wanted = root.get_node("WantedManager")
	_wanted.call("set_stars", 0)
	await _pickpocket_ok()
	await _pickpocket_caught()
	await _pickpocket_abort()
	await _pickpocket_walking()
	await _armed_robbery()
	await _armed_then_tied()
	_wanted.call("set_stars", 0)
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(_fails)


func _pickpocket_ok() -> void:
	# Seed 0: 2 ¢, Schmuck dabei.
	var civ := _civilian(Vector3(0, 0, 0), 0)
	await _frames(4)
	var crime := _crime(civ)
	await _place(Vector3(0, 0, 1.2), 0.0, false)
	_check(_prompt(civ) == "", "stehend hinter der Person: kein Taschendiebstahl")
	await _place(Vector3(0, 0, 1.2), 0.0, true)
	_check(_prompt(civ) == "Taschendiebstahl", "hockend dahinter: Taschendiebstahl (%s)" % _prompt(civ))
	var money := int(_inventory.get("money"))
	civ.call("interact", _player)
	await _frames(20)
	_check(_prompt(civ).begins_with("Klauen"), "Griff läuft, Anzeige: %s" % _prompt(civ))
	await _frames(90)
	_check(float(crime.get("pick_progress")) < 0.0, "Griff fertig")
	_check(int(_inventory.get("money")) == money + 2, "2 ¢ geklaut (%d → %d)" % [money, int(_inventory.get("money"))])
	_check(int(_player.get("item_user").call("count_item", load("res://scenes/items/data/jewelry.tres"))) == 1, "Schmuck mitgenommen")
	_check(int(_wanted.call("star_count")) == 0, "unbemerkt: keine Fahndung (Verdacht %.2f)" % float(crime.get("suspicion")))
	_check(_prompt(civ) == "", "Tasche leer: kein zweiter Diebstahl")
	civ.queue_free()


func _pickpocket_caught() -> void:
	var civ := _civilian(Vector3(40, 0, 0), 5)
	await _frames(4)
	var crime := _crime(civ)
	await _place(Vector3(40, 0, 1.2), 0.0, true)
	var money := int(_inventory.get("money"))
	civ.call("interact", _player)
	crime.set("_alert", 12.0)
	await _frames(60)
	_check(float(crime.get("pick_progress")) < 0.0, "Griff beendet")
	_check(int(_inventory.get("money")) == money, "erwischt: kein Geld")
	_check(bool(civ.call("is_panicking")), "Person rennt weg")
	_check(int(_wanted.call("star_count")) == 1, "erwischt: eine Fahndungsstufe (%d)" % int(_wanted.call("star_count")))
	_wanted.call("set_stars", 0)
	civ.queue_free()


## Gehende Person: bleibt während des Griffs stehen und läuft danach weiter.
func _pickpocket_walking() -> void:
	var civ := _civilian(Vector3(-40, 0, 40), 12)
	civ.set("stay_put", false)
	await _frames(4)
	var crime := _crime(civ)
	await _place(Vector3(-40, 0, 41.2), 0.0, true)
	civ.call("_plan_path", Vector3(-40, 0, 20))
	civ.set("state", 0)
	var before: Vector3 = civ.global_position
	await _frames(6)
	_check(civ.global_position.distance_to(before) > 0.05, "Person geht vor dem Griff (%.2f m)" % civ.global_position.distance_to(before))
	var money := int(_inventory.get("money"))
	civ.call("interact", _player)
	var start: Vector3 = civ.global_position
	await _frames(40)
	var moved := Vector2(civ.global_position.x - start.x, civ.global_position.z - start.z).length()
	_check(float(crime.get("pick_progress")) >= 0.0 and moved < 0.2, "gehende Person bleibt beim Griff stehen (%.2f m)" % moved)
	await _frames(60)
	_check(int(_inventory.get("money")) > money, "Griff an gehender Person gelingt (%d → %d)" % [money, int(_inventory.get("money"))])
	var after: Vector3 = civ.global_position
	await _frames(40)
	_check(civ.global_position.distance_to(after) > 0.3, "danach geht sie weiter")
	civ.queue_free()


func _pickpocket_abort() -> void:
	var civ := _civilian(Vector3(-40, 0, 0), 9)
	await _frames(4)
	var crime := _crime(civ)
	await _place(Vector3(-40, 0, 1.2), 0.0, true)
	var money := int(_inventory.get("money"))
	civ.call("interact", _player)
	await _frames(15)
	await _place(Vector3(-40, 0, -1.2), PI, true)
	_check(float(crime.get("pick_progress")) < 0.0, "vor die Person gegangen: abgebrochen")
	_check(int(_inventory.get("money")) == money, "abgebrochen: kein Geld")
	_check(int(_wanted.call("star_count")) == 0, "abgebrochen: keine Fahndung")
	civ.queue_free()


func _aim(on: bool) -> void:
	if on:
		Input.action_press("aim")
	else:
		Input.action_release("aim")
	await _frames(45)


func _armed_robbery() -> void:
	_inventory.call("add_item", load(PISTOL), 1, false)
	_inventory.call("select", _slot_of("pistol"))
	await _frames(5)
	_check(_player.get("weapon_holder").call("get_weapon") != null, "Pistole in der Hand")
	# Seed 3: 5 ¢ und Schmuck.
	var civ := _civilian(Vector3(0, 0, 40), 3)
	await _frames(4)
	var crime := _crime(civ)
	await _place(Vector3(0, 0, 36), PI, false)
	_check(_prompt(civ) == "", "ohne Zielen nichts")
	await _aim(true)
	_check(bool(crime.get("held_up")), "angezielt: Hände hoch")
	_check(int(_wanted.call("star_count")) == 1, "Bedrohung: eine Stufe")
	_check(_prompt(civ) == "Ausrauben (bedroht)", "Anzeige: %s" % _prompt(civ))
	var money := int(_inventory.get("money"))
	civ.call("interact", _player)
	await _frames(30)
	_check(_prompt(civ).begins_with("Tasche her!"), "Übergabe läuft: %s" % _prompt(civ))
	await _frames(90)
	_check(int(_inventory.get("money")) == money + 5, "5 ¢ geraubt (%d → %d)" % [money, int(_inventory.get("money"))])
	_check(_prompt(civ) == "", "nach dem Raub kein zweites Ausrauben ohne Fesseln")
	await _aim(false)
	_check(not bool(crime.get("held_up")), "Waffe runter: Hände unten")
	_check(int(_wanted.call("star_count")) == 2, "freigelassen: Polizei gerufen, zwei Stufen (%d)" % int(_wanted.call("star_count")))
	_check(bool(civ.call("is_panicking")), "Person rennt weg")
	_wanted.call("set_stars", 0)
	civ.queue_free()
	await _frames(4)


func _armed_then_tied() -> void:
	_inventory.call("add_item", load(ZIPTIES), 1, false)
	_inventory.call("select", _slot_of("pistol"))
	var civ := _civilian(Vector3(40, 0, 40), 6)
	await _frames(4)
	var crime := _crime(civ)
	await _place(Vector3(40, 0, 36), PI, false)
	await _aim(true)
	civ.call("interact", _player)
	await _frames(120)
	_check(bool(crime.get("_armed_robbed")), "zweiter Raub fertig")
	_check(_prompt(civ) == "Fesseln", "danach: Fesseln (%s)" % _prompt(civ))
	civ.call("interact", _player)
	_check(bool(crime.get("restrained")), "gefesselt")
	var stars := int(_wanted.call("star_count"))
	await _aim(false)
	await _frames(30)
	_check(int(_wanted.call("star_count")) == stars, "gefesselt: keine weitere Meldung (%d)" % int(_wanted.call("star_count")))
	_wanted.call("set_stars", 0)
	civ.queue_free()


func _slot_of(id: String) -> int:
	for i in int(_inventory.call("get_size")):
		var item: Resource = _inventory.call("get_item", i)
		if item != null and str(item.get("id")) == id:
			return i
	return -1
