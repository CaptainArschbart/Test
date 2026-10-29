extends CanvasLayer
## Fenster des Bankautomaten (bank_terminal.gd): Bargeld einzahlen, abheben und an andere
## Spieler überweisen.
##
## Wird beim ersten Benutzen als Kind des lokalen Players angelegt ("BankUI") und danach nur
## ein- und ausgeblendet. Solange es offen ist, ist die Maus frei, der Spieler steht still
## (Player.input_locked) und Player.open_panel zeigt hierher, damit das Inventar-HUD die Sperre
## nicht aufhebt. Esc oder "interact" (außerhalb des Betragsfelds) schließt es.
##
## Der Knopf „Überweisen“ ist immer da. Ohne Empfänger (Einzelspieler, allein online) ist er
## gesperrt und ein Hinweis erklärt, dass Überweisungen im Multiplayer gehen. Empfänger sind
## alle anderen Spielerfiguren in der Gruppe "player"; ihr Inventar bekommt die Gutschrift
## über Inventory.send_transfer.
## Kein class_name: wird per preload benutzt (siehe vital_sounds.gd).

const HudScript := preload("res://scenes/survival/survival_hud.gd")
const THEME := preload("res://scenes/ui/cyber_theme.tres")

const PANEL_COLOR := Color(0.03, 0.0, 0.08, 0.94)
const CYAN := Color(0.0, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.1, 0.75)
const MONEY_COLOR := Color(1.0, 0.9, 0.2)
const OK_COLOR := Color(0.3, 1.0, 0.55)
const WARN_COLOR := Color(1.0, 0.16, 0.36)
const DIM_COLOR := Color(0.6, 0.62, 0.75)
## Wie oft die Empfängerliste nachgeladen wird, während das Fenster offen ist (Sekunden).
const RECIPIENT_REFRESH := 0.5

var player: Player
var inventory: Inventory

var cash_label: Label
var bank_label: Label
var amount_edit: LineEdit
var deposit_button: Button
var withdraw_button: Button
var deposit_all_button: Button
var withdraw_all_button: Button
var recipient_select: OptionButton
var transfer_button: Button
var transfer_hint: Label
var status_label: Label
var close_button: Button

var _root: Control
## Inventare der Empfänger in der Reihenfolge von recipient_select.
var _recipients: Array[Inventory] = []
var _recipient_timer := 0.0
var _status_tween: Tween


## Holt das Fenster des Players oder legt es an.
static func for_player(target: Player) -> CanvasLayer:
	var existing := target.get_node_or_null(^"BankUI") as CanvasLayer
	if existing != null:
		return existing
	var ui: CanvasLayer = load("res://scenes/interact/bank_ui.gd").new()
	ui.name = "BankUI"
	target.add_child(ui)
	return ui


func _ready() -> void:
	# Über HUD und Inventar (Layer 2), unter dem Pausemenü (Layer 10).
	layer = 5
	player = get_parent() as Player
	if player == null:
		push_error("BankUI braucht den Player als Parent.")
		return
	inventory = player.inventory
	_build()
	inventory.money_changed.connect(_refresh_balances.unbind(2))
	inventory.bank_changed.connect(_refresh_balances.unbind(2))
	_root.visible = false
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	if player == null or visible:
		return
	visible = true
	_root.visible = true
	player.open_panel = self
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	amount_edit.text = ""
	_set_status("Willkommen bei NC-BANK.", DIM_COLOR)
	_refresh_balances()
	_refresh_recipients()
	amount_edit.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_root.visible = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	if player == null:
		return
	if player.open_panel == self:
		player.open_panel = null
	player.input_locked = false
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not visible or player == null:
		return
	# Tod oder ein anderes Fenster hat übernommen: schließen statt hängen zu bleiben.
	if player.dead or player.open_panel != self:
		close()
		return
	_recipient_timer -= delta
	if _recipient_timer <= 0.0:
		_refresh_recipients()


func _input(event: InputEvent) -> void:
	if not visible or event.is_echo() or get_tree().paused:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not amount_edit.has_focus():
		close()
		get_viewport().set_input_as_handled()


## Eingetragener Betrag. 0 = leer oder ungültig.
func get_amount() -> int:
	var text := amount_edit.text.strip_edges().replace(".", "")
	if not text.is_valid_int():
		return 0
	return clampi(text.to_int(), 0, Inventory.MAX_MONEY)


