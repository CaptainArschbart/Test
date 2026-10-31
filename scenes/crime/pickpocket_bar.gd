class_name PickpocketBar
extends Control
## Anzeige beim Taschendiebstahl im Stil der XP- und Vitals-Leisten (Violett, Cyan-Rand, Neon).
##
## Eine segmentierte Leiste: Von links läuft der Griff (pick_progress) grün auf die Zielmarke zu,
## von rechts der Verdacht (suspicion) rot auf dieselbe Marke. Grün an der Marke heißt geklaut,
## Rot an der Marke heißt erwischt. Die Marke sitzt bei DEAD_POINT, rechts von der Mitte, damit
## der Verdacht den kürzeren Weg hat. Ab DANGER pulsiert der Rand rot.
## item_user.gd lädt das Skript per preload (siehe dort), class_name nur für den Editor.

## Lage der Zielmarke auf der Leiste, 0 = linkes Ende, 1 = rechtes Ende.
const DEAD_POINT := 0.6
## Ab diesem Verdacht warnt die Anzeige.
const DANGER := 0.7
## Größe, mit der item_user die Leiste anlegt (1280×720-Basis).
const SIZE := Vector2(420.0, 48.0)

const PANEL_COLOR := Color(0.03, 0.0, 0.08, 0.84)
const CYAN := Color(0.0, 0.95, 1.0)
const GREEN := Color(0.45, 1.0, 0.35)
const MAGENTA := Color(1.0, 0.1, 0.75)
const RED := Color(1.0, 0.18, 0.22)
const AMBER := Color(1.0, 0.8, 0.2)
const TEXT_COLOR := Color(0.95, 0.97, 1.0)
const CHAMFER := 10.0
const PAD := 16.0
const SEGMENTS := 26
const SLANT := 3.0

