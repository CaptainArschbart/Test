class_name StealthHud
extends Control
## Kleine Schleich-Anzeige unter den Vitals, im selben Stil (Rahmen, Cyan-Rand, Magenta-Streifen).
## Zeigt SICHT (wie gut man zu sehen ist), LÄRM (letztes Geräusch) und den Status der Gegner:
## VERBORGEN, SICHTBAR, VERDACHT, ENTDECKT. Wird von PlayerStealth im Code erzeugt.

const PANEL_COLOR := Color(0.03, 0.0, 0.08, 0.84)
const CYAN := Color(0.0, 0.95, 1.0, 1.0)
const MAGENTA := Color(1.0, 0.1, 0.75, 1.0)
const AMBER := Color(1.0, 0.78, 0.2, 1.0)
const ALERT := Color(1.0, 0.16, 0.36, 1.0)
const CHAMFER := 10.0

var stealth: PlayerStealth

var _sight: VitalBar
var _noise: VitalBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Unter dem Vitals-Rahmen (16,56 bis 316,204).
	# Kompakt gehalten, das Geldfeld der SurvivalHud steht direkt darunter.
	position = Vector2(16.0, 212.0)
	size = Vector2(200.0, 46.0)
	_sight = _make_bar("SICHT", Color(0.85, 0.95, 1.0), 19.0)
	_noise = _make_bar("LÄRM", MAGENTA, 31.0)


func _make_bar(caption: String, accent: Color, y: float) -> VitalBar:
	var bar := VitalBar.new()
	bar.caption = caption
	bar.accent = accent
	bar.warn_ratio = -1.0
	bar.segments = 10
	bar.bar_height = 7.0
	bar.slant = 4.0
	bar.caption_width = 36.0
	bar.number_width = 26.0
	bar.caption_size = 9
	bar.number_size = 10
	bar.max_value = 100.0
	bar.step = 0.0
	bar.position = Vector2(14.0, y)
	bar.size = Vector2(154.0, 12.0)
	add_child(bar)
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
	var color := status_color()
	if status == "ENTDECKT" or status == "VERDACHT":
		var blink := 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.012)
		color = Color(color, blink)
	draw_string(font, Vector2(w - 90.0, 13.0), status, HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 9, color)
	_draw_eye(Vector2(w - 16.0, 31.0), color)


## Kleines Auge rechts: offen = gesehen, Strich = verborgen.
func _draw_eye(center: Vector2, color: Color) -> void:
	var open := 1.0
	if stealth != null:
		open = clampf(stealth.visibility * 1.4, 0.08, 1.0)
	var points := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		var x := lerpf(-9.0, 9.0, t)
		points.append(center + Vector2(x, -sin(t * PI) * 6.0 * open))
	for i in 17:
		var t := float(i) / 16.0
		var x := lerpf(9.0, -9.0, t)
		points.append(center + Vector2(x, sin(t * PI) * 6.0 * open))
	draw_colored_polygon(points, Color(color, 0.18))
	points.append(points[0])
	draw_polyline(points, color, 1.5)
	if open > 0.25:
		draw_circle(center, 2.6 * open, color)
