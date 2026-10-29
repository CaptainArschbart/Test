extends SceneTree
## Prüft den Bankautomaten: Konto im Inventar (einzahlen, abheben, Grenzen, Überweisung),
## das Bankfenster (öffnen, sperrt den Spieler, Überweisen-Knopf im Einzelspieler gesperrt)
## und dass der Automat in Testmap und Sektor 7 frei steht.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_bank.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne typisierte Verweise auf Spielklassen (siehe test_money.gd).

const TESTMAP := "res://scenes/testmap/testmap.tscn"
const SLUM := "res://scenes/slum/slum.tscn"

var _checks := 0
var _fails := 0
var _player: Node
var _inventory: Node


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


func _money() -> int:
	return int(_inventory.get("money"))


func _bank() -> int:
	return int(_inventory.get("bank"))


func _reset(cash: int, bank: int) -> void:
	_inventory.call("take_all_money")
	_inventory.call("spend_bank", _bank())
	_inventory.call("add_money", cash)
	_inventory.call("add_bank", bank)


func _run() -> void:
	change_scene_to_file(TESTMAP)
	await _frames(20)
	_player = get_first_node_in_group("player")
	_check(_player != null, "Testmap mit Spielerfigur geladen")
	if _player == null:
		_finish()
		return
	_inventory = _player.get("inventory")
	_check_account()
	_check_transfer()
	await _check_ui()
	await _check_death_keeps_bank()
	await _check_placement(TESTMAP)
	await _check_placement(SLUM)
	_finish()


func _check_account() -> void:
	_reset(100, 0)
	var moved: int = _inventory.call("deposit", 40)
	_check(moved == 40 and _money() == 60 and _bank() == 40, "40 eingezahlt: 60 bar, 40 Konto")
	moved = _inventory.call("deposit", 500)
	_check(moved == 60 and _money() == 0 and _bank() == 100, "Mehr einzahlen als da: nur 60 (%d)" % moved)
	moved = _inventory.call("withdraw", 30)
	_check(moved == 30 and _money() == 30 and _bank() == 70, "30 abgehoben: 30 bar, 70 Konto")
	moved = _inventory.call("withdraw", 1000)
	_check(moved == 70 and _bank() == 0 and _money() == 100, "Mehr abheben als da: nur 70 (%d)" % moved)
	_check(int(_inventory.call("withdraw", 5)) == 0, "Leeres Konto: nichts abgehoben")
	_check(int(_inventory.call("deposit", -5)) == 0 and _money() == 100, "Negativer Betrag: nichts")
	var max_money: int = _inventory.get("MAX_MONEY")
	_reset(50, max_money - 20)
	moved = _inventory.call("deposit", 50)
	_check(moved == 20 and _bank() == max_money and _money() == 30, "Konto voll: nur 20 eingezahlt")
	_reset(max_money - 5, 100)
	moved = _inventory.call("withdraw", 100)
	_check(moved == 5 and _money() == max_money and _bank() == 95, "Bargeld voll: nur 5 abgehoben")
	var signals: Array = []
	_reset(0, 0)
	var record := func(balance: int, delta: int) -> void: signals.append([balance, delta])
	_inventory.connect("bank_changed", record)
	_inventory.call("add_money", 10)
	_inventory.call("deposit", 10)
	_inventory.disconnect("bank_changed", record)
	_check(signals.size() == 1 and signals[0] == [10, 10], "bank_changed(10, 10) beim Einzahlen")


func _check_transfer() -> void:
	var inventory_script: GDScript = load("res://scenes/inventory/inventory.gd")
	var other: Node = inventory_script.new()
	_player.get_parent().add_child(other)
	_reset(0, 200)
	var received: Array = []
	other.connect("transfer_received", func(amount: int, from_name: String) -> void:
		received.append([amount, from_name]))
	_check(bool(_inventory.call("send_transfer", other, 75, "Test")), "Überweisung 75 angenommen")
	_check(_bank() == 125 and int(other.get("bank")) == 75, "Absender 125, Empfänger 75")
	_check(received.size() == 1 and received[0] == [75, "Test"], "transfer_received(75, Test)")
	_check(not bool(_inventory.call("send_transfer", other, 500)) and _bank() == 125,
		"Zu wenig Guthaben: nichts überwiesen")
	_check(not bool(_inventory.call("send_transfer", _inventory, 10)) and _bank() == 125,
		"An sich selbst: abgelehnt")
	_check(not bool(_inventory.call("send_transfer", other, 0)), "Betrag 0: abgelehnt")
	_check(not bool(_inventory.call("send_transfer", null, 10)), "Kein Empfänger: abgelehnt")
	other.queue_free()
	var name_1: String = inventory_script.call("peer_display_name", 1)
	_check(name_1.contains("Host"), "Peer 1 heißt %s" % name_1)


