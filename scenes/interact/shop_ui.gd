extends CanvasLayer
## Ladenfenster (vom Verkäufer in shop_interior.gd geöffnet), gleicher Aufbau wie das Bankfenster:
##   KASSE    Warenkorb (aus dem Regal genommen, noch nicht bezahlt) mit „Bezahlen“.
##   THEKE    Ware aus der Vitrine hinter dem Verkäufer (echter Bestand des Ladens) kaufen.
##   ANKAUF   Nur beim Hehler (Ladenschild sign_shop): Wertsachen aus dem Inventar verkaufen.
## Bezahlt wird mit Bargeld (Inventory.money). Wird einmal als Kind "ShopUI" am lokalen Player
## angelegt, sperrt solange die Eingabe (Player.open_panel). Esc oder E schließt. Schlägt der Laden
## Alarm oder stirbt der Verkäufer, geht das Fenster zu.
## Kein class_name: wird per preload benutzt.

const THEME := preload("res://scenes/ui/cyber_theme.tres")
const HudScript := preload("res://scenes/survival/survival_hud.gd")

const PANEL_COLOR := Color(0.03, 0.0, 0.08, 0.94)
const ORANGE := Color(1.0, 0.6, 0.2)
const MONEY_COLOR := Color(1.0, 0.9, 0.2)
const OK_COLOR := Color(0.3, 1.0, 0.55)
const WARN_COLOR := Color(1.0, 0.16, 0.36)
const DIM_COLOR := Color(0.6, 0.62, 0.75)

const SHOP_NAMES := {
	"sign_ramen": "RAMEN-BAR", "sign_noodles": "NUDEL-SHOP", "sign_pharmacy": "APOTHEKE",
	"sign_bar": "BAR", "sign_24h": "24/7 MARKT", "sign_shop": "ANKAUF & VERKAUF",
}

var player: Player
## Der Laden, zu dem das Fenster gerade gehört (shop_interior.gd).
var shop: Node

var title_label: Label
var cash_label: Label
var basket_label: Label
var pay_button: Button
var counter_rows: VBoxContainer
var fence_title: Label
var fence_rows: VBoxContainer
var status_label: Label

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
	player.inventory.money_changed.connect(func(_m: int, _d: int) -> void: refresh())
	player.inventory.changed.connect(refresh)
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
	_set_status("Was darf's sein?", DIM_COLOR)
	refresh()


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


## Neu aufbauen (Geld, Warenkorb, Bestand). Bei Alarm oder Tod des Verkäufers zu.
func refresh() -> void:
	if not visible or shop == null or not is_instance_valid(shop):
		return
	if not bool(shop.call("is_open_for_business")):
		close()
		return
	cash_label.text = "%s ¢" % HudScript.format_money(player.inventory.money)
	var unpaid := int(shop.get("my_unpaid"))
	basket_label.text = "Warenkorb: %d ¢" % unpaid if unpaid > 0 else "Warenkorb leer – Ware aus dem Regal nehmen"
	pay_button.disabled = unpaid <= 0
	_fill_counter()
	_fill_fence()


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	if player.dead or player.open_panel != self or shop == null or not is_instance_valid(shop):
		close()


func _input(event: InputEvent) -> void:
	if not visible or event.is_echo() or get_tree().paused:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


## Warenkorb bezahlen. true = Anfrage raus (Geld reicht).
func pay() -> bool:
	var unpaid := int(shop.get("my_unpaid"))
	if unpaid <= 0:
		return false
	if player.inventory.money < unpaid:
		_set_status("Zu wenig Bargeld (%d ¢ fehlen)." % (unpaid - player.inventory.money), WARN_COLOR)
		return false
	shop.call("request", player, &"pay")
	_set_status("Bezahlt: %d ¢." % unpaid, OK_COLOR)
	return true


## Theken-Ware von Platz `slot` kaufen. true = Anfrage raus.
func buy(slot: int) -> bool:
	var item: ItemData = shop.call("item_at", slot)
	if item == null:
		_set_status("Nicht mehr da.", WARN_COLOR)
		return false
	var price := int(shop.call("price_of", item, player))
	if player.inventory.money < price:
		_set_status("Zu wenig Bargeld (%d ¢ fehlen)." % (price - player.inventory.money), WARN_COLOR)
		return false
	if player.inventory.space_for(item) <= 0:
		_set_status("Inventar voll.", WARN_COLOR)
		return false
	shop.call("request", player, &"buy", slot)
	_set_status("%s gekauft (−%d ¢)." % [item.display_name, price], OK_COLOR)
	return true


