extends CanvasLayer
## HUD im Spiel: Fadenkreuz, Hotbar unten und das Inventar-Fenster.
##
## Inventar-Taste (Standard Tab) öffnet/schließt das Fenster, Esc schließt es.
## Solange es offen ist, ist die Maus frei und der Spieler steht still.
## Ein Item aus dem Fenster heraus ziehen = in die Welt fallen lassen.
## Oben zwei Reiter: INVENTAR und SKILLS (SkillTreeView, Punkte in drei Skill-Bäume verteilen).

const SkillTreeViewScript := preload("res://scenes/inventory/skill_tree_view.gd")
const TAB_INVENTORY := 0
const TAB_SKILLS := 1

## Hängt als Kind am Player (player.tscn), damit jede Map mit Player auch das HUD hat.
@onready var player: Player = get_parent()

var inventory: Inventory
## Reiter „Skills“ (im Code angelegt).
var skill_view: SkillTreeViewScript
var tab := TAB_INVENTORY

var _name_tween: Tween
var _tab_buttons: Array[Button] = []
## Teile des Fensters, die nur im Inventar-Reiter zu sehen sind.
var _inventory_parts: Array[Control] = []

@onready var hotbar: HBoxContainer = %Hotbar
@onready var item_name: Label = %ItemName
@onready var feed: VBoxContainer = %Feed
@onready var overlay: Control = %InventoryOverlay
@onready var backpack_grid: GridContainer = %BackpackGrid
@onready var panel_hotbar: HBoxContainer = %PanelHotbar
@onready var info_name: Label = %InfoName
@onready var info_description: Label = %InfoDescription


func _ready() -> void:
	# Zuerst schließen: Bricht _ready unten ab (z. B. fehlender Inventory-Knoten),
	# darf kein leeres Fenster stehen bleiben, das sich nicht schließen lässt.
	overlay.visible = false
	inventory = player.get_node_or_null(^"Inventory") as Inventory
	if inventory == null:
		push_error("InventoryUI: Player hat keinen Kindknoten \"Inventory\" (player.tscn prüfen).")
		hotbar.hide()
		return
	# Slots erst, wenn die Daten da sind. Inventory steht in player.tscn vor diesem HUD;
	# ist die Reihenfolge einmal anders, warten wir auf ready statt leere Arrays zu lesen.
	if not inventory.is_node_ready():
		await inventory.ready
	_build_slots()
	_build_tabs()

	# Ablegen neben dem Fenster (auf dem abgedunkelten Hintergrund) wirft das Item weg.
	overlay.set_drag_forwarding(Callable(), _can_drop_outside, _drop_outside)

	inventory.selected_changed.connect(func(_i: int) -> void: _flash_item_name())
	inventory.changed.connect(_refresh_info.bind(-1))
	inventory.item_added.connect(_on_item_added)

	item_name.modulate.a = 0.0
	_set_open(false)


func _process(_delta: float) -> void:
	# Zu, aber die Sperre klebt noch: dann wieder laufen lassen. Die Fläche fängt nichts.
	if player == null or overlay == null or overlay.visible or get_tree().paused \
			or player.open_panel != null:
		return
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.input_locked = false


func force_close() -> void:
	if overlay == null or not overlay.visible:
		if player != null:
			player.input_locked = false
		return
	_set_open(false)


func _input(event: InputEvent) -> void:
	# Echo würde Tab auf- und wieder zuklappen. Bei Pause bleibt das Inventar zu
	# (dieses HUD erbt den Prozessmodus und läuft im angehaltenen Baum nicht).
	if event.is_echo() or get_tree().paused or inventory == null or player.open_panel != null:
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
	# Geschlossen darf die volle Fläche keine Maus fangen, auch nicht bei 2K/4K.
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	hotbar.visible = not open
	player.input_locked = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	_attach_skills()
	_refresh_info(-1)


