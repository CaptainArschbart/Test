extends CanvasLayer
## Death-Screen „FLATLINE“. Der Player ruft show_death() auf, sobald PlayerStats.died kommt.
##
## Ablauf: Kamera sackt zur Seite weg (und der Körper fällt auf den Boden, falls man in der Luft
## starb), das Bild wird rot-monochrom und verrauscht (death_screen.gdshader), der EKG-Ton geht
## in den Dauerton über. Dann erscheinen Titel, EKG-Linie, Todesursache, Überlebenszeit und
## drei Knöpfe im Stil des Pausemenüs (cyber_theme.tres):
##   RESPAWN          zurück an den Spawnpunkt, Vitals voll (Player.revive())
##   MISSION NEU      Szene neu laden, alles auf Anfang
##   HAUPTMENÜ        zurück ins Hauptmenü
## Liegt auf CanvasLayer 20 über allem und läuft immer (PROCESS_MODE_ALWAYS), auch wenn der
## Player beim Tod angehalten ist. Esc wird abgefangen, damit kein Pausemenü darüber aufgeht.
## Wird vom Player im Code erzeugt (player.tscn bleibt gleich).

const SHADER := preload("res://scenes/survival/death_screen.gdshader")
const THEME := preload("res://scenes/ui/cyber_theme.tres")
const VitalSounds := preload("res://scenes/survival/vital_sounds.gd")

const CYAN := Color(0.0, 0.95, 1.0, 1.0)
const MAGENTA := Color(1.0, 0.1, 0.75, 1.0)
const RED := Color(1.0, 0.16, 0.36, 1.0)
const PANEL_COLOR := Color(0.03, 0.0, 0.08, 0.88)
const CHAMFER := 14.0

## Text unter dem Titel je nach PlayerStats.last_damage_cause.
const CAUSES := {
	&"fall": "AUFPRALL // STURZ AUS GROSSER HÖHE",
	&"guard": "NEUTRALISIERT // SICHERHEITSDIENST",
	&"hunger": "ORGANVERSAGEN // UNTERERNÄHRUNG",
	&"thirst": "ORGANVERSAGEN // DEHYDRIERUNG",
	&"gang": "ZUSAMMENGESCHLAGEN // STRASSENGANG",
	&"gang_shot": "ERSCHOSSEN // STRASSENGANG",
	&"security_shot": "ERSCHOSSEN // SICHERHEITSDIENST",
	&"sniper": "AUSGESCHALTET // SCHARFSCHÜTZE",
	&"police_shot": "ERSCHOSSEN // POLIZEI",
	&"grenade": "ZERFETZT // EIGENE GRANATE",
	&"car": "ÜBERFAHREN // STRASSENVERKEHR",
}
const CAUSE_UNKNOWN := "SIGNAL VERLOREN // URSACHE UNBEKANNT"

## Szene für „Hauptmenü“.
@export_file("*.tscn") var main_menu_scene := "res://scenes/menu/main_menu.tscn"
## Sekunden bis Titel bzw. Knöpfe erscheinen.
@export var title_delay := 1.1
@export var buttons_delay := 2.0
@export var flatline_db := -14.0

## true, solange der Bildschirm offen ist.
var active := false

var _player: Player
var _overlay: ColorRect
var _overlay_material: ShaderMaterial
var _content: Control
var _title: Control
var _ecg: Control
var _cause_label: Label
var _time_label: Label
var _panel: PanelContainer
var _respawn_button: Button
var _restart_button: Button
var _menu_button: Button
var _blackout: ColorRect
var _flatline: AudioStreamPlayer
var _time := 0.0
var _amount := 0.0
var _busy := false
var _tweens: Array[Tween] = []


func _ready() -> void:
	name = "DeathScreen"
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_player = get_parent() as Player
	_build()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_overlay_material.set_shader_parameter(&"amount", _amount)
	_overlay_material.set_shader_parameter(&"time_s", _time)
	_title.queue_redraw()
	_ecg.queue_redraw()


func _input(event: InputEvent) -> void:
	if not active:
		return
	# Kein Pausemenü und kein Inventar über dem Death-Screen.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()


