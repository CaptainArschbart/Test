extends Control
## Reiter „Skills“ im Inventar-Fenster (InventoryUI): drei Bäume nebeneinander, je drei Stufen.
## Linien verbinden einen Skill mit seinen Voraussetzungen. Zustände wie PlayerSkills.state_of:
## gelernt (gefüllt, leuchtend), freischaltbar (Rand pulsiert, Klick lernt), ohne Punkt (Rand
## gedämpft) und gesperrt (grau). Unten stehen die freien Punkte.
## Farben wie XpHud (Violett, Cyan, Magenta). Ohne class_name, InventoryUI lädt das Skript per preload.

## Maus über einem Skill (leer = keiner). InventoryUI zeigt dann Name und Wirkung.
signal hovered(id: StringName)

const PlayerSkillsScript := preload("res://scenes/player/player_skills.gd")
const PANEL_COLOR := Color(0.03, 0.0, 0.08, 0.84)
const CYAN := Color(0.0, 0.95, 1.0, 1.0)
const MAGENTA := Color(1.0, 0.1, 0.75, 1.0)
const XP_COLOR := Color(0.55, 1.0, 0.35, 1.0)
const TEXT_COLOR := Color(0.95, 0.97, 1.0, 1.0)
const LOCKED_COLOR := Color(0.45, 0.45, 0.58, 1.0)
const TREE_COLORS := {&"combat": MAGENTA, &"movement": XP_COLOR, &"stealth": CYAN}
const VIEW_SIZE := Vector2(624.0, 330.0)
const NODE_SIZE := Vector2(92.0, 56.0)
const HEADER := 30.0
const TIER_GAP := 88.0
const CHAMFER := 8.0
const COLUMN_PAD := 8.0

var skills: PlayerSkillsScript:
	set(value):
		if skills != null and skills.changed.is_connected(queue_redraw):
			skills.changed.disconnect(queue_redraw)
		skills = value
		if skills != null:
			skills.changed.connect(queue_redraw)
		queue_redraw()

var _hover: StringName = &""
var _time := 0.0


func _ready() -> void:
	custom_minimum_size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void: _set_hover(&""))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


## Fläche eines Skills in lokalen Koordinaten.
func rect_of(id: StringName) -> Rect2:
	var data: Dictionary = skills_data()[id]
	var tree_index: int = skills_trees().find(data["tree"])
	var column_width := VIEW_SIZE.x / 3.0
	var left := column_width * tree_index + COLUMN_PAD
	var span := column_width - COLUMN_PAD * 2.0 - NODE_SIZE.x
	var x := left + span * float(data["column"])
	var y := HEADER + 8.0 + TIER_GAP * int(data["tier"])
	return Rect2(Vector2(x, y), NODE_SIZE)


func skill_at(point: Vector2) -> StringName:
	for id: StringName in skills_data():
		if rect_of(id).has_point(point):
			return id
	return &""


## Klick auf einen Skill: lernen, wenn möglich. true = gelernt.
func press(id: StringName) -> bool:
	if skills == null or id == &"":
		return false
	return skills.learn(id)


func skills_data() -> Dictionary:
	return PlayerSkillsScript.SKILLS


func skills_trees() -> Array:
	return PlayerSkillsScript.TREES


