class_name VitalBar
extends ProgressBar
## Eine Vitalleiste im Stil des Hauptmenüs: schräge Segmente, Leuchtrand, Zahl rechts.
## Bleibt ein ProgressBar (value / max_value), zeichnet aber alles selbst in _draw.
## Links steht das Kürzel, in der Mitte die Leiste, rechts der Wert.
## Fällt der Wert, bleibt kurz eine helle „Schadensspur“ stehen und läuft dann nach.

const BACK_COLOR := Color(0.03, 0.0, 0.08, 0.85)
const GAP_COLOR := Color(0.02, 0.0, 0.05, 1.0)
const WARN_COLOR := Color(1.0, 0.16, 0.36, 1.0)

@export var accent: Color = Color(0.0, 0.95, 1.0, 1.0)
@export var caption: String = "HP"
@export var segments: int = 10
## Waagerechte Verschiebung der Oberkante in Pixeln (wie die Menüknöpfe).
@export var slant: float = 6.0
@export var bar_height: float = 12.0
@export var caption_width: float = 44.0
@export var number_width: float = 42.0
@export var caption_size: int = 12
@export var number_size: int = 14
## Unter diesem Anteil blinkt das Kürzel rot.
@export var warn_ratio: float = 0.2

## Angezeigter Rest der Schadensspur, läuft dem echten Wert hinterher.
var _trail: float = -1.0
var _trail_hold: float = 0.0


func _ready() -> void:
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("background", empty)
	add_theme_stylebox_override("fill", empty)
	value_changed.connect(_on_value_changed)
	_trail = value


func _on_value_changed(new_value: float) -> void:
	if _trail < 0.0 or new_value >= _trail:
		_trail = new_value
	else:
		_trail_hold = 0.45
	queue_redraw()


func _process(delta: float) -> void:
	if _trail > value:
		if _trail_hold > 0.0:
			_trail_hold -= delta
		else:
			_trail = maxf(value, _trail - max_value * 0.6 * delta)
		queue_redraw()
	elif _ratio() < warn_ratio:
		queue_redraw()


func _ratio() -> float:
	var cap := max_value if max_value > 0.0 else 1.0
	return clampf(value / cap, 0.0, 1.0)


func _draw() -> void:
	var font := get_theme_default_font()
	var h := size.y
	var top := (h - bar_height) * 0.5
	var x0 := caption_width
	var x1 := size.x - number_width
	var ratio := _ratio()
	var warn := ratio < warn_ratio
	var blink := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.009)

	# Kürzel links, im Warnbereich rot blinkend.
	var cap_color := accent.lerp(WARN_COLOR, blink) if warn else accent
	var cap_base := (h + font.get_ascent(caption_size) - font.get_descent(caption_size)) * 0.5
	draw_string(font, Vector2(0.0, cap_base), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, cap_color)

	# Grund: dunkle Schräge mit dünnem Rand in der Leistenfarbe.
	var back := _slanted(x0, x1, top, bar_height)
	draw_colored_polygon(back, BACK_COLOR)
	var outline := back.duplicate()
	outline.append(back[0])
	draw_polyline(outline, Color(accent, 0.35), 1.0)

	# Segmente. Jedes wird anteilig gefüllt, damit die Leiste stufenlos sinkt.
	var count := maxi(segments, 1)
	var pad := 2.0
	var inner0 := x0 + pad
	var inner1 := x1 - pad
	var cell := (inner1 - inner0) / float(count)
	var gap := 2.0
	var cap_value := max_value if max_value > 0.0 else 1.0
	var trail_ratio := clampf(_trail / cap_value, 0.0, 1.0)
	var fill_top := top + pad
	var fill_h := bar_height - pad * 2.0
	for i in count:
		var c0 := inner0 + cell * i
		var c1 := c0 + cell - gap
		var a := float(i) / count
		var b := float(i + 1) / count
		# Leere Zelle als schwache Kontur.
		draw_colored_polygon(_slanted(c0, c1, fill_top, fill_h), Color(accent, 0.07))
		# Schadensspur zwischen echtem Wert und nachlaufendem Wert.
		if trail_ratio > a and trail_ratio > ratio:
			var t0 := lerpf(c0, c1, clampf((ratio - a) / (b - a), 0.0, 1.0))
			var t1 := lerpf(c0, c1, clampf((trail_ratio - a) / (b - a), 0.0, 1.0))
			if t1 > t0:
				draw_colored_polygon(_slanted(t0, t1, fill_top, fill_h), Color(1.0, 0.55, 0.9, 0.7))
		if ratio <= a:
			continue
		var f1 := lerpf(c0, c1, clampf((ratio - a) / (b - a), 0.0, 1.0))
		var fill := accent
		# Weicher Schein hinter der Zelle, dann die Zelle, dann eine helle Oberkante.
		draw_colored_polygon(_slanted(c0 - 1.5, f1 + 1.5, fill_top - 2.0, fill_h + 4.0), Color(fill, 0.22))
		draw_colored_polygon(_slanted(c0, f1, fill_top, fill_h), fill)
		draw_colored_polygon(_slanted(c0, f1, fill_top, maxf(fill_h * 0.3, 1.0)), Color(1.0, 1.0, 1.0, 0.35))

	# Zahl rechts.
	var shown := "%d" % ceili(value) if value > 0.0 else "0"
	var num_color := WARN_COLOR.lerp(Color.WHITE, blink * 0.4) if warn else Color(0.95, 0.97, 1.0, 1.0)
	var num_base := (h + font.get_ascent(number_size) - font.get_descent(number_size)) * 0.5
	draw_string(font, Vector2(x1 + 4.0, num_base), shown, HORIZONTAL_ALIGNMENT_RIGHT, number_width - 4.0, number_size, num_color)


## Parallelogramm von x0 bis x1, die Oberkante um `slant` nach rechts versetzt.
## Der Versatz wird auf die Höhe dieser Fläche umgerechnet, damit alle Kanten parallel laufen.
func _slanted(x0: float, x1: float, y: float, height: float) -> PackedVector2Array:
	var k := slant / maxf(bar_height, 1.0) * height
	var mid := (y + height * 0.5)
	var shift := slant / maxf(bar_height, 1.0) * (mid - size.y * 0.5)
	return PackedVector2Array([
		Vector2(x0 + k * 0.5 - shift, y),
		Vector2(x1 + k * 0.5 - shift, y),
		Vector2(x1 - k * 0.5 - shift, y + height),
		Vector2(x0 - k * 0.5 - shift, y + height),
	])
