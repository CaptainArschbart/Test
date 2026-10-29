extends SceneTree
## Prüft Verbrauchsitems mit Modell und Benutz-Animation (ConsumableModel, ConsumableUse, ItemUser).
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_consumables.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne typisierte Verweise auf Spielklassen (siehe test_sector7_enemies.gd: -s-Skripte werden vor
## den Autoloads kompiliert).

const TESTMAP := "res://scenes/testmap/testmap.tscn"
const ITEMS := {
	"stim_pack": [&"injector", &"inject"],
	"energy_drink": [&"can", &"drink"],
	"noodles": [&"noodles", &"eat"],
	"nano_bandage": [&"bandage", &"bandage"],
}

var _checks := 0
var _fails := 0
var _player: Node
var _inventory: Node
var _stats: Node
var _item_user: Node3D
var _use: Node
var _hands: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Wartet, bis die Animation-Zeit `seconds` erreicht ist (oder die Animation vorbei ist).
func _until_time(seconds: float) -> void:
	for i in 3000:
		if not _use.call("is_active") or float(_use.get("_time")) >= seconds:
			return
		await process_frame


func _until_idle() -> void:
	for i in 4000:
		if not _use.call("is_active"):
			return
		await process_frame


func _item(id: String) -> Resource:
	return load("res://scenes/items/data/%s.tres" % id)


## Legt `count` Stück in einen leeren Slot und wählt ihn. Gibt den Slot zurück.
func _give(id: String, count: int) -> int:
	for i in 9:
		_inventory.call("remove_at", i, 999)
	_inventory.call("add_item", _item(id), count)
	_inventory.call("select", 0)
	return 0


func _count() -> int:
	return int(_inventory.call("get_count", 0))


func _run() -> void:
	change_scene_to_file(TESTMAP)
	await _frames(20)
	_player = get_first_node_in_group("player")
	_check(_player != null, "Testmap mit Spielerfigur geladen")
	if _player == null:
		_finish()
		return
	_inventory = _player.get("inventory")
	_stats = _player.get("stats")
	_item_user = _player.get("item_user")
	_hands = _player.get("hands")
	_use = _item_user.call("get_consumable_use")
	_check(_use != null, "ItemUser hat ConsumableUse")
	_stats.set("hunger_drain_rate", 0.0)
	_stats.set("thirst_drain_rate", 0.0)

	await _check_data_and_models()
	await _check_stim_completes()
	await _check_cancel_by_switch()
	await _check_cancel_by_damage()
	await _check_cancel_by_sprint()
	await _check_drink_boost_at_end()
	await _check_hunger_does_not_cancel()
	await _check_bandage_and_last_item()
	_finish()


func _check_data_and_models() -> void:
	var cls: GDScript = load("res://scenes/items/consumable_model.gd")
	for id: String in ITEMS:
		var item := _item(id)
		_check(item.get("model") == ITEMS[id][0] and item.get("use_animation") == ITEMS[id][1],
			"%s: Modell %s, Animation %s" % [id, ITEMS[id][0], ITEMS[id][1]])
		var model: Node3D = cls.call("build", item.get("model"), item.get("color"), true)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		_check(meshes.size() >= 6, "%s: Modell aus %d Teilen" % [id, meshes.size()])
		model.free()
		# Pickup in der Welt zeigt das Modell statt des Würfels.
		var pickup: Node3D = load("res://scenes/items/pickup.tscn").instantiate()
		pickup.set("item", item)
		current_scene.add_child(pickup)
		await _frames(2)
		var shown := pickup.get_node_or_null("Visual/ConsumableModel")
		_check(shown != null and not (pickup.get_node("Visual/Mesh") as Node3D).visible,
			"%s: Pickup zeigt das Modell" % id)
		pickup.queue_free()
	# Bestehende Werte unverändert.
	_check(is_equal_approx(_item("stim_pack").get("heal"), 45.0), "Stim heilt weiter 45")
	_check(is_equal_approx(_item("energy_drink").get("water"), 30.0)
		and is_equal_approx(_item("energy_drink").get("speed_multiplier"), 1.3), "NeoCola-Werte unverändert")
	_check(is_equal_approx(_item("noodles").get("food"), 45.0), "Nudeln-Werte unverändert")


func _check_stim_completes() -> void:
	_give("stim_pack", 2)
	await _frames(5)
	var held: Node3D = _item_user.call("get_held_view")
	_check(held != null and held.name.begins_with("Consumable_"), "Stim liegt in der Hand")
	# Stehen ohne Bewegung: die Hände bleiben, weil etwas in der Hand liegt.
	await _frames(150)
	_check(float(_hands.call("get_hide_amount")) < 0.01, "Hände mit Item in der Hand nicht ausgeblendet")
	_stats.call("damage", 50.0)
	await _frames(2)
	var hp_before: float = _stats.get("hp")
	_check(bool(_item_user.call("use_selected")), "Rechtsklick startet die Animation")
	_check(bool(_use.call("is_active")), "Animation läuft")
	_check(not bool(_item_user.call("use_selected")), "Zweiter Klick während der Animation startet nichts")
	var use_end: float = _use.get("_use_end")
	_check(use_end > 1.0 and use_end < 2.0, "Stim: Effekt nach %.2f s" % use_end)
	await _until_time(use_end * 0.6)
	_check(is_equal_approx(_stats.get("hp"), hp_before) and _count() == 2,
		"Mitte der Animation: noch kein Effekt, nichts verbraucht")
	_check(float(_hands.call("get_hide_amount")) < 0.01, "Hände während der Animation sichtbar")
	var left: Dictionary = _item_user.call("get_left_hand_target")
	_check(not left.is_empty(), "linke Hand bekommt ein Ziel (Arm hinhalten)")
	var view: Node3D = _item_user.call("get_held_view")
	_check(view != null and view.name == "UseView", "Hände greifen das Animationsmodell")
	await _until_time(use_end + 0.05)
	_check(is_equal_approx(_stats.get("hp"), minf(hp_before + 45.0, 100.0)) and _count() == 1,
		"Ende: +45 HP, ein Stim verbraucht (%.0f HP, %d übrig)" % [_stats.get("hp"), _count()])
	await _until_idle()
	_check(not bool(_use.call("is_active")), "Animation endet sauber")
	await _frames(30)
	_check(_item_user.call("get_held_view") != null, "nächster Stim kommt wieder in die Hand")


func _check_cancel_by_switch() -> void:
	_give("stim_pack", 2)
	_inventory.call("add_item", _item("credchip"), 1)
	await _frames(5)
	_stats.call("damage", 30.0)
	await _frames(2)
	var hp_before: float = _stats.get("hp")
	_item_user.call("use_selected")
	await _until_time(0.6)
	_inventory.call("select", 1)
	await _frames(2)
	_check(not bool(_use.call("is_active")), "Slotwechsel bricht sofort ab")
	_check(is_equal_approx(_stats.get("hp"), hp_before) and int(_inventory.call("get_count", 0)) == 2,
		"Abbruch: kein Effekt, nichts verbraucht")
	_check((_item_user.call("get_left_hand_target") as Dictionary).is_empty(), "linke Hand wieder frei")
	_inventory.call("select", 0)
	await _frames(5)


func _check_cancel_by_damage() -> void:
	_give("stim_pack", 1)
	await _frames(5)
	var hp_before: float = _stats.get("hp")
	_item_user.call("use_selected")
	await _until_time(0.8)
	_stats.call("damage", 5.0, &"guard")
	await _frames(2)
	_check(not bool(_use.call("is_using")), "Treffer bricht ab")
	await _until_idle()
	_check(_count() == 1 and is_equal_approx(_stats.get("hp"), hp_before - 5.0), "nach Treffer nichts verbraucht, kein Heilen")
	_check(_item_user.call("get_held_view") != null, "Stim liegt nach dem Abbruch wieder in der Hand")


func _check_cancel_by_sprint() -> void:
	_give("energy_drink", 1)
	await _frames(5)
	_item_user.call("use_selected")
	await _until_time(0.5)
	_stats.call("set_sprinting", true)
	await _frames(2)
	_stats.call("set_sprinting", false)
	_check(not bool(_use.call("is_using")), "Sprint bricht Trinken ab")
	await _until_idle()
	_check(_count() == 1, "Dose nach Sprint-Abbruch noch da")


func _check_drink_boost_at_end() -> void:
	_give("energy_drink", 1)
	await _frames(5)
	_stats.set("stamina", 10.0)
	_item_user.call("use_selected")
	var use_end: float = _use.get("_use_end")
	await _until_time(use_end * 0.8)
	_check(float(_stats.call("get_boost_left")) == 0.0, "Trinken: Boost erst am Ende")
	await _until_time(use_end + 0.05)
	_check(float(_stats.call("get_boost_left")) > 10.0 and float(_stats.get("stamina")) > 90.0,
		"Trinken fertig: Boost und Ausdauer")
	await _until_idle()
	_check(_item_user.call("get_held_view") == null, "letzte Dose weg: Hand leer")


func _check_hunger_does_not_cancel() -> void:
	_give("noodles", 1)
	await _frames(5)
	_stats.set("hunger", 0.0)
	_stats.set("hp", 80.0)
	_item_user.call("use_selected")
	# Bei Hunger 0 sinken HP jedes Frame; das darf Essen nicht abbrechen.
	await _until_idle()
	_check(_count() == 0 and float(_stats.get("hunger")) >= 44.0, "Essen trotz Hunger-Schaden fertig")


func _check_bandage_and_last_item() -> void:
	_give("nano_bandage", 1)
	await _frames(5)
	_stats.set("hp", 20.0)
	_item_user.call("use_selected")
	var use_end: float = _use.get("_use_end")
	_check(use_end > 2.5, "Verband dauert länger (%.1f s)" % use_end)
	await _until_time(use_end * 0.7)
	var wrap := (_hands.call("get_arm_node", -1.0) as Node).find_child("BandageWrap", false, false)
	_check(wrap != null, "Verband wächst am linken Unterarm")
	await _until_idle()
	_check(is_equal_approx(_stats.get("hp"), 90.0) and _count() == 0, "Verband: +70 HP, verbraucht")


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