## Zeigt den Tod. `cause` ist PlayerStats.last_damage_cause, `seconds_alive` die Zeit seit dem Spawn.
func show_death(cause: StringName, seconds_alive: float) -> void:
	_kill_tweens()
	active = true
	_busy = false
	visible = true
	_time = 0.0
	_amount = 0.0
	_cause_label.text = CAUSES.get(cause, CAUSE_UNKNOWN)
	var secs := int(seconds_alive)
	_time_label.text = "ÜBERLEBT  %02d:%02d" % [secs / 60, secs % 60]
	_content.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_blackout.color.a = 0.0
	_set_buttons_enabled(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_flatline.volume_db = flatline_db
	_flatline.play()
	_collapse_camera()

	var fade := _tween()
	fade.tween_property(self, "_amount", 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var title := _tween()
	title.tween_interval(title_delay)
	title.tween_property(_content, "modulate:a", 1.0, 0.35)
	var buttons := _tween()
	buttons.tween_interval(buttons_delay)
	buttons.tween_property(_panel, "modulate:a", 1.0, 0.3)
	buttons.tween_callback(_on_buttons_shown)
	# Dauerton nach ein paar Sekunden leiser, sonst nervt er im Menü.
	var tone := _tween()
	tone.tween_interval(3.5)
	tone.tween_property(_flatline, "volume_db", flatline_db - 22.0, 2.5)


## Respawn am Spawnpunkt (wie der Knopf).
func respawn() -> void:
	if _busy or _player == null:
		return
	_busy = true
	_set_buttons_enabled(false)
	_kill_tweens()
	var tween := _tween()
	tween.tween_property(_blackout, "color:a", 1.0, 0.3)
	tween.tween_callback(_finish_respawn)
	tween.tween_property(_blackout, "color:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: visible = false)


## Szene neu laden: Welt, Gegner, Pickups und Spieler auf Anfang.
func restart_mission() -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func go_to_main_menu() -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)


func _finish_respawn() -> void:
	active = false
	_flatline.stop()
	_amount = 0.0
	_content.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_player.revive()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()


func _on_buttons_shown() -> void:
	_set_buttons_enabled(true)
	_respawn_button.grab_focus()


## Kamera kippt zur Seite und sackt auf Bodenhöhe. In der Luft fällt der Körper erst auf den Boden.
func _collapse_camera() -> void:
	if _player == null:
		return
	var head := _player.head
	var fall_time := 0.0
	var space := _player.get_world_3d().direct_space_state
	var from := _player.global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 60.0, 1, [_player.get_rid()])
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var ground_y: float = hit.position.y
		var drop := _player.global_position.y - ground_y
		if drop > 0.05:
			fall_time = clampf(sqrt(2.0 * drop / maxf(_player.gravity, 0.1)), 0.1, 1.2)
			var body := _tween()
			body.tween_property(_player, "global_position:y", ground_y, fall_time) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var sag := _tween()
	sag.set_parallel(true)
	sag.tween_property(head, "position:y", 0.28, 0.9).set_delay(fall_time * 0.5) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	sag.tween_property(head, "rotation:z", deg_to_rad(68.0), 1.0).set_delay(fall_time * 0.5 + 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	sag.tween_property(head, "rotation:x", deg_to_rad(-8.0), 1.1).set_delay(fall_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_buttons_enabled(enabled: bool) -> void:
	for button: Button in [_respawn_button, _restart_button, _menu_button]:
		button.disabled = not enabled
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _tween() -> Tween:
	var tween := create_tween()
	_tweens.append(tween)
	return tween


func _kill_tweens() -> void:
	for tween: Tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()


# --- Aufbau ------------------------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = THEME
	add_child(root)

	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = SHADER
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.material = _overlay_material
	root.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", 4)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_content)

	var tag := _label("// BIOMONITOR  ·  VERBINDUNG UNTERBROCHEN", 13, Color(CYAN, 0.7))
	_content.add_child(tag)

	_title = Control.new()
	_title.name = "Title"
	_title.custom_minimum_size = Vector2(600.0, 110.0)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.draw.connect(_draw_title)
	_content.add_child(_title)

	_ecg = Control.new()
	_ecg.name = "Ecg"
	_ecg.custom_minimum_size = Vector2(600.0, 64.0)
	_ecg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ecg.draw.connect(_draw_ecg)
	_content.add_child(_ecg)

	_cause_label = _label(CAUSE_UNKNOWN, 18, Color(1.0, 0.85, 0.9))
	_content.add_child(_cause_label)
	_time_label = _label("ÜBERLEBT  00:00", 14, Color(CYAN, 0.8))
	_content.add_child(_time_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 14.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	var row := CenterContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	_panel = PanelContainer.new()
	_panel.name = "Buttons"
	_panel.custom_minimum_size = Vector2(380.0, 0.0)
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_panel.draw.connect(_draw_panel)
	row.add_child(_panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	margin.add_child(buttons)
	_respawn_button = _button(buttons, "RESPAWN", respawn)
	_restart_button = _button(buttons, "MISSION NEU STARTEN", restart_mission)
	_menu_button = _button(buttons, "HAUPTMENÜ", go_to_main_menu)

	_blackout = ColorRect.new()
	_blackout.name = "Blackout"
	_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout.color = Color(0.0, 0.0, 0.0, 0.0)
	root.add_child(_blackout)

	_flatline = AudioStreamPlayer.new()
	_flatline.name = "Flatline"
	_flatline.stream = VitalSounds.flatline()
	_flatline.bus = &"SFX"
	add_child(_flatline)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## „FLATLINE“ mit Farbtrennung (Cyan links, Magenta rechts), die ab und zu zuckt.
func _draw_title() -> void:
	var font := _title.get_theme_default_font()
	var size := 96
	var text := "FLATLINE"
	var width := _title.size.x
	var baseline := 88.0
	var jitter := 0.0
	var tick := floori(_time * 12.0)
	if (tick * 7919) % 23 == 0:
		jitter = (float((tick * 104729) % 9) - 4.0) * 2.0
	var split := 3.0 + absf(jitter)
	_title.draw_string(font, Vector2(-split + jitter, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(CYAN, 0.55))
	_title.draw_string(font, Vector2(split + jitter, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(MAGENTA, 0.6))
	_title.draw_string_outline(font, Vector2(jitter, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 6, Color(0.1, 0.0, 0.05, 0.9))
	_title.draw_string(font, Vector2(jitter, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(1.0, 0.93, 0.96))
	# Ein Glitch-Streifen quer durch den Titel.
	if jitter != 0.0:
		var y := 30.0 + float((tick * 31) % 50)
		_title.draw_rect(Rect2(0.0, y, width, 3.0), Color(RED, 0.8))


## EKG-Linie: drei schwächer werdende Ausschläge, dann flach. Wird von links nach rechts gezeichnet.
func _draw_ecg() -> void:
	var w := _ecg.size.x
	var h := _ecg.size.y
	var mid := h * 0.5
	var progress := clampf(_time / 1.8, 0.0, 1.0)
	var points := PackedVector2Array()
	var steps := 160
	for i: int in steps + 1:
		var x := float(i) / steps
		if x > progress:
			break
		points.append(Vector2(x * w, mid - _ecg_value(x) * h * 0.45))
	# Rahmenlinien oben/unten wie ein Monitor.
	_ecg.draw_line(Vector2(0.0, 0.0), Vector2(w, 0.0), Color(CYAN, 0.18), 1.0)
	_ecg.draw_line(Vector2(0.0, h), Vector2(w, h), Color(CYAN, 0.18), 1.0)
	if points.size() < 2:
		return
	_ecg.draw_polyline(points, Color(RED, 0.25), 6.0, true)
	_ecg.draw_polyline(points, Color(1.0, 0.45, 0.55), 2.0, true)
	var tip := points[points.size() - 1]
	var blink := 0.6 + 0.4 * sin(_time * 10.0)
	_ecg.draw_circle(tip, 4.0, Color(1.0, 0.8, 0.85, blink))


static func _ecg_value(x: float) -> float:
	var beats := [[0.12, 1.0], [0.30, 0.6], [0.46, 0.28]]
	var v := 0.0
	for beat: Array in beats:
		var d := (x - float(beat[0])) * 60.0
		# Kleiner Gegenschlag vor und nach der Spitze.
		v += float(beat[1]) * (exp(-d * d) - 0.35 * exp(-(d + 1.6) * (d + 1.6)) - 0.25 * exp(-(d - 1.8) * (d - 1.8)))
	return v


## Rahmen wie Vitals-HUD und Menü: abgeschrägte Ecken, Cyan-Rand mit Schein, Magenta-Streifen.
func _draw_panel() -> void:
	var w := _panel.size.x
	var h := _panel.size.y
	var c := CHAMFER
	var shape := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(w - c, 0.0), Vector2(w, c),
		Vector2(w, h), Vector2(c, h), Vector2(0.0, h - c),
	])
	_panel.draw_colored_polygon(shape, PANEL_COLOR)
	for y: int in range(2, int(h), 3):
		_panel.draw_line(Vector2(2.0, y), Vector2(w - 2.0, y), Color(1.0, 1.0, 1.0, 0.02), 1.0)
	var outline := shape.duplicate()
	outline.append(shape[0])
	_panel.draw_polyline(outline, Color(CYAN, 0.12), 5.0)
	_panel.draw_polyline(outline, Color(CYAN, 0.5), 1.0)
	_panel.draw_rect(Rect2(0.0, 0.0, 4.0, h - c), Color(MAGENTA, 0.85))
	_panel.draw_line(Vector2(c + 6.0, h - 4.0), Vector2(w * 0.5, h - 4.0), Color(MAGENTA, 0.6), 1.0)
