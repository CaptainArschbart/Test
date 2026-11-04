extends SceneTree
## Prüft Munitionsarten und Platzbedarf (Schedule 1, P4-4) in der Testmap:
##   - jede Schusswaffe hat ihre Munitionsart (Pistole/MP, Gewehr, Schrot, Präzision),
##   - Nachladen nimmt nur, was im Inventar ist; ohne Munition bleibt das Magazin leer, die Anzeige
##     sagt „KEINE MUNITION“; Einzelnachladen hört auf, wenn die Patronen alle sind,
##   - Traglast: Waffen belegen je Klasse Platz (Pistole 1 … Präzision 4), über 10 nimmt das Inventar
##     keine weitere Waffe, Ablegen macht wieder Platz,
##   - Laden: zur gekauften Waffe ein Ersatzmagazin, Munitionspackungen auf der Theke, am Handelspunkt
##     Nachkauf der gewählten Munition (eine gewählte Waffe kauft er weiterhin an),
##   - Gegner lassen Munition ihrer Waffe fallen.
##
## Aufruf (Projektordner), headless reicht:
##   godot --headless --path . -s res://tools/tests/test_ammo.gd
## Letzte Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const TESTMAP := "res://scenes/testmap/testmap.tscn"
const DATA := "res://scenes/items/data/%s.tres"
const SHOP := "res://scenes/crime/street_shop.gd"
const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"
const AMMO_OF := {
	"pistol": "ammo_pistol", "revolver": "ammo_pistol", "heavy_pistol": "ammo_pistol", "smg": "ammo_pistol",
	"compact_smg": "ammo_pistol", "m4": "ammo_rifle", "ak47": "ammo_rifle", "bullpup": "ammo_rifle",
	"pump_shotgun": "ammo_shells", "sawed_off": "ammo_shells", "sniper": "ammo_sniper", "dmr": "ammo_sniper",
}
const ARENA := Vector3(-400.0, 300.0, 400.0)

var _checks := 0
var _fails := 0
var _player: Node3D
var _inv: Node
var _holder: Node


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


func _run() -> void:
	change_scene_to_file(TESTMAP)
	for i in 300:
		if current_scene != null and current_scene.scene_file_path == TESTMAP:
			break
		await physics_frame
	await _frames(20)
	_player = get_first_node_in_group("player") as Node3D
	_inv = _player.get("inventory")
	_holder = _player.get("weapon_holder")
	_test_data()
	await _test_reload()
	await _test_single()
	_test_capacity()
	await _test_shop()
	await _test_drops()
	_finish()


func _clear() -> void:
	for i in int(_inv.call("get_size")):
		_inv.call("_clear", i)
	_inv.emit_signal("changed")


func _test_data() -> void:
	print("Munitionsart je Waffe")
	var wrong := []
	for id: String in AMMO_OF:
		var weapon: Resource = load(DATA % id)
		var ammo: Resource = weapon.get("ammo")
		if ammo == null or str(ammo.get("id")) != AMMO_OF[id]:
			wrong.append(id)
	_check(wrong.is_empty(), "Alle 12 Schusswaffen mit passender Munition %s" % [wrong])
	var stacks := []
	for id: String in ["ammo_pistol", "ammo_rifle", "ammo_shells", "ammo_sniper"]:
		var ammo: Resource = load(DATA % id)
		stacks.append(int(ammo.get("max_stack")))
	_check(stacks.min() >= 40 and str(load(DATA % "ammo_shells").get("model")) == "ammo", "Munition stapelbar mit Schachtel-Modell %s" % [stacks])


func _test_reload() -> void:
	print("Nachladen aus dem Inventar")
	_clear()
	var pistol: Resource = load(DATA % "pistol")
	var ammo: Resource = pistol.get("ammo")
	_inv.call("add_item", pistol, 1)
	_inv.call("select", 1)
	_inv.call("select", 0)
	await _frames(3)
	var ammo_map: Dictionary = _holder.get("_ammo")
	ammo_map["pistol"] = 0
	_check(int(_holder.call("get_reserve")) == 0, "Keine Pistolenmunition im Inventar")
	_holder.call("start_reload")
	_check(not bool(_holder.call("is_reloading")) and int(_holder.call("get_ammo")) == 0, "Ohne Munition kein Nachladen")
	_holder.call("_update_hud")
	var label: Label = _holder.get("_ammo_label")
	_check(label.text.contains("KEINE MUNITION"), "Anzeige: %s" % label.text)
	_inv.call("add_item", ammo, 5)
	_holder.call("start_reload")
	_check(bool(_holder.call("is_reloading")), "Mit Munition lädt er nach")
	_holder.call("_finish_reload")
	_check(int(_holder.call("get_ammo")) == 5 and int(_holder.call("get_reserve")) == 0,
		"Nur 5 da: Magazin 5, Vorrat 0 (%d, %d)" % [int(_holder.call("get_ammo")), int(_holder.call("get_reserve"))])
	_inv.call("add_item", ammo, 30)
	_holder.call("start_reload")
	_holder.call("_finish_reload")
	var mag := int(pistol.get("magazine_size"))
	_check(int(_holder.call("get_ammo")) == mag and int(_holder.call("get_reserve")) == 35 - mag,
		"Voll nachgeladen: %d im Magazin, %d übrig" % [int(_holder.call("get_ammo")), int(_holder.call("get_reserve"))])
	_holder.call("_update_hud")
	_check(label.text.contains("%d" % (35 - mag)), "Anzeige mit Vorrat: %s" % label.text)


