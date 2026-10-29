class_name StealthHud
extends Control
## Kleine Schleich-Anzeige unter den Vitals, im selben Stil (Rahmen, Cyan-Rand, Magenta-Streifen).
## Zeigt Sicht (Auge-Symbol, wie gut man zu sehen ist), Lärm (Lautsprecher-Symbol, letztes Geräusch)
## und als Schild oben rechts den Status der Gegner:
## VERBORGEN, SICHTBAR, VERDACHT, ENTDECKT. Wird von PlayerStealth im Code erzeugt.

const PANEL_COLOR := Color(0.03, 0.0, 0.08, 0.84)
const CYAN := Color(0.0, 0.95, 1.0, 1.0)
const MAGENTA := Color(1.0, 0.1, 0.75, 1.0)
const AMBER := Color(1.0, 0.78, 0.2, 1.0)
const ALERT := Color(1.0, 0.16, 0.36, 1.0)
const CHAMFER := 10.0
const SIGHT_COLOR := Color(0.85, 0.95, 1.0, 1.0)
const ICON_X := 21.0
const BAR_X := 30.0
const ROW_HEIGHT := 12.0
const ROW_SIGHT_Y := 20.0
const ROW_NOISE_Y := 32.0

var stealth: PlayerStealth

var _sight: VitalBar
var _noise: VitalBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Unter dem Vitals-Rahmen (16,56 bis 316,204).
	# Kompakt gehalten, das Geldfeld der SurvivalHud steht direkt darunter.
	position = Vector2(16.0, 212.0)
	size = Vector2(200.0, 46.0)
	# Statt Beschriftung steht links vor jeder Leiste ein Symbol (in _draw gezeichnet).
	_sight = _make_bar(SIGHT_COLOR, ROW_SIGHT_Y)
	_noise = _make_bar(MAGENTA, ROW_NOISE_Y)


func _make_bar(accent: Color, y: float) -> VitalBar:
	var bar := VitalBar.new()
	bar.caption = ""
	bar.accent = accent
	bar.warn_ratio = -1.0
	bar.segments = 10
	bar.bar_height = 7.0
	bar.slant = 4.0
	bar.caption_width = 4.0
	bar.number_width = 24.0
	bar.number_size = 10
	bar.max_value = 100.0
	bar.step = 0.0
	# ProgressBar erzwingt sonst die Höhe seiner Theme-Schrift (~27 px) und die Leiste rutscht nach unten.
	bar.add_theme_font_size_override("font_size", 4)
	bar.position = Vector2(BAR_X, y)
	add_child(bar)
	bar.size = Vector2(size.x - BAR_X - 8.0, ROW_HEIGHT)
	return bar


func _process(_delta: float) -> void:
	if stealth == null:
		return
	_sight.value = stealth.visibility * 100.0
	_noise.value = stealth.noise_level * 100.0
	queue_redraw()


func status_text() -> String:
	if stealth == null:
		return ""
	if stealth.detection >= 1.0:
		return "ENTDECKT"
	if stealth.detection >= 0.35:
		return "VERDACHT"
	if stealth.visibility < 0.3:
		return "VERBORGEN"
	return "SICHTBAR"


func status_color() -> Color:
	match status_text():
		"ENTDECKT":
			return ALERT
		"VERDACHT":
			return AMBER
		"VERBORGEN":
			return Color(CYAN, 0.8)
	return Color(0.95, 0.97, 1.0, 0.9)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var shape := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(w - CHAMFER, 0.0), Vector2(w, CHAMFER),
		Vector2(w, h), Vector2(CHAMFER, h), Vector2(0.0, h - CHAMFER),
	])
	draw_colored_polygon(shape, PANEL_COLOR)
	var outline := shape.duplicate()
	outline.append(shape[0])
	var status := status_text()
	var edge := CYAN
	if status == "ENTDECKT":
		edge = ALERT
	elif status == "VERDACHT":
		edge = AMBER
	draw_polyline(outline, Color(edge, 0.12), 5.0)
	draw_polyline(outline, Color(edge, 0.5), 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3.0, 4.0), Vector2(6.5, 4.0), Vector2(3.5, h - CHAMFER), Vector2(0.0, h - CHAMFER),
	]), MAGENTA)
	var font := get_theme_default_font()
	draw_string(font, Vector2(14.0, 13.0), "STEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.97, 1.0))
	# Feine Trennlinie unter der Kopfzeile, nach rechts auslaufend.
	draw_line(Vector2(14.0, 16.5), Vector2(w * 0.55, 16.5), Color(MAGENTA, 0.45), 1.0)
	draw_line(Vector2(w * 0.55, 16.5), Vector2(w - 12.0, 16.5), Color(MAGENTA, 0.12), 1.0)
	var color := status_color()
	if status == "ENTDECKT" or status == "VERDACHT":
		var blink := 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.012)
		color = Color(color, blink)
	_draw_status_tag(font, status, color, w - 10.0)
	_draw_eye(Vector2(ICON_X, ROW_SIGHT_Y + ROW_HEIGHT * 0.5), SIGHT_COLOR)
	_draw_speaker(Vector2(ICON_X, ROW_NOISE_Y + ROW_HEIGHT * 0.5), MAGENTA)


## Status als kleines Schild oben rechts (rechte Kante bei `right`).
func _draw_status_tag(font: Font, text: String, color: Color, right: float) -> void:
	if text.is_empty():
		return
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var rect := Rect2(right - text_w - 10.0, 4.0, text_w + 10.0, 11.0)
	draw_rect(rect, Color(color, 0.16 * color.a))
	draw_rect(rect, Color(color, 0.7 * color.a), false, 1.0)
	draw_string(font, Vector2(rect.position.x + 5.0, rect.position.y + 8.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)


## Auge vor der SICHT-Leiste: weit offen = gut zu sehen, fast zu = verborgen.
func _draw_eye(center: Vector2, color: Color) -> void:
	var open := 1.0
	if stealth != null:
		open = clampf(stealth.visibility * 1.4, 0.15, 1.0)
	var points := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		points.append(center + Vector2(lerpf(-6.5, 6.5, t), -sin(t * PI) * 4.2 * open))
	for i in 13:
		var t := float(i) / 12.0
		points.append(center + Vector2(lerpf(6.5, -6.5, t), sin(t * PI) * 4.2 * open))
	draw_colored_polygon(points, Color(color, 0.15))
	points.append(points[0])
	draw_polyline(points, color, 1.2, true)
	if open > 0.3:
		draw_circle(center, 2.0 * open, color)


## Lautsprecher vor der LÄRM-Leiste, mit bis zu drei Schallbögen je nach Lärmpegel.
func _draw_speaker(center: Vector2, color: Color) -> void:
	var c := center + Vector2(-3.0, 0.0)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-3.5, -1.8), c + Vector2(-1.0, -1.8), c + Vector2(2.0, -4.2),
		c + Vector2(2.0, 4.2), c + Vector2(-1.0, 1.8), c + Vector2(-3.5, 1.8),
	]), color)
	var level := 0.0
	if stealth != null:
		level = stealth.noise_level
	for i in 3:
		var lit := level > (float(i) + 0.5) / 3.5
		var alpha := 0.9 if lit else 0.18
		var radius := 3.0 + 2.2 * i
		draw_arc(c + Vector2(2.0, 0.0), radius, -0.9, 0.9, 8, Color(color, alpha), 1.1, true)
