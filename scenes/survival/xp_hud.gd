extends CanvasLayer
## XP-Leiste oben mittig, im Stil der Vitals- und Stealth-Boxen (Violett, Cyan-Rand, Magenta).
## Links das Stufen-Abzeichen, daneben die segmentierte Leiste, rechts "120 / 160 XP".
## Bei XP-Gewinn läuft die Leiste hoch und "+25 XP" steigt darunter auf; bei Stufenaufstieg
## läuft sie voll, beginnt neu und "STUFE 3" blinkt unter der Leiste.
## Der Player legt den Knoten im Code an und setzt `xp` (PlayerXp). Ohne class_name.

const PANEL_COLOR := Color(0.03, 0.0, 0.08, 0.84)
const CYAN := Color(0.0, 0.95, 1.0, 1.0)
const MAGENTA := Color(1.0, 0.1, 0.75, 1.0)
const XP_COLOR := Color(0.55, 1.0, 0.35, 1.0)
const TEXT_COLOR := Color(0.95, 0.97, 1.0, 1.0)
## Größe in der 1280×720-Basis, mittig oben.
const PANEL_SIZE := Vector2(380.0, 34.0)
const TOP := 12.0
const CHAMFER := 10.0
const BADGE_WIDTH := 52.0
const SEGMENTS := 20
## Stufen pro Sekunde, mit denen die Leiste dem echten Stand folgt.
const FILL_SPEED := 1.6

var xp: Node:
	set(value):
		xp = value
		if xp != null:
			xp.xp_changed.connect(_on_xp_changed)
			xp.leveled_up.connect(_on_leveled_up)
			_shown = _target()
			_refresh_text()

var panel: Control
var level_label: Label
var amount_label: Label
var _gain_label: Label
var _level_up_label: Label
## Angezeigter Stand: Stufe + Anteil (2,4 = Stufe 2, 40 %). Läuft dem echten Stand nach.
var _shown := 1.0
var _flash := 0.0
var _gain_tween: Tween
var _level_tween: Tween


func _ready() -> void:
	layer = 2
	panel = Control.new()
	panel.name = "XpBar"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = TOP
	panel.offset_bottom = TOP + PANEL_SIZE.y
	panel.draw.connect(_draw_panel)
	add_child(panel)
	level_label = _make_label(Vector2(8.0, 9.0), Vector2(BADGE_WIDTH - 8.0, 24.0), 17, TEXT_COLOR)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_color_override("font_outline_color", Color(MAGENTA, 0.55))
	level_label.add_theme_constant_override("outline_size", 3)
	amount_label = _make_label(Vector2(BADGE_WIDTH + 10.0, 1.0), Vector2(PANEL_SIZE.x - BADGE_WIDTH - 24.0, 14.0), 9, Color(CYAN, 0.75))
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gain_label = _make_label(Vector2(0.0, PANEL_SIZE.y + 2.0), Vector2(PANEL_SIZE.x, 18.0), 14, XP_COLOR)
	_gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gain_label.add_theme_color_override("font_outline_color", PANEL_COLOR)
	_gain_label.add_theme_constant_override("outline_size", 4)
	_gain_label.modulate.a = 0.0
	_level_up_label = _make_label(Vector2(0.0, PANEL_SIZE.y + 18.0), Vector2(PANEL_SIZE.x, 26.0), 20, MAGENTA)
	_level_up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_up_label.add_theme_color_override("font_outline_color", PANEL_COLOR)
	_level_up_label.add_theme_constant_override("outline_size", 5)
	_level_up_label.modulate.a = 0.0
	_refresh_text()


