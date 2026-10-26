extends CanvasLayer
## Vier Leisten oben links. Liegt auf Layer 2, das Pausemenü auf Layer 10 darüber.
## Die NOCLIP-Zeile bleibt darüber frei (sie steht bei y = 20, der Rahmen beginnt bei y = 56).
## Feste Größe in der 1280×720-Basis. Der Projekt-Stretch skaliert sie mit.
## Optik wie das Hauptmenü: dunkles Violett, Cyan-Rand, Magenta-Streifen, schräge Kanten.
## Den Rahmen zeichnet _draw_frame, die Leisten zeichnen sich selbst (VitalBar).

## Unter 20 % wird die Leiste entsättigt und durchsichtiger. Größe und Position bleiben.
const FADE_RATIO := 0.2
const FADE_ALPHA := 0.42

const PANEL_COLOR := Color(0.03, 0.0, 0.08, 0.84)
const CYAN := Color(0.0, 0.95, 1.0, 1.0)
const MAGENTA := Color(1.0, 0.1, 0.75, 1.0)
const WARN_COLOR := Color(1.0, 0.16, 0.36, 1.0)
## Abgeschrägte Ecken oben rechts und unten links, in Pixeln.
const CHAMFER := 14.0

@onready var hp_bar: ProgressBar = %HPBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var durst_bar: ProgressBar = %DurstBar
@onready var frame: Control = $Frame
@onready var status_label: Label = %Status

var stats: PlayerStats


func _ready() -> void:
	frame.draw.connect(_draw_frame)
	var player := get_parent() as Player
	if player == null:
		push_error("SurvivalHud braucht den Player als Parent.")
		return
	stats = player.get_node_or_null(^"PlayerStats") as PlayerStats
	if stats == null:
		push_error("SurvivalHud: Knoten PlayerStats fehlt.")
		return
	if not stats.is_node_ready():
		await stats.ready
	_apply(hp_bar, stats.hp, stats.max_hp)
	_apply(stamina_bar, stats.stamina, stats.max_stamina)
	_apply(hunger_bar, stats.hunger, stats.max_hunger)
	_apply(durst_bar, stats.thirst, stats.max_thirst)
	stats.stat_changed.connect(_on_stat_changed)


func _on_stat_changed(stat_name: String, current: float, maximum: float) -> void:
	var bar := _bar_for(stat_name)
	if bar == null:
		return
	_apply(bar, current, maximum)


func _bar_for(stat_name: String) -> ProgressBar:
	match stat_name:
		PlayerStats.STAT_HP:
			return hp_bar
		PlayerStats.STAT_STAMINA:
			return stamina_bar
		PlayerStats.STAT_HUNGER:
			return hunger_bar
		PlayerStats.STAT_THIRST:
			return durst_bar
		_:
			return null


func _process(_delta: float) -> void:
	if stats == null:
		return
	_fade(hp_bar, stats.hp, stats.max_hp)
	_fade(stamina_bar, stats.stamina, stats.max_stamina)
	_fade(hunger_bar, stats.hunger, stats.max_hunger)
	_fade(durst_bar, stats.thirst, stats.max_thirst)
	_update_status()
	frame.queue_redraw()


## Kopfzeile rechts: STABIL, sonst der dringendste Mangel, blinkend.
func _update_status() -> void:
	var text := "STABIL"
	if _low(stats.hp, stats.max_hp):
		text = "KRITISCH"
	elif _low(stats.thirst, stats.max_thirst):
		text = "DEHYDRIERT"
	elif _low(stats.hunger, stats.max_hunger):
		text = "UNTERVERSORGT"
	elif _low(stats.stamina, stats.max_stamina):
		text = "ERSCHÖPFT"
	status_label.text = text
	if text == "STABIL":
		status_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		status_label.add_theme_color_override("font_color", Color(CYAN, 0.75))
	else:
		status_label.add_theme_color_override("font_color", WARN_COLOR)
		status_label.modulate.a = 0.55 + 0.45 * absf(sin(float(Time.get_ticks_msec()) * 0.006))


func _low(value: float, maximum: float) -> bool:
	var cap := maximum if maximum > 0.0 else 1.0
	return value / cap < FADE_RATIO


