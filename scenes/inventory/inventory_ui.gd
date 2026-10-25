extends CanvasLayer
## HUD im Spiel: Fadenkreuz, Hotbar unten und das Inventar-Fenster.
##
## Inventar-Taste (Standard Tab) öffnet/schließt das Fenster, Esc schließt es.
## Solange es offen ist, ist die Maus frei und der Spieler steht still.
## Ein Item aus dem Fenster heraus ziehen = in die Welt fallen lassen.

## Hängt als Kind am Player (player.tscn), damit jede Map mit Player auch das HUD hat.
@onready var player: Player = get_parent()

var inventory: Inventory

var _name_tween: Tween

@onready var hotbar: HBoxContainer = %Hotbar
@onready var item_name: Label = %ItemName
@onready var feed: VBoxContainer = %Feed
@onready var overlay: Control = %InventoryOverlay
@onready var backpack_grid: GridContainer = %BackpackGrid
@onready var panel_hotbar: HBoxContainer = %PanelHotbar
@onready var info_name: Label = %InfoName
@onready var info_description: Label = %InfoDescription


func _ready() -> void:
	inventory = player.get_node(^"Inventory") as Inventory
	# Slots erst, wenn die Daten da sind. Inventory steht in player.tscn vor diesem HUD;
	# ist die Reihenfolge einmal anders, warten wir auf ready statt leere Arrays zu lesen.
	if not inventory.is_node_ready():
		await inventory.ready
	_build_slots()

	# Ablegen neben dem Fenster (auf dem abgedunkelten Hintergrund) wirft das Item weg.
	overlay.set_drag_forwarding(Callable(), _can_drop_outside, _drop_outside)

	inventory.selected_changed.connect(func(_i: int) -> void: _flash_item_name())
	inventory.changed.connect(_refresh_info.bind(-1))
	inventory.item_added.connect(_on_item_added)

	item_name.modulate.a = 0.0
	_set_open(false)


func _input(event: InputEvent) -> void:
	# Echo würde Tab auf- und wieder zuklappen. Bei Pause bleibt das Inventar zu
	# (dieses HUD erbt den Prozessmodus und läuft im angehaltenen Baum nicht).
	if event.is_echo() or get_tree().paused:
		return
	if event.is_action_pressed("inventory"):
		_set_open(not overlay.visible)
		get_viewport().set_input_as_handled()
	elif overlay.visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _build_slots() -> void:
	for i: int in Inventory.HOTBAR_SIZE:
		_add_slot(hotbar, i, true, false)
		_add_slot(panel_hotbar, i, true, true)
	for i: int in range(Inventory.HOTBAR_SIZE, inventory.get_size()):
		_add_slot(backpack_grid, i, false, true)
	backpack_grid.columns = Inventory.HOTBAR_SIZE


func _set_open(open: bool) -> void:
	overlay.visible = open
	hotbar.visible = not open
	player.input_locked = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	_refresh_info(-1)


func _add_slot(parent: Control, index: int, show_number: bool, interactive: bool) -> void:
	var slot := InventorySlot.new()
	slot.setup(inventory, index, show_number, interactive)
	slot.hovered.connect(_refresh_info)
	parent.add_child(slot)


func _refresh_info(index: int) -> void:
	var item := inventory.get_item(index) if index >= 0 else null
	if item == null:
		info_name.text = "> INVENTAR"
		info_description.text = "Ziehen = verschieben  //  Rechtsklick = Hotbar ↔ Rucksack  //  aus dem Fenster ziehen = fallen lassen"
		return
	info_name.text = "> " + item.display_name.to_upper()
	info_description.text = item.description


func _flash_item_name() -> void:
	var item := inventory.get_selected_item()
	item_name.text = item.display_name if item else ""
	if _name_tween:
		_name_tween.kill()
	item_name.modulate.a = 1.0
	_name_tween = create_tween()
	_name_tween.tween_interval(1.5)
	_name_tween.tween_property(item_name, "modulate:a", 0.0, 0.5)


func _on_item_added(item: ItemData, amount: int) -> void:
	var label := Label.new()
	label.text = "+%d  %s" % [amount, item.display_name]
	label.add_theme_color_override("font_color", item.color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)
	feed.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
	if item.is_same(inventory.get_selected_item()):
		_flash_item_name()


func _can_drop_outside(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "inventory_slot"


func _drop_outside(_at_position: Vector2, data: Variant) -> void:
	var from := int((data as Dictionary).get("index", -1))
	if from < 0:
		return
	player.drop_item(from, inventory.get_count(from))
