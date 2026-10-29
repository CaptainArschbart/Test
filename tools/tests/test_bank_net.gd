extends SceneTree
## Prüft die Überweisung im Multiplayer mit zwei Prozessen auf diesem Rechner.
##
## Aufruf (Projektordner), zwei Prozesse gleichzeitig, Host zuerst:
##   godot --headless --path . -s res://tools/tests/test_bank_net.gd -- host
##   godot --headless --path . -s res://tools/tests/test_bank_net.gd -- client
## Der Host überweist 120 an den Client, der Client 30 zurück. Jeder Prozess prüft
## sein eigenes Konto und das Bankfenster (Empfänger in der Liste, Knopf frei).
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const TESTMAP := "res://scenes/testmap/testmap.tscn"
const PORT := 7791
const TIMEOUT_MS := 90000

var _checks := 0
var _fails := 0
var _host := false


func _initialize() -> void:
	_host = OS.get_cmdline_user_args().has("host")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + ("[host] " if _host else "[client] ") + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _players() -> Array[Node]:
	var result: Array[Node] = []
	var holder := root.get_node_or_null(^"NetworkManager/Players")
	if holder != null:
		result.assign(holder.get_children())
	return result


func _local_player() -> Node:
	for player: Node in _players():
		if bool(player.call("controls_local_body")):
			return player
	return null


func _remote_player() -> Node:
	for player: Node in _players():
		if not bool(player.call("controls_local_body")):
			return player
	return null


## Wartet, bis `condition` wahr ist oder die Zeit abläuft.
func _wait_for(condition: Callable, timeout_ms := TIMEOUT_MS) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout_ms:
		if condition.call():
			return true
		await process_frame
	return false


func _run() -> void:
	var net := root.get_node(^"NetworkManager")
	var err: int
	if _host:
		err = net.call("host_map", TESTMAP, PORT, false)
		if err == OK:
			change_scene_to_file(TESTMAP)
	else:
		await create_timer(3.0).timeout
		err = net.call("create_client", "127.0.0.1", PORT)
	_check(err == OK, "Verbindung aufgebaut (Fehler %d)" % err)
	if err != OK:
		_finish()
		return
	var both := await _wait_for(func() -> bool: return _local_player() != null and _remote_player() != null)
	_check(both, "Beide Spieler da (%d Figuren)" % _players().size())
	if not both:
		_finish()
		return
	await _frames(30)
	var me := _local_player()
	var other := _remote_player()
	var inventory: Node = me.get("inventory")
	inventory.call("take_all_money")
	inventory.call("add_money", 200)
	inventory.call("deposit", 200)
	_check(int(inventory.get("bank")) == 200, "200 eingezahlt")
	var received: Array = []
	inventory.connect("transfer_received", func(amount: int, from_name: String) -> void:
		received.append([amount, from_name]))

	# Bankfenster: der andere Spieler steht in der Liste, der Knopf ist frei.
	var ui: Node = load("res://scenes/interact/bank_ui.gd").call("for_player", me)
	ui.call("open")
	await _frames(3)
	var select: OptionButton = ui.get("recipient_select")
	var button: Button = ui.get("transfer_button")
	var expected_name: String = load("res://scenes/inventory/inventory.gd").call(
		"peer_display_name", other.get_multiplayer_authority())
	_check(select.item_count == 1 and select.get_item_text(0) == expected_name,
		"Empfänger in der Liste: %s" % (select.get_item_text(0) if select.item_count > 0 else "-"))
	_check(not button.disabled, "Überweisen-Knopf ist frei")

	var amount := 120 if _host else 30
	var start := 200
	if _host:
		# Dem Client Zeit geben, sein Konto zu füllen und auf Gutschriften zu hören.
		await create_timer(4.0).timeout
	else:
		# Erst auf die Überweisung des Hosts warten, dann zurücküberweisen.
		var got := await _wait_for(func() -> bool: return received.size() >= 1, 20000)
		_check(got and received[0][0] == 120 and str(received[0][1]).contains("Host"),
			"120 vom Host erhalten (%s)" % str(received))
		_check(int(inventory.get("bank")) == 320, "Konto 320 (%d)" % int(inventory.get("bank")))
		start = 320
	ui.set("_recipient_timer", 0.0)
	var amount_edit: LineEdit = ui.get("amount_edit")
	amount_edit.text = str(amount)
	button.pressed.emit()
	_check(int(inventory.get("bank")) == start - amount,
		"%d überwiesen, Konto %d" % [amount, int(inventory.get("bank"))])
	if _host:
		var got_back := await _wait_for(func() -> bool: return received.size() >= 1, 20000)
		_check(got_back and received[0][0] == 30, "30 vom Client zurück (%s)" % str(received))
		_check(int(inventory.get("bank")) == 110, "Konto 110 (%d)" % int(inventory.get("bank")))
		ui.call("close")
		# Der Client soll fertig sein, bevor der Host die Sitzung beendet.
		await create_timer(4.0).timeout
	else:
		ui.call("close")
		await create_timer(1.0).timeout
	_finish()


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
