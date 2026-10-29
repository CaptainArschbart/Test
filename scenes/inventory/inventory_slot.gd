class_name InventorySlot
extends Control
## Ein Slot in Hotbar oder Inventar. Zeichnet sich selbst im Neon-Stil und
## kann per Drag & Drop verschoben werden (nur wenn `interactive`).

## Maus ist über dem Slot (für die Info-Zeile im Inventar). -1 = verlassen.
signal hovered(index: int)

const CYAN := Color(0, 0.95, 1)
const MAGENTA := Color(1, 0.1, 0.75)
const BG := Color(0.02, 0.0, 0.06, 0.78)
const SLOT_SIZE := Vector2(64, 64)

var inventory: Inventory
var index := 0
## Slot-Nummer oben links anzeigen (Hotbar).
var show_number := false
## Ziehen, Ablegen und Rechtsklick erlaubt.
var interactive := false

var _hover := false
## Nur für die Drag-Vorschau: zeigt dieses Item statt eines Inventar-Slots.
var _preview_item: ItemData
var _preview_count := 0


func _init() -> void:
	custom_minimum_size = SLOT_SIZE
	focus_mode = Control.FOCUS_NONE


func setup(p_inventory: Inventory, p_index: int, p_show_number: bool, p_interactive: bool) -> void:
	inventory = p_inventory
	index = p_index
	show_number = p_show_number
	interactive = p_interactive
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	inventory.changed.connect(queue_redraw)
	inventory.selected_changed.connect(func(_i: int) -> void: queue_redraw())
	if show_number and not Settings.changed.is_connected(queue_redraw):
		Settings.changed.connect(queue_redraw)


func _ready() -> void:
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _draw() -> void:
	var item := _item()
	var rect := Rect2(Vector2.ZERO, size)
	var selected := inventory != null and show_number and inventory.selected == index
	var border := MAGENTA if selected or _hover else Color(CYAN, 0.55)

	draw_rect(rect, BG)
	if selected:
		draw_rect(rect.grow(3), Color(MAGENTA, 0.25), false, 6.0)
	draw_rect(rect, border, false, 2.0 if selected else 1.0)
	# Abgeschnittene Ecke unten rechts, wie bei den Menü-Knöpfen der Neon-Look.
	var c := size.x * 0.18
	draw_line(Vector2(size.x - c, size.y), Vector2(size.x, size.y - c), border, 2.0)

	var font := get_theme_default_font()
	if show_number:
		var key_text := _bound_key_label()
		var key_size := 12 if key_text.length() <= 2 else 10
		draw_string(font, Vector2(4, 14), key_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, key_size,
			MAGENTA if selected else Color(CYAN, 0.7))
	if item == null:
		return

	var center := size / 2.0
	if item.icon:
		var icon_size := size * 0.7
		draw_texture_rect(item.icon, Rect2(center - icon_size / 2.0, icon_size), false)
	elif item is ConsumableData and ConsumableModel.has_model(item.model):
		ConsumableModel.draw_icon(self, item.model, center, size.x, item.color)
	else:
		var r := size.x * 0.3
		var diamond := PackedVector2Array([
			center + Vector2(0, -r), center + Vector2(r, 0),
			center + Vector2(0, r), center + Vector2(-r, 0),
		])
		draw_colored_polygon(diamond, Color(item.color, 0.25))
		diamond.append(diamond[0])
		draw_polyline(diamond, item.color, 2.0, true)
		var glyph_size := 18 if item.glyph.length() <= 2 else 13
		draw_string(font, center + Vector2(-r, glyph_size * 0.35), item.glyph,
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, glyph_size, Color.WHITE)

	var count := _count()
	if count > 1:
		draw_string_outline(font, Vector2(0, size.y - 5), str(count),
			HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6, 15, 4, Color.BLACK)
		draw_string(font, Vector2(0, size.y - 5), str(count),
			HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6, 15, Color.WHITE)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not interactive or _item() == null:
		return null
	var preview := InventorySlot.new()
	preview._preview_item = _item()
	preview._preview_count = _count()
	preview.size = SLOT_SIZE
	preview.position = -SLOT_SIZE / 2.0
	preview.modulate.a = 0.85
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"type": "inventory_slot", "index": index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return interactive and data is Dictionary and data.get("type") == "inventory_slot"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from := int((data as Dictionary).get("index", -1))
	if from < 0:
		return
	inventory.move(from, index)


func _gui_input(event: InputEvent) -> void:
	if interactive and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		inventory.quick_move(index)
		hovered.emit(index)
		accept_event()


## Angezeigte Taste aus der Input Map (Settings), nicht die feste Ziffer 1–9.
func _bound_key_label() -> String:
	var action := "hotbar_%d" % (index + 1)
	var code: int = int(Settings.key_bindings.get(action, KEY_NONE))
	if code == KEY_NONE:
		return str(index + 1)
	return Settings.key_name(code)


func _item() -> ItemData:
	return _preview_item if inventory == null else inventory.get_item(index)


func _count() -> int:
	return _preview_count if inventory == null else inventory.get_count(index)


func _set_hover(value: bool) -> void:
	_hover = value
	hovered.emit(index if value else -1)
	queue_redraw()