func _draw_frame() -> void:
	var w := frame.size.x
	var h := frame.size.y
	var shape := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(w - CHAMFER, 0.0),
		Vector2(w, CHAMFER),
		Vector2(w, h),
		Vector2(CHAMFER, h),
		Vector2(0.0, h - CHAMFER),
	])
	frame.draw_colored_polygon(shape, PANEL_COLOR)
	# Feine Scanlines wie der CRT-Filter im Menü.
	var y := 2.0
	while y < h - 1.0:
		var x_left := maxf(0.0, CHAMFER - (h - y)) if y > h - CHAMFER else 0.0
		var x_right := w - maxf(0.0, CHAMFER - y) if y < CHAMFER else w
		frame.draw_line(Vector2(x_left, y), Vector2(x_right, y), Color(1.0, 1.0, 1.0, 0.025), 1.0)
		y += 3.0
	# Rand: Cyan, halb durchsichtig. Der Schein ist eine zweite, breitere Linie.
	var outline := shape.duplicate()
	outline.append(shape[0])
	frame.draw_polyline(outline, Color(CYAN, 0.12), 5.0)
	frame.draw_polyline(outline, Color(CYAN, 0.5), 1.0)
	# Magenta-Streifen links, schräg wie an den Menüknöpfen.
	var accent_bottom := h - CHAMFER
	frame.draw_colored_polygon(PackedVector2Array([
		Vector2(2.0, 4.0), Vector2(8.0, 4.0), Vector2(5.0, accent_bottom), Vector2(-1.0, accent_bottom),
	]), Color(MAGENTA, 0.25))
	frame.draw_colored_polygon(PackedVector2Array([
		Vector2(3.0, 4.0), Vector2(6.5, 4.0), Vector2(3.5, accent_bottom), Vector2(0.0, accent_bottom),
	]), MAGENTA)
	# Hell leuchtende Ecke an der Abschrägung oben rechts.
	frame.draw_line(Vector2(w - CHAMFER - 26.0, 0.0), Vector2(w - CHAMFER, 0.0), CYAN, 2.0)
	frame.draw_line(Vector2(w - CHAMFER, 0.0), Vector2(w, CHAMFER), CYAN, 2.0)
	frame.draw_line(Vector2(w, CHAMFER), Vector2(w, CHAMFER + 18.0), CYAN, 2.0)
	# Trennlinie unter der Kopfzeile, von Magenta nach rechts ausblendend.
	var line_y := 27.0
	var steps := 24
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var x0 := lerpf(18.0, w - 16.0, t0)
		var x1 := lerpf(18.0, w - 16.0, t1)
		frame.draw_line(Vector2(x0, line_y), Vector2(x1, line_y), Color(MAGENTA, 0.7 * (1.0 - t0)), 1.0)
	# Kleine Kennung unten rechts und drei Markierungen.
	var font := frame.get_theme_default_font()
	frame.draw_string(font, Vector2(w - 78.0, h - 4.0), "ND-OS // 0.3", HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 9, Color(CYAN, 0.35))
	for i in 3:
		var bx := 24.0 + i * 9.0
		frame.draw_rect(Rect2(bx, h - 8.0, 6.0, 3.0), Color(MAGENTA, 0.9 - i * 0.3))


func _fade(bar: ProgressBar, value: float, maximum: float) -> void:
	var cap := maximum if maximum > 0.0 else 1.0
	bar.modulate = fade_color(value / cap)


## 1 = volle Neonfarbe. Darunter Grau, nahe 0 ein gedämpftes Rot und weniger Alpha.
## Alpha bleibt über 0, die Leiste verschwindet nicht und rückt nicht.
static func fade_color(ratio: float) -> Color:
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped >= FADE_RATIO:
		return Color(1.0, 1.0, 1.0, 1.0)
	var amount := 1.0 - (clamped / FADE_RATIO)
	var gray := lerpf(1.0, 0.55, amount)
	var alpha := lerpf(FADE_ALPHA, 1.0, 1.0 - amount)
	var color := Color(gray, gray, gray, alpha)
	if amount > 0.65:
		var warn := (amount - 0.65) / 0.35
		color = color.lerp(Color(0.72, 0.34, 0.34, alpha), warn)
	if clamped <= 0.02:
		var pulse := 0.82 + 0.18 * absf(sin(float(Time.get_ticks_msec()) * 0.004))
		color.a *= pulse
	return color


func _apply(bar: ProgressBar, current: float, maximum: float) -> void:
	var cap := maximum if maximum > 0.0 else 1.0
	bar.max_value = cap
	bar.value = clampf(current, 0.0, cap)
