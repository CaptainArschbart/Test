extends CanvasLayer
## Vier Leisten oben links, darunter das Geldfeld (Inventory.money, zählt bei Änderungen hoch
## und zeigt kurz "+15 ¢" bzw. "−5 ¢", der Rahmen leuchtet dabei grün oder rot). Liegt auf Layer 2, das Pausemenü auf Layer 10 darüber.
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
## Geldanzeige unter dem Rahmen: Farbe wie der Credchip, Zählen dauert so lange (Sekunden).
const MONEY_COLOR := Color(1.0, 0.9, 0.2, 1.0)
const MONEY_ROLL_TIME := 0.45
const MONEY_GAIN_COLOR := Color(0.3, 1.0, 0.55, 1.0)
const MONEY_PANEL_SIZE := Vector2(200.0, 40.0)
## So lange leuchten Rand und Credchip nach einer Änderung nach (Sekunden).
const MONEY_FLASH_TIME := 0.7

@onready var hp_bar: ProgressBar = %HPBar
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var durst_bar: ProgressBar = %DurstBar
@onready var frame: Control = $Frame
@onready var status_label: Label = %Status

var stats: PlayerStats
var inventory: Inventory
## Geldfeld (im Code erzeugt): Rahmen, Betrag und kurze "+15"-Einblendung.
var money_panel: Control
var money_label: Label
var _money_delta: Label
## Angezeigter Betrag; zählt per Tween zum echten Kontostand.
var _shown_money := 0.0
var _money_tween: Tween
var _delta_tween: Tween
## 1 direkt nach einer Änderung, fällt auf 0. Färbt Rand und Chip in _money_flash_color.
var _money_flash := 0.0
var _money_flash_color := MONEY_GAIN_COLOR


func _ready() -> void:
	frame.draw.connect(_draw_frame)
	_build_money_panel()
	var player := get_parent() as Player
	if player == null:
		push_error("SurvivalHud braucht den Player als Parent.")
		return
	inventory = player.get_node_or_null(^"Inventory") as Inventory
	if inventory != null:
		inventory.money_changed.connect(_on_money_changed)
		_set_shown_money(inventory.money)
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


func _on_money_changed(money: int, delta: int) -> void:
	if _money_tween:
		_money_tween.kill()
	_money_tween = create_tween()
	_money_tween.tween_method(_set_shown_money, _shown_money, float(money), MONEY_ROLL_TIME)
	_money_delta.text = ("+%s ¢" if delta > 0 else "−%s ¢") % format_money(absi(delta))
	_money_flash_color = MONEY_GAIN_COLOR if delta > 0 else WARN_COLOR
	_money_delta.add_theme_color_override("font_color", _money_flash_color)
	_money_delta.modulate.a = 1.0
	_money_delta.position.y = 0.0
	if _delta_tween:
		_delta_tween.kill()
	# Einblendung steigt leicht nach oben und blendet aus, der Rahmen leuchtet kurz in derselben Farbe.
	_delta_tween = create_tween().set_parallel(true)
	_delta_tween.tween_method(_set_money_flash, 1.0, 0.0, MONEY_FLASH_TIME)
	_delta_tween.tween_property(_money_delta, "position:y", -10.0, 1.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_delta_tween.tween_property(_money_delta, "modulate:a", 0.0, 0.5).set_delay(1.0)


func _set_money_flash(value: float) -> void:
	_money_flash = value
	money_panel.queue_redraw()


func _set_shown_money(value: float) -> void:
	_shown_money = value
	if money_label != null:
		money_label.text = format_money(roundi(value))


## 1250 → "1.250" (deutscher Tausenderpunkt).
static func format_money(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	while digits.length() > 3:
		out = "." + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out


func _build_money_panel() -> void:
	money_panel = Control.new()
	money_panel.name = "Money"
	money_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Unter der Stealth-Anzeige (StealthHud, 46 px hoch, 8 px unter dem Rahmen), gleich breit wie sie.
	money_panel.position = Vector2(frame.offset_left, frame.offset_bottom + 62.0)
	money_panel.size = MONEY_PANEL_SIZE
	money_panel.draw.connect(_draw_money_panel)
	add_child(money_panel)
	money_label = Label.new()
	money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_label.position = Vector2(46.0, 16.0)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.text = "0"
	money_label.add_theme_font_size_override("font_size", 18)
	money_label.add_theme_color_override("font_color", MONEY_COLOR)
	money_label.add_theme_color_override("font_outline_color", Color(1.0, 0.5, 0.0, 0.3))
	money_label.add_theme_constant_override("outline_size", 3)
	# Weicher Goldschein hinter den Ziffern.
	money_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.7, 0.0, 0.22))
	money_label.add_theme_constant_override("shadow_offset_x", 0)
	money_label.add_theme_constant_override("shadow_offset_y", 0)
	money_label.add_theme_constant_override("shadow_outline_size", 9)
	# Label erzwingt sonst die Höhe seiner Schrift; die Größe erst nach add_child setzen.
	money_panel.add_child(money_label)
	money_label.size = Vector2(MONEY_PANEL_SIZE.x - 46.0 - 24.0, 22.0)
	_money_delta = Label.new()
	_money_delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_money_delta.position = Vector2(money_panel.size.x + 8.0, 0.0)
	_money_delta.size = Vector2(120.0, money_panel.size.y)
	_money_delta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_delta.add_theme_font_size_override("font_size", 15)
	_money_delta.add_theme_color_override("font_outline_color", Color(0.03, 0.0, 0.08))
	_money_delta.add_theme_constant_override("outline_size", 4)
	_money_delta.modulate.a = 0.0
	money_panel.add_child(_money_delta)