## Beim Hehler: ein Stück von `item` verkaufen. true = verkauft.
func sell(item: ItemData) -> bool:
	if not bool(shop.call("is_fence")):
		return false
	var price := int(shop.call("fence_price", item, player))
	if price <= 0:
		return false
	for i in player.inventory.get_size():
		if item.is_same(player.inventory.get_item(i)):
			player.inventory.remove_at(i, 1)
			player.inventory.add_money(price)
			_set_status("%s verkauft (+%d ¢)." % [item.display_name, price], OK_COLOR)
			refresh()
			return true
	return false


func _fill_counter() -> void:
	for child: Node in counter_rows.get_children():
		child.queue_free()
	var list: Array[int] = shop.call("counter_slots")
	if list.is_empty():
		counter_rows.add_child(_label("Vitrine ist leer.", 14, DIM_COLOR))
		return
	for slot: int in list:
		var item: ItemData = shop.call("item_at", slot)
		counter_rows.add_child(_row(item, "%d ¢" % int(shop.call("price_of", item, player)), "Kaufen", buy.bind(slot)))


func _fill_fence() -> void:
	for child: Node in fence_rows.get_children():
		child.queue_free()
	var fence := bool(shop.call("is_fence"))
	fence_title.visible = fence
	fence_rows.visible = fence
	if not fence:
		return
	var seen := {}
	for i in player.inventory.get_size():
		var item := player.inventory.get_item(i)
		if item == null or seen.has(item.id):
			continue
		var price := int(shop.call("fence_price", item, player))
		if price <= 0:
			continue
		seen[item.id] = true
		fence_rows.add_child(_row(item, "+%d ¢" % price, "Verkaufen", sell.bind(item)))
	if seen.is_empty():
		fence_rows.add_child(_label("Nichts, was ich dir abkaufe.", 14, DIM_COLOR))


func _row(item: ItemData, price_text: String, action: String, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var swatch := ColorRect.new()
	swatch.color = item.color
	swatch.custom_minimum_size = Vector2(6, 26)
	row.add_child(swatch)
	var name_label := _label(item.display_name, 16, Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_label(price_text, 16, MONEY_COLOR))
	var button := _button(action)
	button.pressed.connect(func() -> void: callback.call())
	row.add_child(button)
	return row


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
	panel.custom_minimum_size = Vector2(480, 0)
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
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	title_label = _label("LADEN", 24, ORANGE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	header.add_child(_label("BARGELD ", 13, DIM_COLOR))
	cash_label = _label("0 ¢", 18, MONEY_COLOR)
	header.add_child(cash_label)
	box.add_child(_line())
	box.add_child(_label("KASSE", 13, DIM_COLOR))
	var basket := HBoxContainer.new()
	box.add_child(basket)
	basket_label = _label("", 16, Color.WHITE)
	basket_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basket.add_child(basket_label)
	pay_button = _button("Bezahlen")
	pay_button.pressed.connect(func() -> void: pay())
	basket.add_child(pay_button)
	box.add_child(_line())
	box.add_child(_label("THEKE (VITRINE)", 13, DIM_COLOR))
	counter_rows = VBoxContainer.new()
	counter_rows.add_theme_constant_override("separation", 4)
	box.add_child(counter_rows)
	fence_title = _label("VERKAUFEN – WERTSACHEN, KEINE FRAGEN", 13, DIM_COLOR)
	box.add_child(fence_title)
	fence_rows = VBoxContainer.new()
	fence_rows.add_theme_constant_override("separation", 4)
	box.add_child(fence_rows)
	box.add_child(_line())
	var footer := HBoxContainer.new()
	box.add_child(footer)
	status_label = _label("", 14, DIM_COLOR)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(status_label)
	var close_button := _button("Schließen")
	close_button.pressed.connect(close)
	footer.add_child(close_button)


func _line() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(ORANGE, 0.5)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
