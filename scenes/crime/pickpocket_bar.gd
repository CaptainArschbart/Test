class_name PickpocketBar
extends Control
## Anzeige beim Taschendiebstahl: ein waagerechter Balken mit abgerundeten Enden.
##
## Von links wächst grün der Griff (pick_progress), von rechts rot der Verdacht (suspicion).
## Die graue Markierung bei DEAD_POINT ist das Ziel beider Seiten: Grün dort heißt geklaut,
## Rot dort heißt erwischt. Gelbe Pfeile an den Spitzen zeigen die Richtung.
## Verdacht 1 liegt genau auf der Markierung, Rot berührt Grün also nie vor dem Erwischen.

## Lage der Markierung, 0 = linkes Ende, 1 = rechtes Ende.
const DEAD_POINT := 0.6
const GREEN := Color(0.15, 0.68, 0.3)
const RED := Color(0.92, 0.12, 0.14)
const TRACK := Color(1.0, 1.0, 1.0, 0.9)
const OUTLINE := Color(0.0, 0.0, 0.0)
const MARK := Color(0.5, 0.5, 0.5)
const ARROW := Color(1.0, 0.78, 0.05)

var progress := 0.0
var suspicion := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(new_progress: float, new_suspicion: float) -> void:
	new_progress = clampf(new_progress, 0.0, 1.0)
	new_suspicion = clampf(new_suspicion, 0.0, 1.0)
	if is_equal_approx(new_progress, progress) and is_equal_approx(new_suspicion, suspicion):
		return
	progress = new_progress
	suspicion = new_suspicion
	queue_redraw()


## Rechte Kante von Grün und linke Kante von Rot in Pixeln (für Tests und Pfeile).
func green_tip() -> float:
	return size.x * DEAD_POINT * progress


func red_tip() -> float:
	return size.x - size.x * (1.0 - DEAD_POINT) * suspicion


func _draw() -> void:
	var w := size.x
	var h := size.y
	var radius := int(h * 0.5)
	var border := maxi(int(h * 0.09), 2)
	_box(Rect2(0, 0, w, h), TRACK, radius, true, true)
	var green := green_tip()
	if green > 0.5:
		_box(Rect2(0, 0, green, h), GREEN, radius, true, false)
		draw_line(Vector2(green, 0), Vector2(green, h), OUTLINE, border)
	var red := red_tip()
	if red < w - 0.5:
		_box(Rect2(red, 0, w - red, h), RED, radius, false, true)
		draw_line(Vector2(red, 0), Vector2(red, h), OUTLINE, border)
	var mark := w * DEAD_POINT
	var mark_w := maxf(h * 0.22, 4.0)
	draw_rect(Rect2(mark - mark_w * 0.5, 0, mark_w, h), MARK)
	draw_rect(Rect2(mark - mark_w * 0.5, 0, mark_w, h), OUTLINE, false, border * 0.5)
	if progress < 1.0 and suspicion < 1.0:
		_arrow(green + border, h, 1.0)
		_arrow(red - border, h, -1.0)
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_corner_radius_all(radius)
	frame.set_border_width_all(border)
	frame.border_color = OUTLINE
	frame.anti_aliasing = true
	draw_style_box(frame, Rect2(0, 0, w, h))


func _box(rect: Rect2, color: Color, radius: int, round_left: bool, round_right: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.anti_aliasing = true
	box.corner_radius_top_left = radius if round_left else 0
	box.corner_radius_bottom_left = radius if round_left else 0
	box.corner_radius_top_right = radius if round_right else 0
	box.corner_radius_bottom_right = radius if round_right else 0
	draw_style_box(box, rect)


## Pfeil ab `x` in Richtung `dir` (1 = nach rechts), mittig in der Höhe.
func _arrow(x: float, h: float, dir: float) -> void:
	var len := h * 0.9
	var shaft := h * 0.16
	var head := h * 0.3
	var y := h * 0.5
	var neck := x + dir * len * 0.55
	var points := PackedVector2Array([
		Vector2(x, y - shaft), Vector2(neck, y - shaft), Vector2(neck, y - head),
		Vector2(x + dir * len, y),
		Vector2(neck, y + head), Vector2(neck, y + shaft), Vector2(x, y + shaft),
	])
	draw_colored_polygon(points, ARROW)
	points.append(points[0])
	draw_polyline(points, OUTLINE, maxf(h * 0.05, 1.5), true)
