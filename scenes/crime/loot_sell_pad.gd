class_name LootSellPad
extends StaticBody3D
## VERKAUFEN-Pult. Nimmt Diebesgut gegen Credchips, halber Grundpreis.
##
## Liegt an Waffenläden und Tankstellen. Der Hehler verkauft weiter über das
## Ladenfenster. Hier ist dasselbe Sortiment, ohne den Laden zu öffnen.

const RATE := 0.5
const SELLABLE: Array[String] = [
	"jewelry", "jewels", "cash_wad", "tv_set", "painting", "computer", "smartphone",
]

var _open := false
var _layer: CanvasLayer
var _rows: VBoxContainer
var _cash: Label
var _player: Player


func _ready() -> void:
	collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 0.22, 0.35)
	shape.shape = box
	shape.position = Vector3(0.0, 0.11, 0.0)
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var pad := BoxMesh.new()
	pad.size = box.size
	mesh.mesh = pad
	mesh.position = shape.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.25)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 1.2
	mesh.material_override = mat
	add_child(mesh)
	var sign := Label3D.new()
	sign.text = "VERKAUFEN"
	sign.position = Vector3(0.0, 0.38, 0.0)
	sign.font_size = 28
	sign.pixel_size = 0.004
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(1.0, 0.9, 0.4)
	add_child(sign)


static func price_for(item: ItemData) -> int:
	if item == null or not SELLABLE.has(item.id):
		return 0
	return maxi(int(float(item.value) * RATE), 1)


static func sell_one(inventory: Inventory, item: ItemData) -> int:
	var price := price_for(item)
	if price <= 0 or inventory == null:
		return 0
	for i in inventory.get_size():
		if item.is_same(inventory.get_item(i)):
			inventory.remove_at(i, 1)
			inventory.add_money(price)
			return price
	return 0


func get_interact_text(_player: Player) -> String:
	return "VERKAUFEN"


func interact(player: Player) -> void:
	if player == null or not player.controls_local_body():
		return
	if _open:
		_close()
		return
	_player = player
	_open = true
	player.open_panel = self
	player.input_locked = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ensure_ui()
	_layer.visible = true
	_refresh()


func _ensure_ui() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "SellLayer"
	_layer.layer = 16
	add_child(_layer)
	var root := Control.new()
	root.name = "SellRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)
	var panel := PanelContainer.new()
	panel.name = "SellPanel"
	panel.unique_name_in_owner = true
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 280)
	panel.position = Vector2(-210, -160)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "SellBox"
	panel.add_child(box)
	var title := Label.new()
	title.name = "SellTitle"
	title.unique_name_in_owner = true
	title.text = "VERKAUFEN"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	_cash = Label.new()
	_cash.name = "SellCash"
	_cash.unique_name_in_owner = true
	_cash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_cash)
	var scroll := ScrollContainer.new()
	scroll.name = "SellScroll"
	scroll.unique_name_in_owner = true
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var close := Button.new()
	close.name = "SellClose"
	close.unique_name_in_owner = true
	close.text = "Schließen"
	close.pressed.connect(_close)
	box.add_child(close)


func _refresh() -> void:
	if _player == null or _rows == null:
		return
	_cash.text = "Bargeld  %d ¢" % _player.inventory.money
	for child in _rows.get_children():
		child.queue_free()
	var seen := {}
	for i in _player.inventory.get_size():
		var item := _player.inventory.get_item(i)
		if item == null or seen.has(item.id):
			continue
		var price := price_for(item)
		if price <= 0:
			continue
		seen[item.id] = true
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = "%s  +%d ¢" % [item.display_name, price]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)
		var button := Button.new()
		button.text = "VERKAUFEN"
		var sold := item
		button.pressed.connect(func() -> void: _sell(sold))
		row.add_child(button)
		_rows.add_child(row)
	if seen.is_empty():
		var empty := Label.new()
		empty.text = "Nichts Verkäufliches im Inventar."
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(empty)


func _sell(item: ItemData) -> void:
	if _player == null:
		return
	var price := sell_one(_player.inventory, item)
	if price > 0 and _player.item_user != null:
		_player.item_user.show_message("Verkauft +%d ¢" % price, Color(0.4, 1.0, 0.7))
	_refresh()


func _close() -> void:
	_open = false
	if _layer != null:
		_layer.visible = false
	if _player != null:
		if _player.open_panel == self:
			_player.open_panel = null
		_player.input_locked = false
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player = null