## Rahmen im Stil der Stealth-Box: Violett, Scanlines, Cyan-Rand, Magenta-Streifen und
## Kopfzeile "CREDITS" mit Trennlinie. Links ein gezeichneter Credchip, rechts Betrag und ¢.
## Bei Änderungen leuchten Rand und Chip kurz grün (Gutschrift) oder rot (Abbuchung).
func _draw_money_panel() -> void:
	var w := money_panel.size.x
	var h := money_panel.size.y
	var c := 10.0
	var shape := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(w - c, 0.0), Vector2(w, c),
		Vector2(w, h), Vector2(c, h), Vector2(0.0, h - c),
	])
	money_panel.draw_colored_polygon(shape, PANEL_COLOR)
	if _money_flash > 0.0:
		money_panel.draw_colored_polygon(shape, Color(_money_flash_color, 0.1 * _money_flash))
	var y := 2.0
	while y < h - 1.0:
		var x_left := maxf(0.0, c - (h - y)) if y > h - c else 0.0
		var x_right := w - maxf(0.0, c - y) if y < c else w
		money_panel.draw_line(Vector2(x_left, y), Vector2(x_right, y), Color(1.0, 1.0, 1.0, 0.025), 1.0)
		y += 3.0
	var edge := CYAN.lerp(_money_flash_color, _money_flash)
	var outline := shape.duplicate()
	outline.append(shape[0])
	money_panel.draw_polyline(outline, Color(edge, 0.12 + 0.25 * _money_flash), 5.0)
	money_panel.draw_polyline(outline, Color(edge, 0.5 + 0.4 * _money_flash), 1.0)
	money_panel.draw_colored_polygon(PackedVector2Array([
		Vector2(3.0, 4.0), Vector2(6.5, 4.0), Vector2(3.5, h - c), Vector2(0.0, h - c),
	]), MAGENTA)
	# Hell leuchtende Ecke an der Abschrägung oben rechts.
	money_panel.draw_line(Vector2(w - c - 18.0, 0.0), Vector2(w - c, 0.0), edge, 2.0)
	money_panel.draw_line(Vector2(w - c, 0.0), Vector2(w, c), edge, 2.0)
	var font := money_panel.get_theme_default_font()
	money_panel.draw_string(font, Vector2(14.0, 13.0), "CREDITS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.97, 1.0))
	money_panel.draw_line(Vector2(14.0, 16.5), Vector2(w * 0.55, 16.5), Color(MAGENTA, 0.45), 1.0)
	money_panel.draw_line(Vector2(w * 0.55, 16.5), Vector2(w - 12.0, 16.5), Color(MAGENTA, 0.12), 1.0)
	money_panel.draw_string(font, Vector2(w - 74.0, 12.0), "NC-ACCT", HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 8, Color(CYAN, 0.4))
	_draw_credchip(Vector2(27.0, 28.0))
	money_panel.draw_string(font, Vector2(w - 20.0, h - 9.0), "¢", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(MONEY_COLOR, 0.85))


## Kleiner Credchip: goldene Karte mit abgeschrägter Ecke, Kontaktfeld und Leiterbahnen.
func _draw_credchip(center: Vector2) -> void:
	var tl := center - Vector2(11.0, 7.0)
	var br := center + Vector2(11.0, 7.0)
	var cut := 3.5
	var card := PackedVector2Array([
		tl, Vector2(br.x - cut, tl.y), Vector2(br.x, tl.y + cut), br, Vector2(tl.x, br.y),
	])
	money_panel.draw_colored_polygon(card, Color(MONEY_COLOR.lerp(_money_flash_color, _money_flash), 0.18 + 0.3 * _money_flash))
	var edge := card.duplicate()
	edge.append(card[0])
	money_panel.draw_polyline(edge, MONEY_COLOR, 1.2, true)
	# Kontaktfeld links, durch zwei dunkle Linien in vier Felder geteilt.
	var pad := Rect2(tl + Vector2(3.0, 3.0), Vector2(6.0, 8.0))
	money_panel.draw_rect(pad, Color(MONEY_COLOR, 0.85))
	money_panel.draw_line(pad.position + Vector2(0.0, 4.0), pad.position + Vector2(6.0, 4.0), PANEL_COLOR, 1.0)
	money_panel.draw_line(pad.position + Vector2(3.0, 0.0), pad.position + Vector2(3.0, 8.0), PANEL_COLOR, 1.0)
	for i in 3:
		var ly := tl.y + 4.5 + i * 2.5
		var right := br.x - (6.0 if i == 0 else 3.0)
		money_panel.draw_line(Vector2(pad.end.x + 2.0, ly), Vector2(right, ly), Color(MONEY_COLOR, 0.6), 1.0)


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
