extends SceneTree
## Prüft das Geldsystem: Credchips landen als Kontostand im Inventar statt in Slots,
## Automaten buchen ab, die HUD-Anzeige zeigt den Betrag, beim Tod fällt das Geld als Stapel.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_money.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne typisierte Verweise auf Spielklassen (siehe test_sector7_enemies.gd: -s-Skripte werden vor
## den Autoloads kompiliert).

const TESTMAP := "res://scenes/testmap/testmap.tscn"

var _checks := 0
var _fails := 0
var _player: Node
var _inventory: Node
var _hud: Node


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


func _item(id: String) -> Resource:
	return load("res://scenes/items/data/%s.tres" % id)


func _money() -> int:
	return int(_inventory.get("money"))


func _slots_with(id: String) -> int:
	var found := 0
	for i: int in int(_inventory.call("get_size")):
		var item: Resource = _inventory.call("get_item", i)
		if item != null and item.get("id") == id:
			found += 1
	return found


func _run() -> void:
	change_scene_to_file(TESTMAP)
	await _frames(20)
	_player = get_first_node_in_group("player")
	_check(_player != null, "Testmap mit Spielerfigur geladen")
	if _player == null:
		_finish()
		return
	_inventory = _player.get("inventory")
	_hud = _player.get_node_or_null(^"SurvivalHud")
	_check(_hud != null and _hud.get("money_label") != null, "HUD hat eine Geldanzeige")

	_check_format()
	await _check_pickup_and_hud()
	_check_spend()
	_check_vending()
	await _check_death_drop()
	_finish()


func _check_format() -> void:
	var hud_script: GDScript = load("res://scenes/survival/survival_hud.gd")
	var cases := {0: "0", 7: "7", 999: "999", 1000: "1.000", 1250: "1.250", 999999: "999.999"}
	for amount: int in cases:
		var text: String = hud_script.call("format_money", amount)
		_check(text == cases[amount], "format_money(%d) = %s" % [amount, text])


func _check_pickup_and_hud() -> void:
	_inventory.call("take_all_money")
	var credchip := _item("credchip")
	_check(bool(credchip.get("is_currency")), "Credchip ist als Währung markiert")
	var slots_before := _slots_with("credchip")
	var gained: Array = []
	_inventory.connect("item_added", func(item: Resource, amount: int) -> void: gained.append([item, amount]))
	var left: int = _inventory.call("add_item", credchip, 15)
	_check(left == 0 and _money() == 15, "15 Credchips aufgenommen → Kontostand 15 (%d)" % _money())
	_check(_slots_with("credchip") == slots_before, "Credchips belegen keinen Slot")
	_check(gained.size() == 1 and gained[0][1] == 15, "Einblendung „+15 Credchip“ wird ausgelöst")
	# Pickup in der Welt: Aufheben bucht auf das Konto.
	var pickup: Node3D = load("res://scenes/items/pickup.tscn").instantiate()
	pickup.set("item", credchip)
	pickup.set("count", 40)
	_player.get_parent().add_child(pickup)
	await _frames(2)
	pickup.call("interact", _player)
	await _frames(2)
	_check(_money() == 55 and not is_instance_valid(pickup),
		"Pickup mit 40 Credchips aufgehoben → 55 (%d)" % _money())
	# HUD zählt zum neuen Betrag hoch.
	await create_timer(0.8).timeout
	var label: Label = _hud.get("money_label")
	_check(label.text == "55", "HUD zeigt 55 (%s)" % label.text)
	_inventory.call("add_money", 1200)
	await create_timer(0.8).timeout
	_check(label.text == "1.255", "HUD zeigt 1.255 (%s)" % label.text)


func _check_spend() -> void:
	var before := _money()
	_check(not bool(_inventory.call("spend_money", before + 1)) and _money() == before,
		"Zu wenig Geld: nichts abgezogen")
	_check(bool(_inventory.call("spend_money", 5)) and _money() == before - 5, "5 ausgegeben")
	_inventory.call("take_all_money")
	_check(_money() == 0, "take_all_money leert das Konto")
	var max_money: int = _inventory.get("MAX_MONEY")
	_inventory.call("add_money", max_money + 50)
	_check(_money() == max_money, "Obergrenze %d wird eingehalten" % max_money)
	_inventory.call("take_all_money")


func _check_vending() -> void:
	var machine: Node = current_scene.find_child("ColaMachine", true, false)
	_check(machine != null, "Cola-Automat in der Testmap")
	if machine == null:
		return
	for i: int in int(_inventory.call("get_size")):
		_inventory.call("remove_at", i, 999)
	_inventory.call("add_money", 1)
	machine.call("interact", _player)
	_check(_money() == 1 and _slots_with("energy_drink") == 0, "1 ¢ reicht nicht für Preis 2")
	_inventory.call("add_money", 4)
	machine.call("interact", _player)
	_check(_money() == 3 and _slots_with("energy_drink") == 1, "Kauf: 5 → 3 ¢, Drink im Inventar")
	var text: String = machine.call("get_interact_text", _player)
	_check(text.contains("2"), "Automat nennt den Preis (%s)" % text)


func _check_death_drop() -> void:
	_inventory.call("take_all_money")
	_inventory.call("add_money", 77)
	var parent := _player.get_parent()
	var before := parent.get_child_count()
	_player.call("_drop_all_items")
	await _frames(2)
	_check(_money() == 0, "Tod: Konto leer")
	var stack: Node = null
	for i in range(before, parent.get_child_count()):
		var child := parent.get_child(i)
		var item: Resource = child.get("item")
		if item != null and item.get("id") == "credchip":
			stack = child
	_check(stack != null and int(stack.get("count")) == 77, "Tod: Credchip-Stapel mit 77 liegt da")


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