func do_deposit(amount: int) -> int:
	if amount <= 0:
		_set_status("Betrag eingeben.", WARN_COLOR)
		return 0
	if inventory.money <= 0:
		_set_status("Kein Bargeld dabei.", WARN_COLOR)
		return 0
	var moved := inventory.deposit(amount)
	if moved <= 0:
		_set_status("Konto voll.", WARN_COLOR)
	elif moved < amount:
		_set_status("%s ¢ eingezahlt (mehr Bargeld war nicht da)." % _fmt(moved), OK_COLOR)
	else:
		_set_status("%s ¢ eingezahlt." % _fmt(moved), OK_COLOR)
	return moved


func do_withdraw(amount: int) -> int:
	if amount <= 0:
		_set_status("Betrag eingeben.", WARN_COLOR)
		return 0
	if inventory.bank <= 0:
		_set_status("Konto leer.", WARN_COLOR)
		return 0
	var moved := inventory.withdraw(amount)
	if moved <= 0:
		_set_status("Mehr Bargeld kannst du nicht tragen.", WARN_COLOR)
	elif moved < amount:
		_set_status("%s ¢ abgehoben (mehr war nicht auf dem Konto)." % _fmt(moved), OK_COLOR)
	else:
		_set_status("%s ¢ abgehoben." % _fmt(moved), OK_COLOR)
	return moved


func do_transfer(amount: int) -> bool:
	var index := recipient_select.selected
	if _recipients.is_empty() or index < 0 or index >= _recipients.size():
		_set_status("Kein Empfänger. Überweisungen gehen im Multiplayer.", WARN_COLOR)
		return false
	if amount <= 0:
		_set_status("Betrag eingeben.", WARN_COLOR)
		return false
	if inventory.bank < amount:
		_set_status("Zu wenig Guthaben auf dem Konto.", WARN_COLOR)
		return false
	var target := _recipients[index]
	if not is_instance_valid(target):
		_refresh_recipients()
		_set_status("Empfänger ist nicht mehr da.", WARN_COLOR)
		return false
	var name_text := recipient_select.get_item_text(index)
	if not inventory.send_transfer(target, amount, _own_name()):
		_set_status("Überweisung fehlgeschlagen.", WARN_COLOR)
		return false
	_set_status("%s ¢ an %s überwiesen." % [_fmt(amount), name_text], OK_COLOR)
	return true


## Andere Spieler, an die überwiesen werden kann (Inventar, Anzeigename).
func list_recipients() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in get_tree().get_nodes_in_group("player"):
		var other := node as Player
		if other == null or other == player or other.inventory == null:
			continue
		result.append({
			"inventory": other.inventory,
			"name": Inventory.peer_display_name(other.get_multiplayer_authority()),
		})
	return result


func _refresh_recipients() -> void:
	_recipient_timer = RECIPIENT_REFRESH
	var found := list_recipients()
	var same := found.size() == _recipients.size()
	if same:
		for i in found.size():
			if found[i]["inventory"] != _recipients[i]:
				same = false
				break
	if same and recipient_select.item_count > 0:
		return
	var previous: Inventory = null
	if recipient_select.selected >= 0 and recipient_select.selected < _recipients.size():
		previous = _recipients[recipient_select.selected]
	_recipients.clear()
	recipient_select.clear()
	for entry: Dictionary in found:
		_recipients.append(entry["inventory"])
		recipient_select.add_item(str(entry["name"]))
	var has_any := not _recipients.is_empty()
	if not has_any:
		recipient_select.add_item("— kein Empfänger —")
		recipient_select.select(0)
	else:
		var keep := _recipients.find(previous)
		recipient_select.select(keep if keep >= 0 else 0)
	recipient_select.disabled = not has_any
	transfer_button.disabled = not has_any
	transfer_hint.text = "An einen Spieler in dieser Sitzung." if has_any \
			else "Überweisungen an andere Spieler gehen im Multiplayer."


func _refresh_balances() -> void:
	if inventory == null or cash_label == null:
		return
	cash_label.text = "%s ¢" % _fmt(inventory.money)
	bank_label.text = "%s ¢" % _fmt(inventory.bank)


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
	if _status_tween:
		_status_tween.kill()
	status_label.modulate.a = 1.0
	_status_tween = create_tween()
	_status_tween.tween_property(status_label, "modulate:a", 0.75, 0.6).from(1.0)