func _test_single() -> void:
	print("Einzelnachladen (Pumpgun)")
	_clear()
	var pump: Resource = load(DATA % "pump_shotgun")
	_inv.call("add_item", pump, 1)
	_inv.call("add_item", pump.get("ammo"), 2)
	_inv.call("select", 1)
	_inv.call("select", 0)
	await _frames(3)
	var ammo_map: Dictionary = _holder.get("_ammo")
	ammo_map["pump_shotgun"] = 0
	_holder.call("start_reload")
	for i in 4:
		if bool(_holder.call("is_reloading")):
			_holder.call("_finish_reload")
	_check(int(_holder.call("get_ammo")) == 2 and not bool(_holder.call("is_reloading")),
		"Zwei Patronen da: zwei geladen, dann Schluss (%d)" % int(_holder.call("get_ammo")))


func _test_capacity() -> void:
	print("Traglast")
	_clear()
	var cap := int(_inv.get("WEAPON_CAPACITY"))
	_check(cap == 10, "Traglast 10")
	var sniper: Resource = load(DATA % "sniper")
	var rifle: Resource = load(DATA % "m4")
	var pistol: Resource = load(DATA % "pistol")
	_check(int(sniper.call("carry_size")) == 4 and int(rifle.call("carry_size")) == 3 and int(pistol.call("carry_size")) == 1,
		"Platzbedarf: Präzision 4, Gewehr 3, Pistole 1")
	_inv.call("add_item", sniper, 1)
	_inv.call("add_item", rifle, 1)
	_inv.call("add_item", rifle, 1)
	_check(int(_inv.call("weapon_load")) == 10, "Präzision + 2 Gewehre = 10 (%d)" % int(_inv.call("weapon_load")))
	var left := int(_inv.call("add_item", pistol, 1))
	_check(left == 1 and int(_inv.call("space_for", pistol)) == 0, "Keine weitere Waffe, auch keine Pistole")
	_check(str(_inv.call("full_message", pistol)).contains("Traglast"), "Meldung: %s" % _inv.call("full_message", pistol))
	_check(int(_inv.call("add_item", load(DATA % "ammo_rifle"), 30)) == 0, "Munition passt trotzdem")
	_inv.call("remove_item", rifle, 1)
	_check(int(_inv.call("add_item", pistol, 1)) == 0 and int(_inv.call("weapon_load")) == 8, "Nach dem Ablegen passt die Pistole")


func _test_shop() -> void:
	print("Laden")
	_clear()
	var shop_script: GDScript = load(SHOP)
	var counter: Node3D = shop_script.SaleCounter.new()
	counter.set("item", load(DATA % "pistol"))
	counter.set("price", 40)
	current_scene.add_child(counter)
	_inv.set("money", 500)
	counter.call("interact", _player)
	var pistol: Resource = load(DATA % "pistol")
	var ammo: Resource = pistol.get("ammo")
	_check(int(_inv.call("count_item", pistol)) == 1 and int(_inv.call("count_item", ammo)) == int(pistol.get("magazine_size")),
		"Pistole gekauft, dazu ein Ersatzmagazin (%d)" % int(_inv.call("count_item", ammo)))
	# Packung auf der Theke.
	var packs: Dictionary = shop_script.get_script_constant_map()["AMMO_PACKS"]
	var box: Node3D = shop_script.SaleCounter.new()
	box.set("item", ammo)
	box.set("price", 48)
	box.set("count", int(packs[ammo.resource_path]))
	current_scene.add_child(box)
	var had := int(_inv.call("count_item", ammo))
	var text_box := str(box.call("get_interact_text", _player))
	box.call("interact", _player)
	_check(int(_inv.call("count_item", ammo)) == had + int(packs[ammo.resource_path]) and text_box.contains("×"),
		"Packung gekauft: %s" % text_box)
	# Handelspunkt: gewählte Munition nachkaufen.
	var clerk: Node3D = shop_script.GunClerk.new()
	current_scene.add_child(clerk)
	var slot := -1
	for i in 9:
		if _inv.call("get_item", i) == ammo:
			slot = i
	_inv.call("select", slot)
	await _frames(2)
	var before := int(_inv.get("money"))
	had = int(_inv.call("count_item", ammo))
	var text := str(clerk.call("get_interact_text", _player))
	clerk.call("interact", _player)
	_check(text.contains("nachkaufen") and int(_inv.call("count_item", ammo)) > had, "Handelspunkt: %s" % text)
	_check(int(_inv.get("money")) < before, "Munition kostet (%d ¢)" % (before - int(_inv.get("money"))))
	counter.queue_free()
	box.queue_free()
	clerk.queue_free()
	await _frames(2)


func _test_drops() -> void:
	print("Beute")
	_clear()
	var before := _pickups_of("ammo_pistol")
	for i in 6:
		var enemy: Node3D = load(ENEMY_SCENE).instantiate()
		enemy.set("profile", load("res://scenes/enemies/profiles/gangster_pistol.tres"))
		current_scene.add_child(enemy)
		enemy.global_position = ARENA + Vector3(i * 2.0, 0.1, -6)
		await _frames(2)
		enemy.call("_drop_loot")
		enemy.queue_free()
	await _frames(3)
	_check(_pickups_of("ammo_pistol") > before, "Pistolen-Gangster lassen Pistolenmunition fallen (%d)" % (_pickups_of("ammo_pistol") - before))


func _pickups_of(id: String) -> int:
	var n := 0
	for node in current_scene.find_children("*", "Node3D", true, false):
		var item: Variant = node.get("item")
		if item is Resource and str((item as Resource).get("id")) == id and node.has_method("set_count"):
			n += 1
	return n


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