func _gui_input(event: InputEvent) -> void:
	if skills == null:
		return
	if event is InputEventMouseMotion:
		_set_hover(skill_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := skill_at(event.position)
		if id != &"":
			press(id)
			hovered.emit(id)
			accept_event()


func _set_hover(id: StringName) -> void:
	if id == _hover:
		return
	_hover = id
	hovered.emit(id)
	queue_redraw()


func _draw() -> void:
	if skills == null:
		return
	var font := get_theme_default_font()
	var column_width := VIEW_SIZE.x / 3.0
	var trees := skills_trees()
	for i in trees.size():
		var tree: StringName = trees[i]
		var color: Color = TREE_COLORS.get(tree, CYAN)
		var x0 := column_width * i
		# Kopf: Name und gelernte Skills im Baum.
		var count := 0
		var total := 0
		for id: StringName in skills_data():
			if skills_data()[id]["tree"] == tree:
				total += 1
				if skills.has(id):
					count += 1
		draw_string(font, Vector2(x0 + COLUMN_PAD, 16.0), "// " + str(PlayerSkillsScript.TREE_NAMES[tree]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
		draw_string(font, Vector2(x0 + COLUMN_PAD, 16.0), "%d/%d" % [count, total],
			HORIZONTAL_ALIGNMENT_RIGHT, column_width - COLUMN_PAD * 2.0, 11, Color(color, 0.7))
		draw_line(Vector2(x0 + COLUMN_PAD, 23.0), Vector2(x0 + column_width - COLUMN_PAD, 23.0), Color(color, 0.35), 1.0)
		if i > 0:
			draw_line(Vector2(x0, 4.0), Vector2(x0, VIEW_SIZE.y - 40.0), Color(CYAN, 0.12), 1.0)
	# Verbindungen zuerst, damit die Knoten darüber liegen.
	for id: StringName in skills_data():
		var target := rect_of(id)
		var color: Color = TREE_COLORS.get(skills_data()[id]["tree"], CYAN)
		for req: StringName in skills_data()[id]["requires"]:
			var source := rect_of(req)
			var from := Vector2(source.get_center().x, source.end.y)
			var to := Vector2(target.get_center().x, target.position.y)
			var mid_y := (from.y + to.y) * 0.5
			var points := PackedVector2Array([from, Vector2(from.x, mid_y), Vector2(to.x, mid_y), to])
			var on: bool = skills.has(req)
			var line_color := Color(color, 0.85) if on else Color(LOCKED_COLOR, 0.45)
			if on and skills.has(id):
				draw_polyline(points, Color(color, 0.25), 5.0)
			draw_polyline(points, line_color, 2.0 if on else 1.0)
	for id: StringName in skills_data():
		_draw_node(id, font)
	_draw_points(font)


func _draw_node(id: StringName, font: Font) -> void:
	var data: Dictionary = skills_data()[id]
	var r := rect_of(id)
	var color: Color = TREE_COLORS.get(data["tree"], CYAN)
	var state: String = skills.state_of(id)
	var c := CHAMFER
	var shape := PackedVector2Array([
		r.position + Vector2(c, 0.0), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - c),
		r.end - Vector2(c, 0.0), Vector2(r.position.x, r.end.y), r.position + Vector2(0.0, c),
	])
	var outline := shape.duplicate()
	outline.append(shape[0])
	var hover := id == _hover
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var fill := PANEL_COLOR
	var edge := Color(LOCKED_COLOR, 0.5)
	var text := Color(LOCKED_COLOR, 0.8)
	var status := "GESPERRT"
	match state:
		"learned":
			fill = Color(color, 0.28)
			edge = color
			text = TEXT_COLOR
			status = "GELERNT"
		"available":
			fill = Color(0.06, 0.0, 0.14, 0.92)
			edge = Color(CYAN, 0.55 + 0.45 * pulse)
			text = TEXT_COLOR
			status = "+ LERNEN"
		"unlocked":
			fill = Color(0.05, 0.0, 0.11, 0.9)
			edge = Color(CYAN, 0.45)
			text = Color(TEXT_COLOR, 0.8)
			status = "KEIN PUNKT"
	if hover:
		fill = fill.lightened(0.08)
	draw_colored_polygon(shape, fill)
	if state == "learned" or (state == "available" and hover):
		draw_polyline(outline, Color(edge, 0.25), 6.0)
	draw_polyline(outline, edge, 2.0 if hover or state == "learned" else 1.0)
	# Stufen-Kerbe oben links, wie das Abzeichen der XP-Leiste.
	draw_colored_polygon(PackedVector2Array([
		r.position + Vector2(c, 0.0), r.position + Vector2(c + 18.0, 0.0), r.position + Vector2(c + 14.0, 4.0),
		r.position + Vector2(c - 4.0, 4.0),
	]), Color(color, 0.9) if state != "locked" else Color(LOCKED_COLOR, 0.5))
	draw_string(font, r.position + Vector2(4.0, 26.0), str(data["name"]), HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x - 8.0, 12, text)
	var status_color := MAGENTA if state == "available" else (Color(color, 0.9) if state == "learned" else Color(text, 0.6))
	draw_string(font, r.position + Vector2(4.0, 44.0), status, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8.0, 9, status_color)


## Unten: Abzeichen mit den freien Punkten und ein Hinweis.
func _draw_points(font: Font) -> void:
	var y := VIEW_SIZE.y - 30.0
	var w := 150.0
	var h := 26.0
	var c := 8.0
	var free: int = skills.points_free()
	var shape := PackedVector2Array([
		Vector2(c, y), Vector2(w, y), Vector2(w, y + h - c), Vector2(w - c, y + h), Vector2(0.0, y + h), Vector2(0.0, y + c),
	])
	var outline := shape.duplicate()
	outline.append(shape[0])
	var glow := 0.5 + 0.5 * sin(_time * 4.0) if free > 0 else 0.0
	draw_colored_polygon(shape, Color(MAGENTA, 0.16 + 0.14 * glow))
	draw_polyline(outline, Color(MAGENTA, 0.6 + 0.4 * glow), 1.0)
	draw_string(font, Vector2(10.0, y + 17.0), "FREIE PUNKTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(MAGENTA, 0.95))
	draw_string(font, Vector2(10.0, y + 19.0), str(free), HORIZONTAL_ALIGNMENT_RIGHT, w - 20.0, 18, TEXT_COLOR)
	var hint := "Stufe %d  //  1 Punkt pro Stufenaufstieg  //  Klick lernt einen Skill" % skills.level
	draw_string(font, Vector2(w + 14.0, y + 17.0), hint, HORIZONTAL_ALIGNMENT_LEFT, VIEW_SIZE.x - w - 14.0, 11, Color(CYAN, 0.7))