func _make_label(pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = pos
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	# Label erzwingt sonst die Höhe seiner Schrift; die Größe erst nach add_child setzen.
	label.size = label_size
	return label


func _target() -> float:
	if xp == null:
		return 1.0
	var need: int = xp.needed()
	return float(xp.level) + (float(xp.xp) / float(need) if need > 0 else 0.0)


func _on_xp_changed(_level: int, _xp: int, _needed: int, gained: int) -> void:
	_refresh_text()
	_gain_label.text = "+%d XP" % gained
	_gain_label.modulate.a = 1.0
	_gain_label.position.y = PANEL_SIZE.y + 2.0
	_flash = 1.0
	if _gain_tween:
		_gain_tween.kill()
	_gain_tween = create_tween().set_parallel(true)
	_gain_tween.tween_property(_gain_label, "position:y", PANEL_SIZE.y - 4.0, 1.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_gain_tween.tween_property(_gain_label, "modulate:a", 0.0, 0.5).set_delay(0.9)


func _on_leveled_up(new_level: int) -> void:
	_level_up_label.text = "STUFE %d  //  +1 SKILLPUNKT (Tab)" % new_level
	_level_up_label.modulate.a = 1.0
	if _level_tween:
		_level_tween.kill()
	_level_tween = create_tween()
	for i in 3:
		_level_tween.tween_property(_level_up_label, "modulate:a", 0.35, 0.18)
		_level_tween.tween_property(_level_up_label, "modulate:a", 1.0, 0.18)
	_level_tween.tween_interval(1.2)
	_level_tween.tween_property(_level_up_label, "modulate:a", 0.0, 0.6)


func _refresh_text() -> void:
	if level_label == null:
		return
	if xp == null:
		level_label.text = "1"
		amount_label.text = "0 / %d XP" % 100
		return
	level_label.text = str(int(floorf(_shown)))
	amount_label.text = "%d / %d XP" % [xp.xp, xp.needed()]


func _process(delta: float) -> void:
	var target := _target()
	if not is_equal_approx(_shown, target):
		_shown = move_toward(_shown, target, FILL_SPEED * delta * maxf(1.0, target - _shown))
		var shown_level := str(int(floorf(_shown)))
		if level_label.text != shown_level:
			level_label.text = shown_level
	_flash = maxf(_flash - delta * 1.6, 0.0)
	panel.queue_redraw()


func _draw_panel() -> void:
	var w := PANEL_SIZE.x
	var h := PANEL_SIZE.y
	var c := CHAMFER
	# Beide Seiten abgeschrägt, damit die Leiste mittig symmetrisch wirkt.
	var shape := PackedVector2Array([
		Vector2(c, 0.0), Vector2(w - c, 0.0), Vector2(w, c),
		Vector2(w - c, h), Vector2(c, h), Vector2(0.0, h - c),
	])
	panel.draw_colored_polygon(shape, PANEL_COLOR)
	var y := 2.0
	while y < h - 1.0:
		panel.draw_line(Vector2(c, y), Vector2(w - c, y), Color(1.0, 1.0, 1.0, 0.025), 1.0)
		y += 3.0
	var edge := CYAN.lerp(XP_COLOR, _flash)
	var outline := shape.duplicate()
	outline.append(shape[0])
	panel.draw_polyline(outline, Color(edge, 0.12 + 0.25 * _flash), 5.0)
	panel.draw_polyline(outline, Color(edge, 0.5 + 0.4 * _flash), 1.0)
	# Abzeichen links: Magenta-Feld mit "LVL" und der Stufe (level_label).
	var badge := PackedVector2Array([
		Vector2(c + 2.0, 3.0), Vector2(BADGE_WIDTH, 3.0), Vector2(BADGE_WIDTH - 6.0, h - 3.0),
		Vector2(c + 2.0, h - 3.0), Vector2(4.0, h - c),
	])
	panel.draw_colored_polygon(badge, Color(MAGENTA, 0.18 + 0.2 * _flash))
	var badge_edge := badge.duplicate()
	badge_edge.append(badge[0])
	panel.draw_polyline(badge_edge, Color(MAGENTA, 0.8), 1.0)
	var font := panel.get_theme_default_font()
	panel.draw_string(font, Vector2(8.0, 12.0), "LVL", HORIZONTAL_ALIGNMENT_CENTER, BADGE_WIDTH - 8.0, 8, Color(MAGENTA, 0.95))
	panel.draw_string(font, Vector2(BADGE_WIDTH + 10.0, 12.0), "ERFAHRUNG", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, TEXT_COLOR)
	# Segmentierte Leiste.
	var bar := Rect2(BADGE_WIDTH + 10.0, 17.0, w - BADGE_WIDTH - 24.0, 9.0)
	var ratio := _shown - floorf(_shown)
	var gap := 2.0
	var seg_w := (bar.size.x - gap * (SEGMENTS - 1)) / SEGMENTS
	var slant := 3.0
	for i in SEGMENTS:
		var x0 := bar.position.x + i * (seg_w + gap)
		var fill := clampf(ratio * SEGMENTS - i, 0.0, 1.0)
		var seg := _slanted(x0, bar.position.y, seg_w, bar.size.y, slant)
		panel.draw_colored_polygon(seg, Color(CYAN, 0.1))
		if seg_w * fill > 0.5:
			var t := float(i) / (SEGMENTS - 1)
			var color := CYAN.lerp(XP_COLOR, t).lerp(Color.WHITE, _flash * 0.5)
			panel.draw_colored_polygon(_slanted(x0, bar.position.y, seg_w * fill, bar.size.y, slant * fill), color)
	# Leuchtende Spitze am Füllstand.
	if ratio > 0.0:
		var tip_x := bar.position.x + ratio * bar.size.x
		panel.draw_line(Vector2(tip_x, bar.position.y - 2.0), Vector2(tip_x - slant, bar.end.y + 2.0), Color(Color.WHITE, 0.85), 1.5)
	# Feine Magenta-Linie unter der Leiste, nach rechts auslaufend.
	panel.draw_line(Vector2(bar.position.x, h - 4.5), Vector2(bar.position.x + bar.size.x * 0.5, h - 4.5), Color(MAGENTA, 0.45), 1.0)
	panel.draw_line(Vector2(bar.position.x + bar.size.x * 0.5, h - 4.5), Vector2(bar.end.x, h - 4.5), Color(MAGENTA, 0.12), 1.0)


## Parallelogramm, oben um `slant` nach rechts versetzt (wie die Vitals-Leisten).
static func _slanted(x: float, y: float, width: float, height: float, slant: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x + slant, y), Vector2(x + width, y), Vector2(x + width - slant, y + height), Vector2(x, y + height),
	])