func _check_ui() -> void:
	var terminal: Node = current_scene.find_child("BankTerminal", true, false)
	_check(terminal != null, "Bankautomat in der Testmap")
	if terminal == null:
		return
	var text: String = terminal.call("get_interact_text", _player)
	_check(text.contains("NC-BANK"), "Hinweis unter dem Fadenkreuz: %s" % text)
	_reset(300, 0)
	terminal.call("interact", _player)
	await _frames(3)
	var ui: Node = _player.get_node_or_null(^"BankUI")
	_check(ui != null and bool(ui.call("is_open")), "E öffnet das Bankfenster")
	if ui == null:
		return
	_check(bool(_player.get("input_locked")) and _player.get("open_panel") == ui,
		"Spieler gesperrt, open_panel = BankUI")
	# Das Inventar-HUD darf die Sperre nicht wieder lösen.
	await _frames(5)
	_check(bool(_player.get("input_locked")), "Sperre hält nach 5 Frames (Inventar-HUD greift nicht)")
	var transfer: Button = ui.get("transfer_button")
	var hint: Label = ui.get("transfer_hint")
	_check(transfer != null and transfer.visible and transfer.text == "Überweisen",
		"Überweisen-Knopf ist auch im Einzelspieler da")
	_check(transfer.disabled and hint.text.contains("Multiplayer"),
		"Ohne Empfänger gesperrt mit Hinweis (%s)" % hint.text)
	_check(not bool(ui.call("do_transfer", 10)) and _bank() == 0, "Überweisen ohne Empfänger bucht nichts")
	var edit: LineEdit = ui.get("amount_edit")
	edit.text = "1a2.0"
	edit.text_changed.emit(edit.text)
	_check(edit.text == "120", "Betragsfeld nimmt nur Ziffern (%s)" % edit.text)
	ui.call("_add_to_amount", 50)
	_check(int(ui.call("get_amount")) == 170, "+50 ergibt 170")
	var deposit_button: Button = ui.get("deposit_button")
	deposit_button.pressed.emit()
	await _frames(2)
	var cash_label: Label = ui.get("cash_label")
	var bank_label: Label = ui.get("bank_label")
	_check(_money() == 130 and _bank() == 170, "Knopf Einzahlen: 130 bar, 170 Konto")
	_check(cash_label.text == "130 ¢" and bank_label.text == "170 ¢",
		"Anzeige: %s / %s" % [cash_label.text, bank_label.text])
	var withdraw_all: Button = ui.get("withdraw_all_button")
	withdraw_all.pressed.emit()
	_check(_money() == 300 and _bank() == 0, "Knopf Alles abheben: 300 bar")
	var status: Label = ui.get("status_label")
	_check(status.text.contains("170"), "Statuszeile: %s" % status.text)
	ui.call("close")
	await _frames(3)
	_check(not bool(ui.call("is_open")) and not bool(_player.get("input_locked"))
		and _player.get("open_panel") == null, "Schließen gibt den Spieler frei")
	terminal.call("interact", _player)
	await _frames(2)
	_check(bool(ui.call("is_open")) and _player.get_children().filter(
		func(n: Node) -> bool: return n.name.begins_with("BankUI")).size() == 1,
		"Zweites Öffnen benutzt dasselbe Fenster")
	ui.call("close")


func _check_death_keeps_bank() -> void:
	_reset(40, 90)
	_player.call("_drop_all_items")
	await _frames(2)
	_check(_money() == 0 and _bank() == 90, "Tod: Bargeld fällt, Konto (90) bleibt")


## Der Automat darf nicht in Wänden oder anderen Automaten stecken.
func _check_placement(path: String) -> void:
	if current_scene == null or current_scene.scene_file_path != path:
		change_scene_to_file(path)
		await _frames(20)
	var terminal: Node3D = current_scene.find_child("BankTerminal", true, false)
	_check(terminal != null, "%s: Bankautomat vorhanden" % path.get_file())
	if terminal == null:
		return
	await physics_frame
	await physics_frame
	var shape := BoxShape3D.new()
	var size: Vector3 = terminal.get("size")
	# Etwas kleiner, damit Boden und Nachbarn, die nur anliegen, nicht zählen.
	shape.size = size - Vector3(0.1, 0.2, 0.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = terminal.global_transform.translated_local(Vector3.UP * size.y * 0.5)
	query.collision_mask = 1
	query.exclude = [terminal.get_rid()]
	var hits := terminal.get_world_3d().direct_space_state.intersect_shape(query, 8)
	var names: Array[String] = []
	for hit: Dictionary in hits:
		var collider: Object = hit["collider"]
		names.append(str(collider.get("name")) if collider != null else "?")
	_check(hits.is_empty(), "%s: Automat steckt in nichts %s" % [path.get_file(), names])
	# Vor der Front muss man stehen können.
	var front: Vector3 = terminal.global_transform * Vector3(0.0, 1.0, size.z * 0.5 + 0.6)
	var ray := PhysicsRayQueryParameters3D.create(front, front + Vector3.DOWN * 1.5, 1)
	var floor_hit := terminal.get_world_3d().direct_space_state.intersect_ray(ray)
	var stand := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	stand.shape = capsule
	stand.transform = Transform3D(Basis(), front + Vector3.UP * 0.1)
	stand.collision_mask = 1
	var blocked := terminal.get_world_3d().direct_space_state.intersect_shape(stand, 4)
	_check(not floor_hit.is_empty() and blocked.is_empty(),
		"%s: vor dem Automaten ist Boden und Platz" % path.get_file())


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
