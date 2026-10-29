extends CanvasLayer
## Ladenfenster (vom Verkäufer in shop_interior.gd geöffnet): Angebot mit Preisen, bezahlt wird mit
## Bargeld (Inventory.money). Gleicher Aufbau wie das Bankfenster (bank_ui.gd): wird einmal als Kind
## "ShopUI" am lokalen Player angelegt, sperrt solange die Eingabe (Player.open_panel), Esc oder E
## schließt. Schlägt der Laden Alarm oder stirbt der Verkäufer, geht das Fenster zu.
## Kein class_name: wird per preload benutzt.

const THEME := preload("res://scenes/ui/cyber_theme.tres")
const HudScript := preload("res://scenes/survival/survival_hud.gd")

const PANEL_COLOR := Color(0.03, 0.0, 0.08, 0.94)
const ORANGE := Color(1.0, 0.6, 0.2)
const CYAN := Color(0.0, 0.95, 1.0)
const MONEY_COLOR := Color(1.0, 0.9, 0.2)
const OK_COLOR := Color(0.3, 1.0, 0.55)
const WARN_COLOR := Color(1.0, 0.16, 0.36)
const DIM_COLOR := Color(0.6, 0.62, 0.75)

const SHOP_NAMES := {
	"sign_ramen": "RAMEN-BAR", "sign_noodles": "NUDEL-SHOP", "sign_pharmacy": "APOTHEKE",
	"sign_bar": "BAR", "sign_24h": "24/7 MARKT", "sign_shop": "LADEN",
}

var player: Player
## Der Laden, zu dem das Fenster gerade gehört (shop_interior.gd).
var shop: Node

var title_label: Label
var cash_label: Label
var rows: VBoxContainer
var status_label: Label
var buy_buttons: Array[Button] = []

var _root: Control


static func for_player(target: Player) -> CanvasLayer:
	var existing := target.get_node_or_null(^"ShopUI") as CanvasLayer
	if existing != null:
		return existing
	var ui: CanvasLayer = load("res://scenes/interact/shop_ui.gd").new()
	ui.name = "ShopUI"
	target.add_child(ui)
	return ui


func _ready() -> void:
	layer = 5
	player = get_parent() as Player
	if player == null:
		push_error("ShopUI braucht den Player als Parent.")
		return
	_build()
	player.inventory.money_changed.connect(_refresh_cash.unbind(2))
	visible = false


func is_open() -> bool:
	return visible


func open(for_shop: Node) -> void:
	if player == null or for_shop == null:
		return
	shop = for_shop
	visible = true
	player.open_panel = self
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title_label.text = SHOP_NAMES.get(str(shop.get("shop_sign")), "LADEN")
	_fill_rows()
	_refresh_cash()
	_set_status("Was darf's sein?", DIM_COLOR)


func close() -> void:
	if not visible:
		return
	visible = false
	if player == null:
		return
	if player.open_panel == self:
		player.open_panel = null
	player.input_locked = false
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Vom Laden: Zustand hat sich geändert (Alarm, Überfall, Tod).
func refresh() -> void:
	if visible and shop != null and not bool(shop.call("is_open_for_business")):
		close()


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	if player.dead or player.open_panel != self or shop == null or not is_instance_valid(shop):
		close()
		return
	refresh()


func _input(event: InputEvent) -> void:
	if not visible or event.is_echo() or get_tree().paused:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


## Kauft Angebot Nr. `index`. true = gekauft.
func buy(index: int) -> bool:
	var offers: Array = shop.call("get_offers")
	if index < 0 or index >= offers.size():
		return false
	if not bool(shop.call("is_open_for_business")):
		_set_status("Der Laden hat zu.", WARN_COLOR)
		return false
	var item: ItemData = shop.call("load_item", str(offers[index][0]))
	var price := int(offers[index][1])
	if item == null:
		return false
	if player.inventory.money < price:
		_set_status("Zu wenig Bargeld (%d ¢ fehlen)." % (price - player.inventory.money), WARN_COLOR)
		return false
	if player.inventory.space_for(item) <= 0:
		_set_status("Inventar voll.", WARN_COLOR)
		return false
	player.inventory.spend_money(price)
	player.inventory.add_item(item, 1)
	_set_status("%s gekauft (−%d ¢)." % [item.display_name, price], OK_COLOR)
	return true


func _fill_rows() -> void:
	for child: Node in rows.get_children():
		child.queue_free()
	buy_buttons.clear()
	var offers: Array = shop.call("get_offers")
	for i in offers.size():
		var item: ItemData = shop.call("load_item", str(offers[i][0]))
		if item == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := ColorRect.new()
		swatch.color = item.color
		swatch.custom_minimum_size = Vector2(6, 28)
		row.add_child(swatch)
		var name_label := _label(item.display_name, 17, Color.WHITE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(_label("%d ¢" % int(offers[i][1]), 17, MONEY_COLOR))
		var button := Button.new()
		button.text = "Kaufen"
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(buy.bind(i))
		row.add_child(button)
		rows.add_child(row)
		buy_buttons.append(button)


func _refresh_cash() -> void:
	if cash_label != null and player != null:
		cash_label.text = "%s ¢" % HudScript.format_money(player.inventory.money)


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _build() -> void:
	_root = Control.new()
	_root.theme = THEME
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = ORANGE
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.shadow_color = Color(ORANGE, 0.25)
	style.shadow_size = 12
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	title_label = _label("LADEN", 24, ORANGE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	header.add_child(_label("BARGELD", 13, DIM_COLOR))
	cash_label = _label("0 ¢", 18, MONEY_COLOR)
	header.add_child(cash_label)
	var line := ColorRect.new()
	line.color = Color(ORANGE, 0.6)
	line.custom_minimum_size = Vector2(0, 1)
	box.add_child(line)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	box.add_child(rows)
	var footer := HBoxContainer.new()
	box.add_child(footer)
	status_label = _label("", 14, DIM_COLOR)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(status_label)
	var close_button := Button.new()
	close_button.text = "Schließen"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	footer.add_child(close_button)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