## Reiterleiste über dem Fenster und die Skill-Ansicht (anfangs versteckt).
func _build_tabs() -> void:
	var layout := info_name.get_parent() as Container
	for child: Node in layout.get_children():
		if child != info_name and child != info_description and child is Control:
			_inventory_parts.append(child as Control)
	var bar := HBoxContainer.new()
	bar.name = "Tabs"
	bar.add_theme_constant_override("separation", 6)
	layout.add_child(bar)
	layout.move_child(bar, 0)
	for i in 2:
		var button := Button.new()
		button.name = "InventoryTab" if i == TAB_INVENTORY else "SkillsTab"
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(150, 30)
		button.add_theme_font_size_override("font_size", 15)
		_style_tab(button)
		button.pressed.connect(set_tab.bind(i))
		bar.add_child(button)
		_tab_buttons.append(button)
	skill_view = SkillTreeViewScript.new()
	skill_view.name = "SkillTree"
	skill_view.visible = false
	skill_view.hovered.connect(_on_skill_hovered)
	layout.add_child(skill_view)
	_update_tabs()


func _style_tab(button: Button) -> void:
	var cyan := Color(0.0, 0.95, 1.0)
	var magenta := Color(1.0, 0.1, 0.75)
	for style_name: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		var active := style_name.contains("pressed")
		box.bg_color = Color(magenta, 0.22) if active else Color(0.05, 0.0, 0.12, 0.9)
		if style_name == "hover":
			box.bg_color = Color(cyan, 0.12)
		box.border_color = magenta if active else Color(cyan, 0.5)
		box.set_border_width_all(0)
		box.border_width_bottom = 2
		box.border_width_top = 1 if active else 0
		box.corner_detail = 1
		box.skew = Vector2(0.18, 0.0)
		box.content_margin_left = 14
		box.content_margin_right = 14
		button.add_theme_stylebox_override(style_name, box)
	button.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.75))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)


## Player.skills entsteht erst nach diesem HUD (Player._ready läuft nach den Kindern).
func _attach_skills() -> void:
	if skill_view == null or player == null or player.skills == null or skill_view.skills == player.skills:
		return
	skill_view.skills = player.skills
	player.skills.changed.connect(_update_tabs)
	_update_tabs()


## Reiter wechseln (TAB_INVENTORY oder TAB_SKILLS).
func set_tab(value: int) -> void:
	tab = clampi(value, TAB_INVENTORY, TAB_SKILLS)
	_attach_skills()
	_update_tabs()
	_refresh_info(-1)


func _update_tabs() -> void:
	if skill_view == null:
		return
	var skills_open := tab == TAB_SKILLS
	for part: Control in _inventory_parts:
		part.visible = not skills_open
	skill_view.visible = skills_open
	var free: int = player.skills.points_free() if player != null and player.skills != null else 0
	_tab_buttons[TAB_INVENTORY].text = "INVENTAR"
	_tab_buttons[TAB_SKILLS].text = "SKILLS  [%d]" % free if free > 0 else "SKILLS"
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == tab)


func _on_skill_hovered(id: StringName) -> void:
	if tab != TAB_SKILLS:
		return
	if id == &"" or not SkillTreeViewScript.PlayerSkillsScript.SKILLS.has(id):
		_refresh_info(-1)
		return
	var data: Dictionary = SkillTreeViewScript.PlayerSkillsScript.SKILLS[id]
	info_name.text = "> " + str(data["name"]).to_upper()
	var req_names := PackedStringArray()
	for req: StringName in data["requires"]:
		req_names.append(str(SkillTreeViewScript.PlayerSkillsScript.SKILLS[req]["name"]))
	var line := str(data["description"])
	if not req_names.is_empty():
		line += "  //  Braucht: " + ", ".join(req_names)
	info_description.text = line


func _add_slot(parent: Control, index: int, show_number: bool, interactive: bool) -> void:
	var slot := InventorySlot.new()
	slot.setup(inventory, index, show_number, interactive)
	slot.hovered.connect(_refresh_info)
	parent.add_child(slot)


func _refresh_info(index: int) -> void:
	if tab == TAB_SKILLS:
		info_name.text = "> SKILLS"
		info_description.text = "Drei Bäume: Kampf, Bewegung, Stealth. Ein Skill braucht die verbundenen darüber."
		return
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