func _own_name() -> String:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return "Runner"
	return Inventory.peer_display_name(multiplayer.get_unique_id())


func _fmt(amount: int) -> String:
	return HudScript.format_money(amount)


# --- Aufbau ---------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = THEME
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = CYAN
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.shadow_color = Color(CYAN, 0.25)
	style.shadow_size = 12
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := _label("NC-BANK", 24, CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label("TERMINAL // 24H", 13, MAGENTA))
	box.add_child(_separator(MAGENTA))

	var balances := GridContainer.new()
	balances.columns = 2
	balances.add_theme_constant_override("h_separation", 24)
	box.add_child(balances)
	balances.add_child(_label("BARGELD", 14, DIM_COLOR))
	cash_label = _label("0 ¢", 20, MONEY_COLOR)
	cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cash_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balances.add_child(cash_label)
	balances.add_child(_label("KONTO", 14, DIM_COLOR))
	bank_label = _label("0 ¢", 20, MONEY_COLOR)
	bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balances.add_child(bank_label)

	box.add_child(_separator(Color(CYAN, 0.4)))
	box.add_child(_label("BETRAG", 13, DIM_COLOR))
	amount_edit = LineEdit.new()
	amount_edit.name = "Amount"
	amount_edit.placeholder_text = "z. B. 100"
	amount_edit.max_length = 7
	amount_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_edit.text_changed.connect(_on_amount_text_changed)
	amount_edit.text_submitted.connect(func(_t: String) -> void: amount_edit.release_focus())
	box.add_child(amount_edit)

	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 6)
	box.add_child(quick)
	for step: int in [10, 50, 100, 500]:
		var add_button := _button("+%d" % step, 14)
		add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_button.pressed.connect(_add_to_amount.bind(step))
		quick.add_child(add_button)
	var clear_button := _button("C", 14)
	clear_button.pressed.connect(func() -> void: amount_edit.text = "")
	quick.add_child(clear_button)

	var moves := GridContainer.new()
	moves.columns = 2
	moves.add_theme_constant_override("h_separation", 8)
	moves.add_theme_constant_override("v_separation", 6)
	box.add_child(moves)
	deposit_button = _button("Einzahlen", 16)
	deposit_button.pressed.connect(func() -> void: do_deposit(get_amount()))
	withdraw_button = _button("Abheben", 16)
	withdraw_button.pressed.connect(func() -> void: do_withdraw(get_amount()))
	deposit_all_button = _button("Alles einzahlen", 14)
	deposit_all_button.pressed.connect(func() -> void: do_deposit(inventory.money))
	withdraw_all_button = _button("Alles abheben", 14)
	withdraw_all_button.pressed.connect(func() -> void: do_withdraw(inventory.bank))
	for button: Button in [deposit_button, withdraw_button, deposit_all_button, withdraw_all_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		moves.add_child(button)

	box.add_child(_separator(Color(CYAN, 0.4)))
	box.add_child(_label("ÜBERWEISUNG", 13, DIM_COLOR))
	var transfer_row := HBoxContainer.new()
	transfer_row.add_theme_constant_override("separation", 8)
	box.add_child(transfer_row)
	recipient_select = OptionButton.new()
	recipient_select.name = "Recipient"
	recipient_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transfer_row.add_child(recipient_select)
	transfer_button = _button("Überweisen", 16)
	transfer_button.name = "Transfer"
	transfer_button.pressed.connect(func() -> void: do_transfer(get_amount()))
	transfer_row.add_child(transfer_button)
	transfer_hint = _label("", 12, DIM_COLOR)
	transfer_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(transfer_hint)

	box.add_child(_separator(MAGENTA))
	var footer := HBoxContainer.new()
	box.add_child(footer)
	status_label = _label("", 14, DIM_COLOR)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(status_label)
	close_button = _button("Schließen", 14)
	close_button.pressed.connect(close)
	footer.add_child(close_button)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", size)
	return button


func _separator(color: Color) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _add_to_amount(step: int) -> void:
	amount_edit.text = str(mini(get_amount() + step, Inventory.MAX_MONEY))


## Nur Ziffern im Betragsfeld.
func _on_amount_text_changed(text: String) -> void:
	var digits := ""
	for c in text:
		if c >= "0" and c <= "9":
			digits += c
	if digits != text:
		var caret := amount_edit.caret_column
		amount_edit.text = digits
		amount_edit.caret_column = mini(caret, digits.length())