var progress := 0.0
var suspicion := 0.0
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(new_progress: float, new_suspicion: float) -> void:
	progress = clampf(new_progress, 0.0, 1.0)
	suspicion = clampf(new_suspicion, 0.0, 1.0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


## Die Leiste selbst (ohne Rahmen und Beschriftung).
func bar_rect() -> Rect2:
	return Rect2(PAD, size.y - 21.0, size.x - PAD * 2.0, 11.0)


## Zielmarke, rechte Kante von Grün und linke Kante von Rot in Pixeln (auch für Tests).
func mark_x() -> float:
	var bar := bar_rect()
	return bar.position.x + bar.size.x * DEAD_POINT


func green_tip() -> float:
	var bar := bar_rect()
	return bar.position.x + bar.size.x * DEAD_POINT * progress


func red_tip() -> float:
	var bar := bar_rect()
	return bar.end.x - bar.size.x * (1.0 - DEAD_POINT) * suspicion


func _draw() -> void:
	var w := size.x
	var h := size.y
	var c := CHAMFER
	var danger := clampf((suspicion - DANGER) / (1.0 - DANGER), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_time * lerpf(6.0, 14.0, danger))
	# Rahmen wie die XP-Leiste: beidseitig abgeschrägt, feine Scanlines.
	var shape := PackedVector2Array([
		Vector2(c, 0.0), Vector2(w - c, 0.0), Vector2(w, c),
		Vector2(w - c, h), Vector2(c, h), Vector2(0.0, h - c),
	])
	draw_colored_polygon(shape, PANEL_COLOR)
	var y := 2.0
	while y < h - 1.0:
		draw_line(Vector2(c, y), Vector2(w - c, y), Color(1.0, 1.0, 1.0, 0.025), 1.0)
		y += 3.0
	var edge := CYAN.lerp(RED, danger * pulse)
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, Color(edge, 0.12 + 0.3 * danger * pulse), 5.0)
	draw_polyline(outline, Color(edge, 0.55 + 0.35 * danger), 1.0)

	var bar := bar_rect()
	var mark := mark_x()
	var green := green_tip()
	var red := red_tip()
	# Beschriftung: links der Griff, rechts der Verdacht, jeweils mit Prozent.
	var font := get_theme_default_font()
	var text_y := bar.position.y - 7.0
	_label(font, Vector2(bar.position.x, text_y), "GRIFF", HORIZONTAL_ALIGNMENT_LEFT, GREEN)
	var gap_x := 6.0
	var pick_w := font.get_string_size("GRIFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	_label(font, Vector2(bar.position.x + pick_w + gap_x, text_y), "%d %%" % roundi(progress * 100.0),
			HORIZONTAL_ALIGNMENT_LEFT, Color(TEXT_COLOR, 0.8))
	var sus_color := MAGENTA.lerp(RED, danger).lerp(Color.WHITE, danger * pulse * 0.4)
	var sus_w := font.get_string_size("VERDACHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	_label(font, Vector2(bar.end.x - sus_w, text_y), "VERDACHT", HORIZONTAL_ALIGNMENT_LEFT, sus_color)
	_label(font, Vector2(bar.end.x - sus_w - gap_x - 40.0, text_y), "%d %%" % roundi(suspicion * 100.0),
			HORIZONTAL_ALIGNMENT_RIGHT, Color(TEXT_COLOR, 0.8), 40.0)

	# Segmente: links grün getönt bis zur Marke, rechts rot getönt.
	var gap := 2.0
	var seg_w := (bar.size.x - gap * (SEGMENTS - 1)) / SEGMENTS
	for i in SEGMENTS:
		var x0 := bar.position.x + i * (seg_w + gap)
		var x1 := x0 + seg_w
		var left_side := (x0 + x1) * 0.5 < mark
		draw_colored_polygon(_slanted(x0, bar.position.y, seg_w, bar.size.y), Color(GREEN if left_side else MAGENTA, 0.09))
		# Griff: Cyan nach Grün, je näher an der Marke.
		var a := x0
		var b := minf(x1, green)
		if b - a > 0.5:
			var t := clampf((x0 - bar.position.x) / (mark - bar.position.x), 0.0, 1.0)
			draw_colored_polygon(_slanted(a, bar.position.y, b - a, bar.size.y), CYAN.lerp(GREEN, t))
		# Verdacht: Magenta nach Rot, je näher an der Marke.
		a = maxf(x0, red)
		b = x1
		if b - a > 0.5:
			var t := clampf((bar.end.x - x1) / (bar.end.x - mark), 0.0, 1.0)
			draw_colored_polygon(_slanted(a, bar.position.y, b - a, bar.size.y), MAGENTA.lerp(RED, t))
	# Leuchtende Spitzen an beiden Füllständen.
	if progress > 0.0:
		draw_line(Vector2(green, bar.position.y - 2.0), Vector2(green - SLANT, bar.end.y + 2.0), Color(Color.WHITE, 0.85), 1.5)
	if suspicion > 0.0:
		draw_line(Vector2(red + SLANT, bar.position.y - 2.0), Vector2(red, bar.end.y + 2.0), Color(Color.WHITE, 0.85), 1.5)

	# Zielmarke: Bernstein-Strich mit Glimmen, Dreiecke darüber und darunter.
	var near := maxf(progress, suspicion)
	var glow := 0.25 + 0.35 * near * pulse
	var top := bar.position.y - 4.0
	var bottom := bar.end.y + 4.0
	draw_line(Vector2(mark, top), Vector2(mark - SLANT, bottom), Color(AMBER, glow), 6.0)
	draw_line(Vector2(mark, top), Vector2(mark - SLANT, bottom), AMBER, 2.0)
	var s := 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(mark - s, top - s), Vector2(mark + s, top - s), Vector2(mark, top)]), AMBER)
	draw_colored_polygon(PackedVector2Array([Vector2(mark - SLANT - s, bottom + s), Vector2(mark - SLANT, bottom),
			Vector2(mark - SLANT + s, bottom + s)]), AMBER)

	# Feine Linie unter der Leiste, links grün, rechts rot, auslaufend.
	var line_y := h - 4.5
	draw_line(Vector2(bar.position.x, line_y), Vector2(mark, line_y), Color(GREEN, 0.35), 1.0)
	draw_line(Vector2(mark, line_y), Vector2(bar.end.x, line_y), Color(RED, 0.2 + 0.4 * danger * pulse), 1.0)


func _label(font: Font, at: Vector2, text: String, align: HorizontalAlignment, color: Color, width := -1.0) -> void:
	draw_string(font, at + Vector2(1.0, 1.0), text, align, width, 9, Color(0.15, 0.0, 0.2, 0.9))
	draw_string(font, at, text, align, width, 9, color)


## Parallelogramm, oben um SLANT nach rechts versetzt (wie XP- und Vitals-Leisten).
static func _slanted(x: float, y: float, width: float, height: float) -> PackedVector2Array:
	var slant := minf(SLANT, width)
	return PackedVector2Array([
		Vector2(x + slant, y), Vector2(x + width, y), Vector2(x + width - slant, y + height), Vector2(x, y + height),
	])
